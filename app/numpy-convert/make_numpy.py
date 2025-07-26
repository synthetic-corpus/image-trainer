#################################################################
# Convert images from sources/ folder to black and white
# This lambda function is triggered by S3 events when files are
# uploaded to the sources/ folder.
# It converts the images to black and white and saves them to
# the monochrome/ folder with _bw suffix.
#################################################################
import json
import logging
import os
import sys
import numpy as np
from urllib.parse import unquote_plus
from io import BytesIO
from botocore.exceptions import ClientError, NoCredentialsError, \
    ParamValidationError
# import numpy as np # not used yet, but here for future use
from PIL import Image


try:
    # Try Lambda environment first (modules at same level)
    from modules.s3_access import S3Access
except ImportError:
    # Fall back to local development (modules one level up)
    sys.path.append(os.path.join(os.path.dirname(__file__), '..'))
    from modules.s3_access import S3Access


# Configure CloudWatch logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize S3 access
s3_access = None

# Get default target pixels from environment variable
DEFAULT_TARGET_PIXELS = int(os.environ.get('DEFAULT_TARGET_PIXELS', '500'))
TO_GRAYSCALE = bool(int(os.environ.get('TO_GRAYSCALE', '0')))


def lambda_handler(event, context):
    """
    AWS Lambda handler for converting images to black and white.
    Triggered by S3 events when files are uploaded to the sources/ folder.
    """
    global s3_access

    logger.info(f"Starting image conversion. Request ID: "
                f"{context.aws_request_id}")
    logger.info(f"Event: {json.dumps(event, default=str)}")

    bucket_name = os.environ.get('S3_BUCKET_NAME')
    if not bucket_name:
        error_msg = 'S3_BUCKET_NAME environment variable not set'
        logger.error(error_msg)
        return {
            'statusCode': 500,
            'body': error_msg
        }

    # Initialize S3 access if not already done
    if s3_access is None:
        try:
            s3_access = S3Access(bucket_name)
            logger.info(f"Initialized S3 access for bucket: {bucket_name}")
        except (NoCredentialsError, ClientError) as e:
            error_msg = f"Failed to initialize S3 access: {e}"
            logger.error(error_msg)
            return {
                'statusCode': 500,
                'body': error_msg
            }

    try:
        processed_files = []

        # Process each record in the S3 event
        for record in event['Records']:
            # Extract bucket and object key from the event
            event_bucket = record['s3']['bucket']['name']
            object_key = unquote_plus(record['s3']['object']['key'])

            logger.info(f"Processing file: {object_key} from bucket: "
                        f"{event_bucket}")

            # Verify this is the correct bucket
            if event_bucket != bucket_name:
                logger.warning(f"Skipping file from different bucket: "
                               f"{event_bucket}")
                continue

            # DEFENSIVE: Ensure we only process files from sources folder
            if not object_key.startswith('sources/'):
                logger.warning(f"Skipping file not in sources folder: "
                               f"{object_key}")
                continue

            # DEFENSIVE: Skip the folder itself
            if object_key.endswith('/'):
                logger.info(f"Skipping folder: {object_key}")
                continue

            # DEFENSIVE: Skip files have _bw suffix (prevent reprocessing)
            filename = object_key.split('/')[-1]
            if '_bw.' in filename:
                logger.info(f"Skipping already processed file: {object_key}")
                processed_files.append({
                    'original_file': object_key,
                    'status': 'skipped_already_processed'
                })
                continue

            # Check if file has valid image extension
            if is_valid_image_file(filename):
                # Process valid image file
                result = process_image_file(object_key)
                processed_files.append(result)
                logger.info(f"Successfully processed: {object_key}")
            else:
                logger.warning(f"Skipping invalid image file: {object_key}")
                processed_files.append({
                    'original_file': object_key,
                    'status': 'skipped_invalid_extension'
                })

        logger.info(f"Image conversion completed. Processed "
                    f"{len(processed_files)} files")
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Image conversion completed',
                'processed_files': processed_files
            })
        }

    except ClientError as e:
        error_code = e.response['Error']['Code']
        error_message = e.response['Error']['Message']
        logger.error(f"AWS S3 error: {error_code} - {error_message}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': f'AWS S3 error: {error_code} - {error_message}'
            })
        }
    except NoCredentialsError as e:
        error_msg = f"AWS credentials error: {e}"
        logger.error(error_msg)
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': error_msg
            })
        }
    except ParamValidationError as e:
        error_msg = f"AWS parameter validation error: {e}"
        logger.error(error_msg)
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': error_msg
            })
        }
    except Exception as e:
        error_msg = f"Unexpected error processing images: {str(e)}"
        logger.error(error_msg, exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': error_msg
            })
        }


