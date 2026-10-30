# Use official AWS Lambda Python base image
FROM public.ecr.aws/lambda/python:3.11

# Copy requirements first for better caching
COPY requirements.txt ${LAMBDA_TASK_ROOT}/
RUN pip install --no-cache-dir -r ${LAMBDA_TASK_ROOT}/requirements.txt

# Install Lambda Web Adapter as a Lambda Extension
ADD https://github.com/awslabs/aws-lambda-web-adapter/releases/download/v0.8.4/lambda-adapter-linux-amd64.zip /tmp/lambda-adapter.zip
RUN unzip /tmp/lambda-adapter.zip -d /opt/extensions && \
    chmod +x /opt/extensions/lambda-adapter && \
    rm /tmp/lambda-adapter.zip

# Copy application code
COPY . ${LAMBDA_TASK_ROOT}/

# Create uploads directory
RUN mkdir -p ${LAMBDA_TASK_ROOT}/uploads/videos

# Environment variables for Lambda Web Adapter
ENV AWS_LWA_INVOKE_MODE=response_stream
ENV AWS_LWA_PORT=8080
ENV PORT=8080

# Start command - Lambda Web Adapter will intercept and forward to this
CMD ["sh", "-c", "exec gunicorn --bind 0.0.0.0:8080 --workers 1 --threads 4 --timeout 300 app_simple:app"]
