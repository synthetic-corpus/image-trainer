import os
import sys
from flask import Flask, render_template, request, redirect, url_for, jsonify
from botocore.exceptions import ClientError, NoCredentialsError

# Custom modules
# Handle both local development and Lambda environments
try:
    # Try Lambda environment first (modules at same level)
    from modules.s3_access import S3Access
    print("Modules imported at Root Successfully")
except ImportError:
    # Fall back to local development (modules one level up)
    sys.path.append(os.path.join(os.path.dirname(__file__), '..'))
    from modules.s3_access import S3Access

try:
    bucket_name = os.environ.get('S3_BUCKET_NAME')
    s3_access = S3Access(bucket_name)
    print("S3 access initialized successfully")
except (ClientError, NoCredentialsError) as e:
    print(f"Error initializing S3 access: {e}")
    s3_access = None

app = Flask(__name__)


def get_image_url():
    """Function to get the external image URL from environment variable."""
    return os.environ.get(
        'IMAGE_URL',
        'https://via.placeholder.com/400x300.jpg'
    )


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
    current_image_url = request.form.get('current_image_url', get_image_url())

    # Extract filename from the image URL
    filename = extract_filename_from_url(current_image_url)

    selection_data = {
        'gender': gender,
        'filename': filename
    }

    return redirect(url_for('index', gender=selection_data['gender']))


@app.route('/health')
def health():
    container_name = os.environ.get('CONTAINER_NAME', 'web')
    return jsonify({"message": f"{container_name} is up"}), 200


if __name__ == '__main__':
    app.run(debug=True)
