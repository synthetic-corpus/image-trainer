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


def convert_to_black_white(file_object):
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

        # Convert to grayscale (black and white)
        bw_image = image.convert('L')
        output_buffer = BytesIO()
        bw_image.save(output_buffer, format=image.format or 'JPEG')
        bw_bytes = output_buffer.getvalue()

        logger.info("Successfully converted image to black and white")
        return bw_bytes

    except Exception as e:
        logger.error(f"Error converting image to black and white: {str(e)}")
        return None


def save_bw_image(file_object, original_key):
    """
    Function 3: Save black and white image to S3 monochrome folder.

    Args:
        file_object (bytes): Black and white image as bytes
        original_key (str): Original S3 key of the source file

    Returns:
        str: New S3 key of the saved file, or None if error
    """
    try:
        logger.info(f"Saving black and white image for: {original_key}")

        # DEFENSIVE: Ensure we never write back to sources folder
        if original_key.startswith('sources/'):
            logger.warning(f"Attempted to write to sources folder, \
                           redirecting to monochrome: {original_key}")

        # Extract filename and extension
        filename = original_key.split('/')[-1]
        name_parts = filename.rsplit('.', 1)

        if len(name_parts) != 2:
            logger.error(f"Invalid filename format: {filename}")
            return None

        base_name, extension = name_parts

        # Create new filename with _bw suffix
        new_filename = f"{base_name}_bw.{extension}"
        new_key = f"monochrome/{new_filename}"

        logger.info(f"New file key will be: {new_key}")

        # Save to S3 using S3Access
        success = s3_access.put_object(new_key, BytesIO(file_object))
        if not success:
            error_msg = f"Failed to save black and white image to {new_key}"
            logger.error(error_msg)
            return None

        logger.info(f"Successfully saved black and white image: {new_key}")
        return new_key

    except Exception as e:
        logger.error(f"Error saving black and white image: {str(e)}")
        return None


def process_image_file(file_key):
    """
    Process a valid image file: convert to black and white
    and save to monochrome folder.
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

        bw_file_object = convert_to_black_white(file_object)
        if bw_file_object is None:
            error_msg = f"Failed to convert image to \
                black and white: {file_key}"
            logger.error(error_msg)
            raise Exception(error_msg)

        new_key = save_bw_image(bw_file_object, file_key)
        if new_key is None:
            error_msg = f"Failed to save black and white image: {file_key}"
            logger.error(error_msg)
            raise Exception(error_msg)

        logger.info(f"Successfully processed {file_key} -> {new_key}")
        return {
            'original_file': file_key,
            'new_file': new_key,
            'status': 'converted_to_bw'
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
