# AWS Lambda Deployment Guide

## Overview
Deploy TalentMatch AI to AWS Lambda using Lambda Web Adapter. This allows your Flask application to run on Lambda without code changes.

## Prerequisites
- AWS CLI configured
- Docker installed
- AWS account with Lambda permissions
- ECR repository created

## Step 1: Build Docker Image for Lambda

```bash
# Build for Linux/AMD64 (Lambda architecture)
docker build --platform linux/amd64 -t talentmatch-lambda .

# Tag for ECR
docker tag talentmatch-lambda:latest <account-id>.dkr.ecr.<region>.amazonaws.com/talentmatch-lambda:latest
```

## Step 2: Push to Amazon ECR

```bash
# Login to ECR
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com

# Create repository (if not exists)
aws ecr create-repository --repository-name talentmatch-lambda --region <region>

# Push image
docker push <account-id>.dkr.ecr.<region>.amazonaws.com/talentmatch-lambda:latest
```

## Step 3: Create Lambda Function

### Using AWS Console

1. Go to AWS Lambda Console
2. Click "Create function"
3. Select "Container image"
4. Function name: `talentmatch-ai`
5. Container image URI: `<account-id>.dkr.ecr.<region>.amazonaws.com/talentmatch-lambda:latest`
6. Architecture: `x86_64`
7. Click "Create function"

### Using AWS CLI

```bash
aws lambda create-function \
  --function-name talentmatch-ai \
  --package-type Image \
  --code ImageUri=<account-id>.dkr.ecr.<region>.amazonaws.com/talentmatch-lambda:latest \
  --role arn:aws:iam::<account-id>:role/lambda-execution-role \
  --timeout 300 \
  --memory-size 2048 \
  --environment Variables="{AWS_REGION=us-east-1,BEDROCK_MODEL_ID=anthropic.claude-3-sonnet-20240229-v1:0}"
```

## Step 4: Add Lambda Web Adapter Layer

The Lambda Web Adapter allows Flask to run on Lambda.

### Using AWS Console
1. Go to your Lambda function
2. Scroll to "Layers"
3. Click "Add a layer"
4. Select "AWS layers"
5. Choose: `LambdaAdapterLayerX86` (for x86_64)
6. Version: Latest
7. Click "Add"

### Using AWS CLI

```bash
# Get latest Lambda Web Adapter ARN for your region
# Visit: https://github.com/awslabs/aws-lambda-web-adapter

aws lambda update-function-configuration \
  --function-name talentmatch-ai \
  --layers arn:aws:lambda:<region>:753240598075:layer:LambdaAdapterLayerX86:20
```

## Step 5: Configure Environment Variables

```bash
aws lambda update-function-configuration \
  --function-name talentmatch-ai \
  --environment Variables="{
    AWS_REGION=us-east-1,
    BEDROCK_MODEL_ID=anthropic.claude-3-sonnet-20240229-v1:0,
    MAX_TOKENS=3000,
    TEMPERATURE=0.0,
    PORT=8080,
    AWS_LWA_INVOKE_MODE=response_stream
  }"
```

## Step 6: Configure IAM Role

Your Lambda execution role needs:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ],
      "Resource": "arn:aws:bedrock:*::foundation-model/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

## Step 7: Create Function URL (Optional)

For direct HTTP access:

```bash
aws lambda create-function-url-config \
  --function-name talentmatch-ai \
  --auth-type NONE \
  --cors AllowOrigins="*",AllowMethods="*",AllowHeaders="*"

# Get the URL
aws lambda get-function-url-config --function-name talentmatch-ai
```

## Step 8: Test the Deployment

```bash
# Test via Function URL
curl https://<function-url-id>.lambda-url.<region>.on.aws/api/status

# Expected response:
# {"success": true, "resume_count": 0, "has_job_description": false, "can_analyze": false}
```

## Configuration Notes

### Lambda Settings
- **Timeout**: 300 seconds (5 minutes) - Bedrock analysis can take time
- **Memory**: 2048 MB - Recommended for PDF processing
- **Ephemeral Storage**: 512 MB (default) - Increase if processing large files

### Environment Variables
- `PORT=8080` - Required for Lambda Web Adapter
- `AWS_LWA_INVOKE_MODE=response_stream` - For streaming responses
- `PYTHONUNBUFFERED=1` - Already set in Dockerfile

### Cold Start Optimization
- Use provisioned concurrency for production
- Keep dependencies minimal
- Consider Lambda SnapStart (for Java, not Python yet)

## Updating the Function

```bash
# Build new image
docker build --platform linux/amd64 -t talentmatch-lambda .

# Push to ECR
docker tag talentmatch-lambda:latest <account-id>.dkr.ecr.<region>.amazonaws.com/talentmatch-lambda:latest
docker push <account-id>.dkr.ecr.<region>.amazonaws.com/talentmatch-lambda:latest

# Update Lambda function
aws lambda update-function-code \
  --function-name talentmatch-ai \
  --image-uri <account-id>.dkr.ecr.<region>.amazonaws.com/talentmatch-lambda:latest
```

## Monitoring

```bash
# View logs
aws logs tail /aws/lambda/talentmatch-ai --follow

# View metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Duration \
  --dimensions Name=FunctionName,Value=talentmatch-ai \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Average
```

## Troubleshooting

### Function times out
- Increase timeout to 300 seconds
- Increase memory to 2048 MB or higher
- Check Bedrock model availability

### Out of memory
- Increase memory allocation
- Reduce MAX_TOKENS in environment variables
- Process fewer resumes per request

### Lambda Web Adapter not working
- Verify layer ARN is correct for your region
- Ensure PORT=8080 is set
- Check that CMD in Dockerfile starts the web server

## Cost Estimation

**Lambda Pricing** (us-east-1):
- Requests: $0.20 per 1M requests
- Duration: $0.0000166667 per GB-second
- Example: 1000 requests/month, 30s avg, 2GB memory = ~$1/month

**Additional Costs**:
- ECR storage: ~$0.10/GB/month
- Bedrock API calls: Variable based on usage
- Data transfer: Minimal for typical usage
