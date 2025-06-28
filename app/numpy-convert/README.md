# Make Numpy Lambda Function

This Lambda function processes images uploaded to the S3 bucket's `sources/` folder and converts them to black and white versions, saving them to the `monochrome/` folder.

## Functionality

The Lambda function consists of three main functions:

### 1. `get_file_object(file_key)`
- Retrieves a file object from the S3 sources folder
- Returns the file content as bytes
- Uses the S3Access module for S3 operations

### 2. `convert_to_black_white(file_object)`
- Takes a file object (bytes) as input
- Converts the image to black and white using PIL (Pillow)
- Returns the black and white image as bytes

### 3. `save_bw_image(file_object, original_key)`
- Saves the black and white image to the S3 monochrome folder
- Appends `_bw` to the filename before the extension
- Example: `myimage123.jpeg` becomes `myimage123_bw.jpeg`

## Trigger

This Lambda function is triggered by S3 events when files are uploaded to the `sources/` folder.

## Supported Image Formats

- `.jpg`
- `.jpeg`
- `.png`

## Dependencies

- `boto3` - AWS SDK for Python
- `Pillow` - Python Imaging Library for image processing
- `numpy` - Numerical computing library
- Custom `s3_access.py` module for S3 operations

## Environment Variables

- `S3_BUCKET_NAME` - The name of the S3 bucket containing the images

## File Structure

```
app/numpy-convert/
├── make_numpy.py      # Main Lambda function
├── requirements.txt   # Python dependencies
└── README.md         # This documentation
```

## Example Usage

When a file `example.jpg` is uploaded to `sources/example.jpg`, the Lambda function will:
1. Retrieve the file from S3
2. Convert it to black and white
3. Save it as `monochrome/example_bw.jpg` 