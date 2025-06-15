#################################################################
# Process files uploaded to the upload/ folder in S3
# This lambda function is triggered by S3 events when files are
# uploaded to the upload/ folder.
# It processes the files by calculating the MD5 hash and copying
# the file to the sources/ folder.
# It also deletes the original file from the upload/ folder.
#################################################################
import hashlib
import json
import logging
import os
import sys
from urllib.parse import unquote_plus
from botocore.exceptions import ClientError, NoCredentialsError, \
    ParamValidationError

# Custom modules
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))
from modules import S3Access  # noqa: E402


# Configure CloudWatch logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize S3 access
s3_access = None


def lambda_handler(event, context):
    """
    AWS Lambda handler for processing uploaded files in S3.
    Triggered by S3 events when files are uploaded to the upload/ folder.
    """
    global s3_access

    logger.info(f"Starting file processing. Request ID: "
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

            # Skip if not in upload folder (shouldn't happen due to filter,
            # but safety check)
            if not object_key.startswith('upload/'):
                logger.warning(f"Skipping file not in upload folder: "
                               f"{object_key}")
                continue

            # Skip the folder itself
            if object_key.endswith('/'):
                logger.info(f"Skipping folder: {object_key}")
                continue

            # Extract filename from key
            filename = object_key.split('/')[-1]

            # Check if file has valid image extension
            if is_valid_image_file(filename):
                # Process valid image file
                result = process_image_file(object_key)
                processed_files.append(result)
                logger.info(f"Successfully processed: {object_key}")
            else:
                # Delete invalid file
                delete_file(object_key)
                processed_files.append({
                    'original_file': object_key,
                    'status': 'deleted_invalid_extension'
                })
                logger.info(f"Deleted invalid file: {object_key}")

        logger.info(f"File processing completed. Processed "
                    f"{len(processed_files)} files")
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'File processing completed',
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
        error_msg = f"Unexpected error processing files: {str(e)}"
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


def process_image_file(file_key):
    """
    Process a valid image file: calculate MD5 hash and copy to sources folder.
    """
    try:
        logger.info(f"Starting to process image file: {file_key}")

        # Get the file object using S3Access
        file_content = s3_access.get_object(file_key)
        if file_content is None:
            error_msg = f"Failed to retrieve file {file_key}"
            logger.error(error_msg)
            raise ClientError(
                error_response={'Error': {'Code': 'NoSuchKey',
                                'Message': error_msg}},
                operation_name='GetObject'
            )

        # Calculate MD5 hash for naming purposes.
        md5_hash = hashlib.md5(file_content).hexdigest()
        logger.info(f"Calculated MD5 hash for {file_key}: {md5_hash}")

        # Get file extension
        original_filename = file_key.split('/')[-1]
        file_extension = '.' + original_filename.split('.')[-1].lower()

        new_filename = f"{md5_hash}{file_extension}"
        new_key = f"sources/{new_filename}"
        logger.info(f"New file key will be: {new_key}")

        if s3_access.object_exists(new_key):
            logger.info(f"File with MD5 {md5_hash} already exists in "
                        f"sources, skipping copy")
            s3_access.delete_object(file_key)
            return {
                'original_file': file_key,
                'existing_file': new_key,
                'md5_hash': md5_hash,
                'status': 'duplicate_removed'
            }

        # Copy file to sources folder with new name using S3Access
        success = s3_access.rename_key(file_key, new_key)
        if not success:
            error_msg = f"Failed to rename {file_key} to {new_key}"
            logger.error(error_msg)
            raise ClientError(
                error_response={'Error': {'Code': 'CopyObjectFailed',
                                'Message': error_msg}},
                operation_name='CopyObject'
            )

        logger.info(f"Successfully processed {file_key} -> {new_key}")
        return {
            'original_file': file_key,
            'new_file': new_key,
            'md5_hash': md5_hash,
            'status': 'processed'
        }

    except ClientError as e:
        logger.error(f"S3 error processing image file {file_key}: {e}")
        raise e
    except Exception as e:
        logger.error(f"Unexpected error processing image file {file_key}: "
                     f"{str(e)}", exc_info=True)
        raise e


def delete_file(file_key):
    """Delete an invalid file from S3."""
    try:
        logger.info(f"Attempting to delete invalid file: {file_key}")
        success = s3_access.delete_object(file_key)
        if success:
            logger.info(f"Successfully deleted invalid file: {file_key}")
        else:
            logger.warning(f"Failed to delete file: {file_key}")
    except ClientError as e:
        logger.error(f"S3 error deleting file {file_key}: {e}")
        raise e
    except Exception as e:
        logger.error(f"Unexpected error deleting file {file_key}: "
                     f"{str(e)}", exc_info=True)
        raise e


if __name__ == "__main__":
    # Mock S3 event for local testing
    test_event = {
        "Records": [
            {
                "s3": {
                    "bucket": {
                        "name": "your-test-bucket-name"
                    },
                    "object": {
                        "key": "upload/test-image.jpg"
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
