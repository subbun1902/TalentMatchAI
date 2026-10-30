# Lambda Configuration Troubleshooting

## Issue
The Lambda configuration scripts complete successfully but the function doesn't appear to exist.

## Diagnostic Steps

### 1. Check if Lambda function exists
```bash
aws lambda list-functions
```

### 2. Check if IAM role was created
```bash
aws iam get-role --role-name talentmatch-lambda-role
```

### 3. Check ECR image availability
```bash
aws ecr describe-images --repository-name ai_resume_anaylsis --region us-east-1
```

## Manual Creation Steps (if needed)

### Option 1: AWS Console
1. Go to AWS Lambda Console
2. Click "Create function"
3. Select "Container image"
4. Configuration:
   - **Function name**: `talentmatch-ai`
   - **Container image URI**: `225989360749.dkr.ecr.us-east-1.amazonaws.com/ai_resume_anaylsis:latest`
   - **Execution role**: Use existing role → `talentmatch-lambda-role`
5. Click "Create function"
6. After creation, configure:
   - **Memory**: 2048 MB
   - **Timeout**: 300 seconds (5 minutes)
   - **Ephemeral storage**: 512 MB
   - **Environment variables**:
     - `AWS_REGION`: us-east-1
     - `BEDROCK_MODEL_ID`: anthropic.claude-3-sonnet-20240229-v1:0
     - `PYTHONUNBUFFERED`: 1
     - `AWS_LWA_INVOKE_MODE`: response_stream
     - `AWS_LWA_PORT`: 8080

### Option 2: AWS CLI (Manual)
```bash
# Get your account ID
aws sts get-caller-identity --query "Account" --output text

# Get role ARN
aws iam get-role --role-name talentmatch-lambda-role --query "Role.Arn" --output text

# Create function (replace ACCOUNT_ID and ROLE_ARN)
aws lambda create-function \
    --function-name talentmatch-ai \
    --package-type Image \
    --code ImageUri=ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/ai_resume_anaylsis:latest \
    --role ROLE_ARN \
    --timeout 300 \
    --memory-size 2048 \
    --ephemeral-storage Size=512 \
    --environment Variables="{AWS_REGION=us-east-1,BEDROCK_MODEL_ID=anthropic.claude-3-sonnet-20240229-v1:0,PYTHONUNBUFFERED=1,AWS_LWA_INVOKE_MODE=response_stream,AWS_LWA_PORT=8080}"
```

## Common Issues

### Issue: ResourceNotFoundException
**Cause**: Function doesn't exist
**Solution**: Create it using one of the methods above

### Issue: InvalidParameterValueException (Role)
**Cause**: IAM role doesn't exist or doesn't have correct trust policy
**Solution**: Run `configure-lambda-function.bat --create-role`

### Issue: ImageNotFoundException
**Cause**: Docker image not in ECR or wrong URI
**Solution**: Verify image exists with `aws ecr describe-images --repository-name ai_resume_anaylsis`

### Issue: AccessDeniedException
**Cause**: AWS credentials don't have permission to create Lambda functions
**Solution**: Ensure your AWS user/role has Lambda creation permissions