def is_valid_image_file(filename):
    """Check if the file has a valid image extension."""
    valid_extensions = ['.jpeg', '.jpg', '.png']
    filename_lower = filename.lower()
    return any(filename_lower.endswith(ext) for ext in valid_extensions)


def get_file_object(file_key):
    """
    Function 1: Get file object from S3 sources folder.

    Args:
        file_key (str): The S3 key of the file in sources folder

    Returns:
        bytes: File content as bytes, or None if error
    """
    try:
        logger.info(f"Retrieving file object: {file_key}")

        # Get the file object using S3Access
        file_content = s3_access.get_object(file_key)
        if file_content is None:
            error_msg = f"Failed to retrieve file {file_key}"
            logger.error(error_msg)
            return None

        logger.info(f"Successfully retrieved file object: {file_key}")
        return file_content

    except Exception as e:
        logger.error(f"Error getting file object {file_key}: {str(e)}")
        return None


def resize_and_pad_image(image_file_object,
                         target_pixels_on_side=DEFAULT_TARGET_PIXELS,
                         background_color=(0, 0, 0)):
    """
    Resizes an image to fit within a square of 'target_pixels_on_side'
    while maintaining its aspect ratio, and adds black (or specified color)
    padding to make it a perfect square.

    Args:
        image_file_object: A PIL.Image.Image object (already opened).
        target_pixels_on_side (int): The desired length (in pixels) of each
                                     side of the square output image.
                                     Defaults to DEFAULT_TARGET_PIXELS
                                     environment variable.
        background_color (tuple): The RGB tuple (0-255) for the padding color.
                                  Defaults to black (0, 0, 0).

    Returns:
        PIL.Image.Image: A new PIL Image object, resized and padded to
        a square.
        Returns None if there's an error.
    """
    try:
        if not isinstance(image_file_object, Image.Image):
            print("Error: Input is not a PIL.Image.Image object. (resize)")
            return None

        original_width, original_height = image_file_object.size
        if original_width > original_height:
            scale_factor = target_pixels_on_side / original_width
        else:
            scale_factor = target_pixels_on_side / original_height

        new_width = int(original_width * scale_factor)
        new_height = int(original_height * scale_factor)

        # Resize the image while maintaining aspect ratio
        resized_img = image_file_object.convert("RGB").resize(
            (new_width, new_height),
            Image.Resampling.LANCZOS)

        # Create a new square image with the background color
        padded_img = Image.new('RGB',
                               (target_pixels_on_side, target_pixels_on_side),
                               background_color)

        paste_x = (target_pixels_on_side - new_width) // 2
        paste_y = (target_pixels_on_side - new_height) // 2

        # Paste the resized image onto the new background
        padded_img.paste(resized_img, (paste_x, paste_y))

        return padded_img

    except Exception as e:
        print(f"An error occurred during resizing and padding: {e}")
        return None


