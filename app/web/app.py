import os
import sys
import logging
from flask import Flask, render_template, request, redirect, url_for, jsonify
from flask_sqlalchemy import SQLAlchemy
from botocore.exceptions import ClientError, NoCredentialsError
import sqlalchemy.exc


# Configure logging for CloudWatch
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Custom modules
# Handle both local development and Lambda environments
try:
    # Try Lambda environment first (modules at same level)
    from modules.cdn import CDN
    from db_models.image_table_base import Base
    logger.info("Modules imported at Root Successfully")
except ImportError:
    # Fall back to local development (modules one level up)
    sys.path.append(os.path.join(os.path.dirname(__file__), '..'))
    from modules.cdn import CDN
    from db_models.image_table_base import Base
    logger.info("Modules imported at fallback Successfully")

try:
    bucket_name = os.environ.get('S3_BUCKET_NAME')
    cloudfront_url = os.environ.get('CLOUDFRONT_URL')
    cloudfront_access = CDN(bucket_name, cloudfront_url)
    logger.info("CloudFront access initialized successfully")
except (ClientError, NoCredentialsError) as e:
    logger.error(f"Error initializing CloudFront access: {e}")
    cloudfront_access = None

app = Flask(__name__)
db = SQLAlchemy()
db.Model = Base
Image_table_base = None

file_name_cache = []
# Database configuration
DB_HOST = os.environ.get('DB_HOST')
DB_NAME = os.environ.get('DB_NAME', 'image-trainer-db')
DB_USER = os.environ.get('DB_USER', 'image-trainer-user')
DB_PASSWORD = os.environ.get('DB_PASSWORD')

# Print out Variables For Debugging
logger.info(f"DB_HOST: {DB_HOST}")
logger.info(f"DB_NAME: {DB_NAME}")
logger.info(f"DB_USER: {DB_USER}")
if len(DB_PASSWORD) > 0:
    logger.info(f"DB_PASSWORD: {DB_PASSWORD[:4]}******")
    logger.info(f"Database string: \
                postgresql://{DB_USER}:{DB_PASSWORD[:4]}****@{DB_HOST}")  # noqa
else:
    logger.info("DB_PASSWORD: Not SET!")

if DB_HOST and DB_PASSWORD:
    # Construct database connection string
    DATABASE_URI = f'postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}'  # noqa
    app.config['SQLALCHEMY_DATABASE_URI'] = DATABASE_URI
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

    db.init_app(app)

    logger.info("Database connection configured successfully")
else:
    logger.warning("Database environment variables not set - \
                   database features disabled")
    db = None
    Image_table_base = None


def get_image_url_by_db() -> str:
    # Initial checks for database feature availability
    if Image_table_base is None or db is None:
        logger.warning("Database features disabled. Cannot get image from DB.")
        raise RuntimeError("Database features are not available. \
                           Check environment variables.")

    with app.app_context():  # ensures app context!
        try:
            if len(file_name_cache) == 0:
                # Call model methods, passing Flask-SQLAlchemy's db.session
                next_batch = Image_table_base.get_random_unclassified(db.session)  # noqa E501

                # If no unclassified images, try getting classified ones
                if len(next_batch) == 0:
                    logger.warn("We did not find any unclassified images! \
                                Getting classified images instead.")
                    next_batch = Image_table_base.get_random_classified(db.session)  # noqa E501

                if not next_batch:
                    raise RuntimeError("Could not find rows to \
                                       classify or unclassify")

                # Populate cache with file names
                for element in next_batch:
                    file_name_cache.append(element.file_name)

            # Get the next file from the cache
            next_file = file_name_cache.pop()

            # Return the full URL
            return f"{cloudfront_url}/{next_file}"

        except sqlalchemy.exc.SQLAlchemyError as e:
            # Catch SQLAlchemy-specific errors, log, rollback, and re-raise
            logger.error(f"Database error in get_image_url_by_db: {e}")
            db.session.rollback()  # Rollback the session
            raise RuntimeError(f"Database error: {e}")

        except Exception as e:
            # Catch any other unexpected errors
            logger.error(f"An unexpected error occurred in \
                         get_image_url_by_db: {e}")
            raise RuntimeError(f"An unexpected error occurred: {e}")

        finally:
            pass  # db.session.remove()


def get_image_url() -> str:
    """Function to get the external image URL from environment variable."""
    image_url = cloudfront_access.get_random()[0]
    return image_url


def extract_filename_from_url(url):
    """Extract filename from URL."""
    return url.split('/')[-1]


@app.route('/')
def index():
    # Get the image URL server-side and pass it to the template
    image_url = get_image_url_by_db()
    selected_gender = request.args.get('gender', None)
    message = None

    if selected_gender:
        message = f"You selected: {selected_gender.upper()}"

    return render_template(
        'index.html',
        image_url=image_url,
        selected_gender=selected_gender,
        message=message
    )


@app.route('/select-gender', methods=['POST'])
def select_gender():
    gender = request.form.get('gender')
    current_image_url = request.form.get('current_image_url', None)

    try:
        filename = extract_filename_from_url(current_image_url)
    except Exception as e:
        logger.error(f"Error extracting filename from URL: {e}. \
              No data will be written!")
        filename = None

    if filename is not None:
        selection_data = {
            'gender': gender,
            'filename': filename
        }
        message = f'User selected {gender} for {filename}'
        logger.info(message)

        # Update the database with the gender selection
        try:
            # Convert gender string to boolean
            is_masc = gender.lower() == 'male'
            Image_table_base.update_gender(filename, is_masc)
            logger.info(f'Successfully updated database for \
                        {filename} with gender: {gender}')
        except ValueError as e:
            logger.error(f'Image not in database for {filename}: {e}')
        except sqlalchemy.exc.IntegrityError as e:
            logger.error(f'Database integrity error for {filename}: {e}')
        except sqlalchemy.exc.OperationalError as e:
            logger.error(f'Database connection error for {filename}: {e}')
        except sqlalchemy.exc.SQLAlchemyError as e:
            logger.error(f'SQLAlchemy error for {filename}: {e}')
        except Exception as e:
            logger.error(f'Unexpected error updating database \
                         for {filename}: {e}')  # noqa: E272

    return redirect(url_for('index', gender=selection_data['gender']))


@app.route('/health')
def health():
    container_name = os.environ.get('CONTAINER_NAME', 'web')
    return jsonify({"message": f"{container_name} is up"}), 200


@app.route('/api/images')
def get_images():
    """Get all images from the database."""
    if Image_table_base is None:
        return jsonify({"error": "Database not configured"}), 500

    try:
        images = Image_table_base.query.all()
        return jsonify([img.to_dict() for img in images])
    except Exception as e:
        logger.error(f"Error fetching images: {e}")
        return jsonify({"error": "Database error"}), 500


@app.route('/api/images/random')
def get_random_images():
    """Get 10 random unclassified images."""
    if Image_table_base is None:
        return jsonify({"error": "Database not configured"}), 500

    try:
        random_images = Image_table_base.get_random_unclassified(10)
        return jsonify([img.to_dict() for img in random_images])
    except Exception as e:
        logger.error(f"Error fetching random images: {e}")
        return jsonify({"error": "Database error"}), 500


if __name__ == '__main__':
    app.run(debug=True)
