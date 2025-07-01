# Multi-stage build for optimized Lambda container
FROM public.ecr.aws/lambda/python:3.11 as builder

# Install build dependencies
RUN yum install -y gcc

# Copy requirements and install dependencies
COPY process/requirements.txt ${LAMBDA_TASK_ROOT}
RUN pip install --no-cache-dir -r requirements.txt -t ${LAMBDA_TASK_ROOT}

# Production stage
FROM public.ecr.aws/lambda/python:3.11

# Copy installed dependencies from builder stage
COPY --from=builder ${LAMBDA_TASK_ROOT} ${LAMBDA_TASK_ROOT}

# Copy modules directory for S3Access
COPY modules ${LAMBDA_TASK_ROOT}/modules

# Copy database models
COPY app/db_models ${LAMBDA_TASK_ROOT}/db_models

# Copy function code
COPY process/file_processor.py ${LAMBDA_TASK_ROOT}

# Set environment variable for S3 bucket name
ENV S3_BUCKET_NAME=""

# Database environment variables
ENV DB_HOST=""
ENV DB_PORT="5432"
ENV DB_NAME=""
ENV DB_USER=""
ENV DB_PASSWORD=""

# Set the CMD to your handler
CMD ["file_processor.lambda_handler"]
