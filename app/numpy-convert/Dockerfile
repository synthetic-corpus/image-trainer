# Multi-stage build for optimized Lambda container
FROM public.ecr.aws/lambda/python:3.11 as builder

# Install build dependencies
RUN yum install -y gcc gcc-c++ libjpeg-devel libpng-devel freetype-devel

# Copy requirements and install dependencies
COPY numpy-convert/requirements.txt ${LAMBDA_TASK_ROOT}
RUN pip install --no-cache-dir -r requirements.txt -t ${LAMBDA_TASK_ROOT}

# Production stage
FROM public.ecr.aws/lambda/python:3.11

# Install runtime dependencies for Pillow
RUN yum install -y libjpeg libpng freetype

# Copy installed dependencies from builder stage
COPY --from=builder ${LAMBDA_TASK_ROOT} ${LAMBDA_TASK_ROOT}

# Copy modules directory for S3Access
COPY modules ${LAMBDA_TASK_ROOT}/modules

# Copy function code
COPY numpy-convert/make_numpy.py ${LAMBDA_TASK_ROOT}

# Set environment variable for S3 bucket name
ENV S3_BUCKET_NAME=""

# Set the CMD to your handler
CMD ["make_numpy.lambda_handler"] 