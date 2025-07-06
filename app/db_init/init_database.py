import os
import json
import logging
from sqlalchemy import create_engine, text, inspect
from sqlalchemy.exc import SQLAlchemyError


logger = logging.getLogger()
logger.setLevel(logging.INFO)


def get_db_connection_string():
    """Get database connection string from environment variables"""
    db_host = os.environ['DB_HOST']
    db_name = os.environ['DB_NAME']
    db_user = os.environ['DB_USER']
    db_password = os.environ['DB_PASSWORD']
    # db_port = os.environ.get('DB_PORT', '5432')

    return f"postgresql://{db_user}:{db_password}@{db_host}/{db_name}"  # noqa: E501, E231


def check_table_exists(engine, table_name):
    """Check if a table exists in the database"""
    inspector = inspect(engine)
    return table_name in inspector.get_table_names()


def create_images_table(engine):
    """Create the images table with all necessary components"""
    try:
        with engine.connect() as conn:
            # Create the images table
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS images (
                    id SERIAL PRIMARY KEY,
                    file_name VARCHAR(255) UNIQUE NOT NULL,
                    is_masc_human BOOLEAN,
                    is_masc_prediction BOOLEAN,
                    hash VARCHAR(255) NOT NULL
                );
            """))

            # Create the hash extraction function
            conn.execute(text("""
                CREATE OR REPLACE FUNCTION extract_hash_from_filename()
                RETURNS TRIGGER AS $$
                BEGIN
                    -- Extract filename without extension
                    NEW.hash = split_part(NEW.file_name, '.', 1);
                    RETURN NEW;
                END;
                $$ LANGUAGE plpgsql;
            """))

            # Create the trigger
            conn.execute(text("""
                DROP TRIGGER IF EXISTS auto_hash_trigger ON images;
                CREATE TRIGGER auto_hash_trigger
                    BEFORE INSERT OR UPDATE ON images
                    FOR EACH ROW
                    EXECUTE FUNCTION extract_hash_from_filename();
            """))

            conn.commit()
            logger.info("Images table, function, and \
                        trigger created successfully")
            return True

    except SQLAlchemyError as e:
        logger.error(f"Error creating images table: {e}")
        return False


def verify_database_setup(engine):
    """Verify that the database setup is correct"""
    try:
        with engine.connect() as conn:
            # Check if table exists
            result = conn.execute(text("""
                SELECT EXISTS (
                    SELECT FROM information_schema.tables
                    WHERE table_schema = 'public' AND table_name = 'images'
                );
            """))
            table_exists = result.scalar()

            if not table_exists:
                logger.error("Images table does not exist")
                return False

            # Check if trigger exists
            result = conn.execute(text("""
                SELECT EXISTS (
                    SELECT FROM information_schema.triggers
                    WHERE event_object_table = 'images' AND
                    trigger_name = 'auto_hash_trigger'
                );
            """))
            trigger_exists = result.scalar()

            if not trigger_exists:
                logger.error("Auto-hash trigger does not exist")
                return False

            # Test the trigger with a sample insert
            conn.execute(text("""
                INSERT INTO images (file_name, is_masc_human,
                              is_masc_prediction)
                VALUES ('test_file.jpg', true, false)
                ON CONFLICT (file_name) DO NOTHING;
            """))

            # Verify the hash was generated
            result = conn.execute(text("""
                SELECT hash FROM images WHERE file_name = 'test_file.jpg';
            """))
            hash_value = result.scalar()

            if hash_value != 'test_file':
                logger.error(f"Hash generation failed. Expected \
                             'test_file', got '{hash_value}'")
                return False

            # Clean up test data
            conn.execute(text("DELETE FROM images WHERE \
                              file_name = 'test_file.jpg';"))
            conn.commit()

            logger.info("Database verification completed successfully")
            return True

    except SQLAlchemyError as e:
        logger.error(f"Error verifying database setup: {e}")
        return False


def lambda_handler(event, context):
    """Lambda handler for database initialization"""
    try:
        logger.info("Starting database initialization")

        # Get database connection
        connection_string = get_db_connection_string()
        engine = create_engine(connection_string)

        # Check if images table already exists
        if check_table_exists(engine, 'images'):
            logger.info("Images table already exists, verifying setup...")
            if verify_database_setup(engine):
                logger.info("Database is already properly initialized")
                return {
                    'statusCode': 200,
                    'body': json.dumps({
                        'message': 'Database already initialized',
                        'action': 'verification_completed'
                    })
                }
            else:
                logger.warning("Table exists but setup is incomplete, \
                               recreating...")

        logger.info("Creating images table and components...")
        if create_images_table(engine):
            # Verify the setup
            if verify_database_setup(engine):
                logger.info("Database initialization completed successfully")
                return {
                    'statusCode': 200,
                    'body': json.dumps({
                        'message': 'Database initialized successfully',
                        'action': 'created_and_verified'
                    })
                }
            else:
                logger.error("Database creation succeeded \
                             but verification failed")
                return {
                    'statusCode': 500,
                    'body': json.dumps({
                        'message': 'Database creation succeeded \
                            but verification failed',
                        'action': 'creation_succeeded_verification_failed'
                    })
                }
        else:
            logger.error("Database creation failed")
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'message': 'Database creation failed',
                    'action': 'creation_failed'
                })
            }

    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': f'Unexpected error: {str(e)}',
                'action': 'error'
            })
        }