def convert_to_numpy(file_object, grayscale=TO_GRAYSCALE) -> np.ndarray:
    """
    Function 2: Convert image file object to black and white.

    Args:
        file_object (bytes): File content as bytes

    Returns:
        bytes: Black and white image as bytes, or None if error
    """
    try:
        logger.info("Converting image to black and white")

        # Convert bytes to PIL Image
        image = Image.open(BytesIO(file_object))
        image = resize_and_pad_image(image)

        if grayscale:
            # Convert to grayscale (black and white)
            image = image.convert('L')
        else:
            image = image.convert('RGB')

        # Convert to numpy array
        img_array = np.array(image)
        img_array = img_array / 255.0
        flattened_img = img_array.flatten()

        logger.info("Successfully converted to a numpy array")
        return flattened_img

    except Exception as e:
        logger.error(f"Error converting image to black and white: {str(e)}")
        return None


def save_numpy_array(numpy_array: np.ndarray, original_key: str) -> None:
    """
    Function 3: Save black and white image to S3 numpys folder.

    Args:
        file_object (bytes): Black and white image as bytes
        original_key (str): Original S3 key of the source file

    Returns:
        str: New S3 key of the saved file, or None if error
    """
    try:
        logger.info(f"Saving numpy array for: {original_key}")

        # DEFENSIVE: Ensure we never write back to sources folder
        if original_key.startswith('sources/'):
            logger.warning(f"Attempted to write to sources folder, \
                           redirecting to numpys: {original_key}")

        # Extract filename and extension
        filename = original_key.split('/')[-1]
        name_parts = filename.rsplit('.', 1)

        if len(name_parts) != 2:
            logger.error(f"Invalid filename format: {filename}")
            return None

        md5_hash, extension = name_parts  # hash of the source file

        new_filename = f"{md5_hash}.npy"
        new_key = f"numpys/{new_filename}"

        logger.info(f"New file key will be: {new_key}")

        # Save to S3 using S3Access
        success = s3_access.put_object(new_key, BytesIO(numpy_array))
        if not success:
            error_msg = f"Failed to save numpy array to {new_key}"
            logger.error(error_msg)
            return None

        logger.info(f"Successfully saved a numpy array  image: {new_key}")
        return new_key

    except Exception as e:
        logger.error(f"Error saving numpy array for an image: {str(e)}")
        return None


def process_image_file(file_key):
    """
    Process a valid image file: convert to black and white
    and save to numpys folder.
    """
    try:
        logger.info(f"Starting to process image file: {file_key}")

        file_object = get_file_object(file_key)
        if file_object is None:
            error_msg = f"Failed to retrieve file {file_key}"
            logger.error(error_msg)
            raise ClientError(
                error_response={'Error': {'Code': 'NoSuchKey',
                                'Message': error_msg}},
                operation_name='GetObject'
            )

        numpy_array = convert_to_numpy(file_object)
        if numpy_array is None:
            error_msg = f"Failed to convert image to \
                numpy array: {file_key}"
            logger.error(error_msg)
            raise Exception(error_msg)

        new_key = save_numpy_array(numpy_array, file_key)
        if new_key is None:
            error_msg = f"Failed to save black and white image: {file_key}"
            logger.error(error_msg)
            raise Exception(error_msg)

        logger.info(f"Successfully processed {file_key} -> {new_key}")
        return {
            'original_file': file_key,
            'new_file': new_key,
            'status': 'converted_to_numpy_array'
        }

    except ClientError as e:
        logger.error(f"S3 error processing image file {file_key}: {e}")
        raise e
    except Exception as e:
        logger.error(f"Unexpected error processing image file {file_key}: "
                     f"{str(e)}", exc_info=True)
        raise e


if __name__ == "__main__":
    test_event = {
        "Records": [
            {
                "s3": {
                    "bucket": {
                        "name": "your-test-bucket-name"
                    },
                    "object": {
                        "key": "sources/test-image.jpg"
                    }
                }
            }
        ]
    }
    test_context = {}

    # Set environment variable for testing
    os.environ['S3_BUCKET_NAME'] = 'your-test-bucket-name'

    result = lambda_handler(test_event, test_context)
    print(json.dumps(result, indent=2))
