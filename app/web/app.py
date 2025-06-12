import os
from flask import Flask, render_template, request, redirect, url_for

app = Flask(__name__)


def get_image_url():
    """Function to get the external image URL from environment variable."""
    return os.environ.get(
        'IMAGE_URL',
        'https://via.placeholder.com/400x300.jpg'
    )


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
    # Redirect back to main page with gender parameter
    return redirect(url_for('index', gender=gender))


if __name__ == '__main__':
    app.run(debug=True)
