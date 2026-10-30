# AWS App Runner Deployment Guide

## Overview
Deploy TalentMatch AI to AWS App Runner - a fully managed container service that automatically builds, deploys, and scales your application.

## Prerequisites
- AWS CLI configured
- Docker installed
- AWS account with App Runner permissions
- ECR repository created

## Step 1: Build and Push Docker Image

```bash
# Build image
docker build -t talentmatch-ai .

# Tag for ECR
docker tag talentmatch-ai:latest <account-id>.dkr.ecr.<region>.amazonaws.com/talentmatch-ai:latest

# Login to ECR
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com

# Create repository (if not exists)
aws ecr create-repository --repository-name talentmatch-ai --region <region>

# Push image
docker push <account-id>.dkr.ecr.<region>.amazonaws.com/talentmatch-ai:latest
```

## Step 2: Create App Runner Service

### Using AWS Console

1. Go to AWS App Runner Console
2. Click "Create service"
3. **Source**:
   - Repository type: Container registry
   - Provider: Amazon ECR
   - Container image URI: `<account-id>.dkr.ecr.<region>.amazonaws.com/talentmatch-ai:latest`
   - Deployment trigger: Manual (or Automatic for CI/CD)
4. **Deployment settings**:
   - Service name: `talentmatch-ai`
   - Port: `8080`
   - Start command: (leave empty, uses Dockerfile CMD)
5. **Configure service**:
   - CPU: 1 vCPU
   - Memory: 2 GB
   - Environment variables:
     ```
     AWS_REGION=us-east-1
     BEDROCK_MODEL_ID=anthropic.claude-3-sonnet-20240229-v1:0
     MAX_TOKENS=3000
     TEMPERATURE=0.0
     PORT=8080
     ```
6. **Auto scaling**:
   - Min instances: 1
   - Max instances: 5
   - Max concurrency: 100
7. **Health check**:
   - Protocol: HTTP
   - Path: `/api/status`
   - Interval: 5 seconds
   - Timeout: 2 seconds
   - Healthy threshold: 1
   - Unhealthy threshold: 5
8. Click "Create & deploy"

### Using AWS CLI

```bash
# Create service configuration file
cat > apprunner-service.json << EOF
{
  "ServiceName": "talentmatch-ai",
  "SourceConfiguration": {
    "ImageRepository": {
      "ImageIdentifier": "<account-id>.dkr.ecr.<region>.amazonaws.com/talentmatch-ai:latest",
      "ImageRepositoryType": "ECR",
      "ImageConfiguration": {
        "Port": "8080",
        "RuntimeEnvironmentVariables": {
          "AWS_REGION": "us-east-1",
          "BEDROCK_MODEL_ID": "anthropic.claude-3-sonnet-20240229-v1:0",
          "MAX_TOKENS": "3000",
          "TEMPERATURE": "0.0",
          "PORT": "8080"
        }
      }
    },
    "AutoDeploymentsEnabled": false
  },
  "InstanceConfiguration": {
    "Cpu": "1 vCPU",
    "Memory": "2 GB"
  },
  "HealthCheckConfiguration": {
    "Protocol": "HTTP",
    "Path": "/api/status",
    "Interval": 5,
    "Timeout": 2,
    "HealthyThreshold": 1,
    "UnhealthyThreshold": 5
  },
  "AutoScalingConfigurationArn": "arn:aws:apprunner:<region>:<account-id>:autoscalingconfiguration/DefaultConfiguration/1/00000000000000000000000000000001"
}
EOF

# Create service
aws apprunner create-service --cli-input-json file://apprunner-service.json
```

## Step 3: Configure IAM Role

App Runner needs an IAM role to:
1. Pull images from ECR
2. Access AWS Bedrock

### ECR Access Role

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": "*"
    }
  ]
}
```

### Instance Role (for Bedrock access)

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
    }
  ]
}
```

## Step 4: Configure Custom Domain (Optional)

