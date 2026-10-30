# AWS ECS/Fargate Deployment Guide

## Overview
Deploy TalentMatch AI to AWS ECS (Elastic Container Service) with Fargate for serverless container orchestration.

## Prerequisites
- AWS CLI configured
- Docker installed
- AWS account with ECS permissions
- VPC with public subnets (or NAT Gateway for private subnets)

## Step 1: Build and Push Docker Image

```bash
# Build image
docker build -t talentmatch-ai .

# Tag for ECR
docker tag talentmatch-ai:latest <account-id>.dkr.ecr.<region>.amazonaws.com/talentmatch-ai:latest

# Login to ECR
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com

# Create repository
aws ecr create-repository --repository-name talentmatch-ai --region <region>

# Push image
docker push <account-id>.dkr.ecr.<region>.amazonaws.com/talentmatch-ai:latest
```

## Step 2: Create ECS Cluster

```bash
aws ecs create-cluster \
  --cluster-name talentmatch-cluster \
  --capacity-providers FARGATE FARGATE_SPOT \
  --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1
```

## Step 3: Create Task Definition

Create `task-definition.json`:

```json
{
  "family": "talentmatch-ai",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "1024",
  "memory": "2048",
  "executionRoleArn": "arn:aws:iam::<account-id>:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::<account-id>:role/ecsTaskRole",
  "containerDefinitions": [
    {
      "name": "talentmatch-ai",
      "image": "<account-id>.dkr.ecr.<region>.amazonaws.com/talentmatch-ai:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "AWS_REGION",
          "value": "us-east-1"
        },
        {
          "name": "BEDROCK_MODEL_ID",
          "value": "anthropic.claude-3-sonnet-20240229-v1:0"
        },
        {
          "name": "MAX_TOKENS",
          "value": "3000"
        },
        {
          "name": "TEMPERATURE",
          "value": "0.0"
        },
        {
          "name": "PORT",
          "value": "8080"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/talentmatch-ai",
          "awslogs-region": "<region>",
          "awslogs-stream-prefix": "ecs",
          "awslogs-create-group": "true"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8080/api/status || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
```

Register the task definition:

```bash
aws ecs register-task-definition --cli-input-json file://task-definition.json
```

## Step 4: Create Application Load Balancer

```bash
# Create security group for ALB
aws ec2 create-security-group \
  --group-name talentmatch-alb-sg \
  --description "Security group for TalentMatch ALB" \
  --vpc-id <vpc-id>

# Allow HTTP traffic
aws ec2 authorize-security-group-ingress \
  --group-id <alb-sg-id> \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

# Create ALB
aws elbv2 create-load-balancer \
  --name talentmatch-alb \
  --subnets <subnet-1> <subnet-2> \
  --security-groups <alb-sg-id> \
  --scheme internet-facing \
  --type application

# Create target group
aws elbv2 create-target-group \
  --name talentmatch-tg \
  --protocol HTTP \
  --port 8080 \
  --vpc-id <vpc-id> \
  --target-type ip \
  --health-check-path /api/status \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3

# Create listener
aws elbv2 create-listener \
  --load-balancer-arn <alb-arn> \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=<target-group-arn>
```

## Step 5: Create ECS Service

```bash
# Create security group for ECS tasks
aws ec2 create-security-group \
  --group-name talentmatch-ecs-sg \
  --description "Security group for TalentMatch ECS tasks" \
  --vpc-id <vpc-id>

# Allow traffic from ALB
aws ec2 authorize-security-group-ingress \
  --group-id <ecs-sg-id> \
  --protocol tcp \
  --port 8080 \
  --source-group <alb-sg-id>

# Create service
aws ecs create-service \
  --cluster talentmatch-cluster \
  --service-name talentmatch-service \
  --task-definition talentmatch-ai \
  --desired-count 2 \
  --launch-type FARGATE \
  --platform-version LATEST \
  --network-configuration "awsvpcConfiguration={subnets=[<subnet-1>,<subnet-2>],securityGroups=[<ecs-sg-id>],assignPublicIp=ENABLED}" \
  --load-balancers targetGroupArn=<target-group-arn>,containerName=talentmatch-ai,containerPort=8080 \
  --health-check-grace-period-seconds 60
```

## Step 6: Configure Auto Scaling

