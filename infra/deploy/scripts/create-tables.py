#!/usr/bin/env python3
"""
Database setup script for image-trainer application.
Creates the images table with automatic hash generation.
"""

import os
import sys
import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
import logging


logging.basicConfig(level=logging.INFO,
                    format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


def get_db_connection():
    """Create database connection using environment variables."""
    try:
        # Parse endpoint to get host and port
        db_endpoint = os.environ.get('DB_HOST')
        if not db_endpoint:
            raise ValueError("DB_HOST environment variable not set")

        # Split endpoint into host and port
        if ':' in db_endpoint:
            host, port = db_endpoint.split(':')
        else:
            host = db_endpoint
            port = 5432

        connection = psycopg2.connect(
            host=host,
            port=port,
            database=os.environ.get('DB_NAME', 'image-trainer-db'),
            user=os.environ.get('DB_USER', 'image-trainer-user'),
            password=os.environ.get('DB_PASSWORD')
        )

        connection.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        logger.info(f"Connected to database: {host}: {port}/\
                    {os.environ.get('DB_NAME', 'image-trainer-db')}")
        return connection

    except Exception as e:
        logger.error(f"Failed to connect to database: {e}")
        sys.exit(1)


def create_images_table(connection):
    """Create the images table with all required columns and constraints."""
    try:
        cursor = connection.cursor()

        # Create the images table
        create_table_sql = """
        CREATE TABLE IF NOT EXISTS images (
            id SERIAL PRIMARY KEY,
            file_name VARCHAR(255) UNIQUE NOT NULL,
            is_masc_human BOOLEAN,
            is_masc_prediction BOOLEAN,
            hash VARCHAR(255) NOT NULL
        );
        """

        cursor.execute(create_table_sql)
        logger.info("Created images table successfully")

        # Create function to extract hash from filename
        create_function_sql = """
        CREATE OR REPLACE FUNCTION extract_hash_from_filename()
        RETURNS TRIGGER AS $$
        BEGIN
            -- Extract filename without extension
            -- Handles cases like "file.jpg", "file.jpeg", "file.png", etc.
            NEW.hash = split_part(NEW.file_name, '.', 1);
            RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;
        """

        cursor.execute(create_function_sql)
        logger.info("Created hash extraction function")

        # Create trigger to automatically populate hash column
        create_trigger_sql = """
        DROP TRIGGER IF EXISTS auto_hash_trigger ON images;
        CREATE TRIGGER auto_hash_trigger
            BEFORE INSERT OR UPDATE ON images
            FOR EACH ROW
            EXECUTE FUNCTION extract_hash_from_filename();
        """

        cursor.execute(create_trigger_sql)
        logger.info("Created auto-hash trigger")

        cursor.close()

    except Exception as e:
        logger.error(f"Failed to create images table: {e}")
        connection.rollback()
        sys.exit(1)


def verify_table_creation(connection):
    """Verify that the table was created correctly."""
    try:
        cursor = connection.cursor()

        # Check if table exists
        cursor.execute("""
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = 'public' AND table_name = 'images';
        """)

        if cursor.fetchone():
            logger.info("✓ Images table exists")
        else:
            logger.error("✗ Images table not found")
            sys.exit(1)

        # Check columns
        cursor.execute("""
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_name = 'images'
            ORDER BY ordinal_position;
        """)

        columns = cursor.fetchall()
        logger.info("Table columns:")
        for column in columns:
            logger.info(f" - {column[0]}: {column[1]} \
                        (nullable: {column[2]})")

        # Check triggers
        cursor.execute("""
            SELECT trigger_name
            FROM information_schema.triggers
            WHERE event_object_table = 'images';
        """)

        triggers = cursor.fetchall()
        if triggers:
            logger.info("✓ Auto-hash trigger exists")
        else:
            logger.error("✗ Auto-hash trigger not found")
            sys.exit(1)

        cursor.close()

    except Exception as e:
        logger.error(f"Failed to verify table creation: {e}")
        sys.exit(1)


def test_hash_functionality(connection):
    """Test that the hash auto-generation works correctly."""
    try:
        cursor = connection.cursor()

        # Test insert with hash auto-generation
        test_filename = "test123.jpeg"
        cursor.execute("""
            INSERT INTO images (file_name, is_masc_human, is_masc_prediction)
            VALUES (%s, %s, %s)
            ON CONFLICT (file_name) DO NOTHING
            RETURNING id, file_name, hash;
        """, (test_filename, True, False))

        result = cursor.fetchone()
        if result:
            id, filename, hash_value = result
            logger.info(f"✓ Test insert successful: {filename} \
                        becomes hash: {hash_value}")

            # Clean up test data
            cursor.execute("DELETE FROM images WHERE \
                           file_name = %s", (test_filename,))
            logger.info("✓ Test data cleaned up")
        else:
            logger.warning("Test insert returned no \
                           result (possibly duplicate)")

        cursor.close()

    except Exception as e:
        logger.error(f"Failed to test hash functionality: {e}")
        sys.exit(1)


def main():
    """Main function to set up the database."""
    logger.info("Starting database setup...")

    # Get database connection
    connection = get_db_connection()

    try:
        # Create the images table
        create_images_table(connection)

        # Verify the table was created correctly
        verify_table_creation(connection)

        # Test the hash functionality
        test_hash_functionality(connection)

        logger.info("✓ Database setup completed successfully!")

    finally:
        connection.close()
        logger.info("Database connection closed")


if __name__ == "__main__":
    main()
