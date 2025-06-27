import os
import sys
import logging
from flask import Flask, render_template, request, redirect, url_for, jsonify
from botocore.exceptions import ClientError, NoCredentialsError

# Configure logging for CloudWatch
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Custom modules
# Handle both local development and Lambda environments
try:
    # Try Lambda environment first (modules at same level)
    from modules.cdn import CDN
    logger.info("Modules imported at Root Successfully")
except ImportError:
    # Fall back to local development (modules one level up)
    sys.path.append(os.path.join(os.path.dirname(__file__), '..'))
    from modules.cdn import CDN
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
    image_url = get_image_url()
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

    return redirect(url_for('index', gender=selection_data['gender']))


@app.route('/health')
def health():
    container_name = os.environ.get('CONTAINER_NAME', 'web')
    return jsonify({"message": f"{container_name} is up"}), 200


if __name__ == '__main__':
    app.run(debug=True)