```bash
# Associate custom domain
aws apprunner associate-custom-domain \
  --service-arn arn:aws:apprunner:<region>:<account-id>:service/talentmatch-ai/<service-id> \
  --domain-name talentmatch.yourdomain.com

# Get DNS records to configure
aws apprunner describe-custom-domains \
  --service-arn arn:aws:apprunner:<region>:<account-id>:service/talentmatch-ai/<service-id>
```

## Step 5: Test the Deployment

```bash
# Get service URL
aws apprunner describe-service \
  --service-arn arn:aws:apprunner:<region>:<account-id>:service/talentmatch-ai/<service-id> \
  --query 'Service.ServiceUrl' \
  --output text

# Test endpoint
curl https://<service-id>.<region>.awsapprunner.com/api/status
```

## Configuration Notes

### Instance Configuration
- **CPU**: 1 vCPU (can increase to 2 or 4 vCPU)
- **Memory**: 2 GB (can increase to 4 GB)
- **Port**: 8080 (matches Dockerfile EXPOSE)

### Auto Scaling
- **Min instances**: 1 (always running)
- **Max instances**: 5 (adjust based on load)
- **Max concurrency**: 100 requests per instance

### Health Check
- **Path**: `/api/status` (returns JSON)
- **Interval**: 5 seconds
- **Timeout**: 2 seconds
- **Healthy threshold**: 1 successful check
- **Unhealthy threshold**: 5 failed checks

## Updating the Service

```bash
# Build new image
docker build -t talentmatch-ai .
docker tag talentmatch-ai:latest <account-id>.dkr.ecr.<region>.amazonaws.com/talentmatch-ai:latest
docker push <account-id>.dkr.ecr.<region>.amazonaws.com/talentmatch-ai:latest

# Update App Runner service (if auto-deploy is disabled)
aws apprunner start-deployment \
  --service-arn arn:aws:apprunner:<region>:<account-id>:service/talentmatch-ai/<service-id>
```

## Monitoring

### CloudWatch Logs
```bash
# View logs
aws logs tail /aws/apprunner/talentmatch-ai/<service-id>/application --follow
```

### CloudWatch Metrics
- `2XXStatusResponses` - Successful requests
- `4XXStatusResponses` - Client errors
- `5XXStatusResponses` - Server errors
- `RequestLatency` - Response time
- `ActiveInstances` - Running instances
- `CPUUtilization` - CPU usage
- `MemoryUtilization` - Memory usage

### View Metrics
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/AppRunner \
  --metric-name RequestLatency \
  --dimensions Name=ServiceName,Value=talentmatch-ai \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Average
```

## Troubleshooting

### Service fails to start
- Check CloudWatch logs for errors
- Verify ECR image is accessible
- Ensure PORT=8080 is set
- Check IAM role permissions

### Health check failures
- Verify `/api/status` endpoint works
- Check application logs
- Ensure port 8080 is exposed
- Verify health check timeout is adequate

### High latency
- Increase instance CPU/memory
- Increase max instances
- Reduce MAX_TOKENS for faster Bedrock responses
- Enable auto-scaling

### Out of memory
- Increase memory to 4 GB
- Reduce concurrent requests per instance
- Optimize application code

## Cost Estimation

**App Runner Pricing** (us-east-1):
- Compute: $0.064 per vCPU-hour + $0.007 per GB-hour
- Requests: $0.40 per million requests
- Build: $0.005 per build minute (if using source code)

**Example**:
- 1 instance, 1 vCPU, 2 GB memory, 24/7
- 10,000 requests/month
- Cost: ~$60/month

**Additional Costs**:
- ECR storage: ~$0.10/GB/month
- Bedrock API calls: Variable
- Data transfer: $0.09/GB (first 10 TB)

## Best Practices

1. **Use Auto Scaling**: Set min=1, max=5 for production
2. **Enable Auto Deploy**: For CI/CD workflows
3. **Configure Custom Domain**: For production use
4. **Monitor Metrics**: Set up CloudWatch alarms
5. **Use Secrets Manager**: For sensitive environment variables
6. **Enable VPC Connector**: If accessing private resources
7. **Set Resource Limits**: Prevent runaway costs
8. **Regular Updates**: Keep dependencies up to date
