# Use AWS Lambda Python runtime as base image
FROM public.ecr.aws/lambda/python:3.11

# Set working directory
WORKDIR ${LAMBDA_TASK_ROOT}

# Copy requirements file
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy function code
COPY init_database.py .

# Copy Alembic configuration (for future use)
COPY alembic.ini .

# Set the CMD to your handler
CMD [ "init_database.lambda_handler" ] 