```bash
# Register scalable target
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/talentmatch-cluster/talentmatch-service \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 1 \
  --max-capacity 10

# Create scaling policy (CPU-based)
aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id service/talentmatch-cluster/talentmatch-service \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name cpu-scaling-policy \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration file://scaling-policy.json
```

Create `scaling-policy.json`:

```json
{
  "TargetValue": 70.0,
  "PredefinedMetricSpecification": {
    "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
  },
  "ScaleInCooldown": 300,
  "ScaleOutCooldown": 60
}
```

## Step 7: Configure IAM Roles

### Task Execution Role

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
        "ecr:BatchGetImage",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:CreateLogGroup"
      ],
      "Resource": "*"
    }
  ]
}
```

### Task Role (for Bedrock access)

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

## Step 8: Test the Deployment

```bash
# Get ALB DNS name
aws elbv2 describe-load-balancers \
  --names talentmatch-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text

# Test endpoint
curl http://<alb-dns-name>/api/status
```

## Configuration Notes

### Task Resources
- **CPU**: 1024 (1 vCPU) - Can increase to 2048 or 4096
- **Memory**: 2048 MB (2 GB) - Can increase to 4096 or 8192
- **Network Mode**: awsvpc (required for Fargate)

### Service Configuration
- **Desired Count**: 2 (for high availability)
- **Min Capacity**: 1 (auto-scaling)
- **Max Capacity**: 10 (auto-scaling)
- **Health Check Grace Period**: 60 seconds

### Load Balancer
- **Type**: Application Load Balancer
- **Health Check Path**: `/api/status`
- **Health Check Interval**: 30 seconds
- **Healthy Threshold**: 2
- **Unhealthy Threshold**: 3

## Updating the Service

```bash
# Build and push new image
docker build -t talentmatch-ai .
docker tag talentmatch-ai:latest <account-id>.dkr.ecr.<region>.amazonaws.com/talentmatch-ai:latest
docker push <account-id>.dkr.ecr.<region>.amazonaws.com/talentmatch-ai:latest

# Update task definition (increment revision)
aws ecs register-task-definition --cli-input-json file://task-definition.json

# Update service
aws ecs update-service \
  --cluster talentmatch-cluster \
  --service talentmatch-service \
  --task-definition talentmatch-ai:2 \
  --force-new-deployment
```

## Monitoring

### CloudWatch Logs
```bash
# View logs
aws logs tail /ecs/talentmatch-ai --follow
```

### CloudWatch Metrics
- `CPUUtilization` - Task CPU usage
- `MemoryUtilization` - Task memory usage
- `TargetResponseTime` - ALB response time
- `HealthyHostCount` - Healthy targets
- `UnHealthyHostCount` - Unhealthy targets

### CloudWatch Alarms
```bash
# Create CPU alarm
aws cloudwatch put-metric-alarm \
  --alarm-name talentmatch-high-cpu \
  --alarm-description "Alert when CPU exceeds 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2
```

## Troubleshooting

### Tasks fail to start
- Check CloudWatch logs
- Verify IAM roles have correct permissions
- Ensure ECR image is accessible
- Check security group rules

### Health check failures
- Verify `/api/status` endpoint works
- Check task logs for errors
- Ensure port 8080 is exposed
- Increase health check timeout

### High costs
- Reduce task count
- Use Fargate Spot for non-production
- Optimize auto-scaling policies
- Consider reserved capacity

## Cost Estimation

**ECS Fargate Pricing** (us-east-1):
- vCPU: $0.04048 per vCPU-hour
- Memory: $0.004445 per GB-hour

**Example** (2 tasks, 1 vCPU, 2 GB, 24/7):
- Compute: ~$120/month
- ALB: ~$20/month
- Data transfer: Variable

**Additional Costs**:
- ECR storage: ~$0.10/GB/month
- CloudWatch Logs: ~$0.50/GB
- Bedrock API calls: Variable

## Best Practices

1. **Use Multiple AZs**: Deploy across 2+ availability zones
2. **Enable Auto Scaling**: Scale based on CPU/memory
3. **Use ALB**: For load balancing and health checks
4. **Monitor Metrics**: Set up CloudWatch alarms
5. **Use Secrets Manager**: For sensitive data
6. **Enable Container Insights**: For detailed metrics
7. **Use Fargate Spot**: For cost savings (non-production)
8. **Implement CI/CD**: Automate deployments
