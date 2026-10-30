# TalentMatch AI - Docker Deployment

## Quick Start

### Local Development

```bash
# Using Docker Compose
docker-compose up

# Access at http://localhost:5000
```

### Build and Run Manually

```bash
# Build
docker build -t talentmatch-ai .

# Run
docker run -p 5000:8080 \
  -e AWS_REGION=us-east-1 \
  -e AWS_ACCESS_KEY_ID=your-key \
  -e AWS_SECRET_ACCESS_KEY=your-secret \
  -e BEDROCK_MODEL_ID=anthropic.claude-3-sonnet-20240229-v1:0 \
  talentmatch-ai
```

## AWS Deployment Options

### 1. AWS Lambda (Serverless)
**Best for**: Variable traffic, pay-per-use
- ✅ No infrastructure management
- ✅ Automatic scaling
- ✅ Pay only for execution time
- ❌ Cold start latency
- ❌ 15-minute timeout limit

**Cost**: ~$1-5/month for low traffic

[📖 Full Lambda Deployment Guide](deployment/lambda-deploy.md)

### 2. AWS App Runner (Managed Containers)
**Best for**: Simple deployment, predictable traffic
- ✅ Fully managed
- ✅ Auto-scaling
- ✅ Built-in load balancing
- ✅ Custom domains
- ❌ Higher cost than Lambda

**Cost**: ~$60/month for 24/7 operation

[📖 Full App Runner Deployment Guide](deployment/apprunner-deploy.md)

### 3. AWS ECS/Fargate (Full Control)
**Best for**: Production workloads, high availability
- ✅ Full container orchestration
- ✅ Multi-AZ deployment
- ✅ Advanced networking
- ✅ Integration with AWS services
- ❌ More complex setup

**Cost**: ~$120/month for 2 tasks, 24/7

[📖 Full ECS Deployment Guide](deployment/ecs-deploy.md)

## Comparison Matrix

| Feature | Lambda | App Runner | ECS/Fargate |
|---------|--------|------------|-------------|
| Setup Complexity | ⭐ Easy | ⭐⭐ Moderate | ⭐⭐⭐ Complex |
| Management | Fully Managed | Fully Managed | Semi-Managed |
| Scaling | Automatic | Automatic | Configurable |
| Cold Start | Yes (~1-2s) | Minimal | No |
| Max Timeout | 15 minutes | No limit | No limit |
| Custom VPC | Yes | Yes | Yes |
| Load Balancer | Function URL | Built-in | ALB/NLB |
| Cost (Low Traffic) | $ | $$ | $$$ |
| Cost (High Traffic) | $$ | $$$ | $$ |

## Environment Variables

All deployment methods require these environment variables:

```bash
AWS_REGION=us-east-1
BEDROCK_MODEL_ID=anthropic.claude-3-sonnet-20240229-v1:0
MAX_TOKENS=3000
TEMPERATURE=0.0
PORT=8080
```

## IAM Permissions Required

All deployments need Bedrock access:

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

## Testing Your Deployment

```bash
# Health check
curl https://your-deployment-url/api/status

# Expected response:
# {"success": true, "resume_count": 0, "has_job_description": false, "can_analyze": false}
```

## Monitoring

All deployments automatically send logs to CloudWatch:

```bash
# View logs
aws logs tail /aws/<service>/talentmatch-ai --follow
```

## Troubleshooting

### Common Issues

**Docker build fails**
- Ensure Docker is running
- Check internet connection
- Verify requirements.txt is valid

**Container won't start**
- Check CloudWatch logs
- Verify environment variables
- Ensure port 8080 is exposed

**Bedrock access denied**
- Verify IAM role has Bedrock permissions
- Check AWS region supports Bedrock
- Ensure model ID is correct

**High latency**
- Increase container memory
- Reduce MAX_TOKENS
- Use provisioned concurrency (Lambda)
- Enable auto-scaling

## Next Steps

1. Choose your deployment method
2. Follow the specific deployment guide
3. Configure environment variables
4. Set up monitoring and alerts
5. Configure custom domain (optional)
6. Implement CI/CD pipeline

## Support

For detailed deployment instructions, see:
- [Lambda Deployment](deployment/lambda-deploy.md)
- [App Runner Deployment](deployment/apprunner-deploy.md)
- [ECS Deployment](deployment/ecs-deploy.md)
