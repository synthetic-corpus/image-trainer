# Multi-stage build for optimized Lambda container
FROM public.ecr.aws/lambda/python:3.11 as builder

# Install build dependencies
RUN yum install -y gcc

# Copy requirements and install dependencies
COPY requirements.txt ${LAMBDA_TASK_ROOT}
RUN pip install --no-cache-dir -r requirements.txt -t ${LAMBDA_TASK_ROOT}

# Production stage
FROM public.ecr.aws/lambda/python:3.11

# Copy installed dependencies from builder stage
COPY --from=builder ${LAMBDA_TASK_ROOT} ${LAMBDA_TASK_ROOT}

# Copy modules directory for S3Access
COPY ../modules ${LAMBDA_TASK_ROOT}/modules

# Copy function code
COPY file_processor.py ${LAMBDA_TASK_ROOT}

# Set environment variable for S3 bucket name
ENV S3_BUCKET_NAME=""

# Set the CMD to your handler
CMD ["file_processor.lambda_handler"]
