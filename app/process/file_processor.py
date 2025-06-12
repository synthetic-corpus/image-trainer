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
import os
from urllib.parse import unquote_plus

import boto3

# Initialize S3 client
s3_client = boto3.client('s3')


def lambda_handler(event, context):
    """
    AWS Lambda handler for processing uploaded files in S3.
    Triggered by S3 events when files are uploaded to the upload/ folder.
    """
    # Get bucket name from environment variable
    bucket_name = os.environ.get('S3_BUCKET_NAME')
    if not bucket_name:
        return {
            'statusCode': 500,
            'body': 'S3_BUCKET_NAME environment variable not set'
        }

    try:
        processed_files = []

        # Process each record in the S3 event
        for record in event['Records']:
            # Extract bucket and object key from the event
            event_bucket = record['s3']['bucket']['name']
            object_key = unquote_plus(record['s3']['object']['key'])

            print(f"Processing file: {object_key} from bucket: {event_bucket}")

            # Verify this is the correct bucket
            if event_bucket != bucket_name:
                print(f"Skipping file from different bucket: {event_bucket}")
                continue

            # Skip if not in upload folder (shouldn't happen due to filter,
            # but safety check)
            if not object_key.startswith('upload/'):
                print(f"Skipping file not in upload folder: {object_key}")
                continue

            # Skip the folder itself
            if object_key.endswith('/'):
                print(f"Skipping folder: {object_key}")
                continue

            # Extract filename from key
            filename = object_key.split('/')[-1]

            # Check if file has valid image extension
            if is_valid_image_file(filename):
                # Process valid image file
                result = process_image_file(bucket_name, object_key)
                processed_files.append(result)
                print(f"Successfully processed: {object_key}")
            else:
                # Delete invalid file
                delete_file(bucket_name, object_key)
                processed_files.append({
                    'original_file': object_key,
                    'status': 'deleted_invalid_extension'
                })
                print(f"Deleted invalid file: {object_key}")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'File processing completed',
                'processed_files': processed_files
            })
        }

    except Exception as e:
        print(f"Error processing files: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': f'Error processing files: {str(e)}'
            })
        }


def is_valid_image_file(filename):
    """Check if the file has a valid image extension."""
    valid_extensions = ['.jpeg', '.jpg', '.png']
    filename_lower = filename.lower()
    return any(filename_lower.endswith(ext) for ext in valid_extensions)


def process_image_file(bucket_name, file_key):
    """
    Process a valid image file: calculate MD5 hash and copy to sources folder.
    """
    try:
        # Get the file object
        response = s3_client.get_object(Bucket=bucket_name, Key=file_key)
        file_content = response['Body'].read()

        # Calculate MD5 hash
        md5_hash = hashlib.md5(file_content).hexdigest()

        # Get file extension
        original_filename = file_key.split('/')[-1]
        file_extension = '.' + original_filename.split('.')[-1].lower()

        # Create new filename with MD5 hash
        new_filename = f"{md5_hash}{file_extension}"
        new_key = f"sources/{new_filename}"

        # Check if file with same MD5 already exists in sources
        try:
            s3_client.head_object(Bucket=bucket_name, Key=new_key)
            print(f"File with MD5 {md5_hash} already exists in sources, "
                  f"skipping copy")
            # Delete the duplicate upload
            s3_client.delete_object(Bucket=bucket_name, Key=file_key)
            return {
                'original_file': file_key,
                'existing_file': new_key,
                'md5_hash': md5_hash,
                'status': 'duplicate_removed'
            }
        except s3_client.exceptions.NoSuchKey:
            # File doesn't exist, proceed with copy
            pass

        # Copy file to sources folder with new name
        s3_client.copy_object(
            Bucket=bucket_name,
            CopySource={'Bucket': bucket_name, 'Key': file_key},
            Key=new_key
        )

        # Delete original file from upload folder
        s3_client.delete_object(Bucket=bucket_name, Key=file_key)

        return {
            'original_file': file_key,
            'new_file': new_key,
            'md5_hash': md5_hash,
            'status': 'processed'
        }

    except Exception as e:
        print(f"Error processing image file {file_key}: {str(e)}")
        raise e


def delete_file(bucket_name, file_key):
    """Delete an invalid file from S3."""
    try:
        s3_client.delete_object(Bucket=bucket_name, Key=file_key)
        print(f"Deleted invalid file: {file_key}")
    except Exception as e:
        print(f"Error deleting file {file_key}: {str(e)}")
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
