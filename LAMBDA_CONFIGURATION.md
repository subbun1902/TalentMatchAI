# Lambda Function Configuration Guide

This document provides comprehensive guidance for configuring AWS Lambda function settings and IAM permissions for the TalentMatch AI application.

## Overview

The Lambda configuration includes:
- Function settings (timeout, memory, ephemeral storage)
- IAM role with required permissions for Bedrock and CloudWatch
- Environment variables for AWS services and Lambda Web Adapter
- CloudWatch log group setup
- Connectivity testing

## Quick Start

### 1. Create IAM Role and Update Function (Recommended)
```bash
# PowerShell (Recommended)
.\configure-lambda-function.ps1 -CreateRole -UpdateFunction -TestConnectivity

# Batch Script
configure-lambda-function.bat --create-role --update-function --test-connectivity
```

### 2. Validate Configuration
```bash
validate-lambda-config.bat
```

### 3. Test Bedrock Connectivity
```bash
python test-lambda-bedrock.py
```

## Configuration Details

### Lambda Function Settings

| Setting | Value | Purpose |
|---------|-------|---------|
| Timeout | 300 seconds (5 minutes) | Allow time for Bedrock analysis |
| Memory | 2048 MB (2 GB) | Handle PDF processing and AI analysis |
| Ephemeral Storage | 512 MB | Temporary file storage |
| Architecture | x86_64 | Standard Lambda architecture |
| Package Type | Image | Container deployment |

### Environment Variables

| Variable | Value | Description |
|----------|-------|-------------|
| `AWS_REGION` | us-east-1 | AWS region for services |
| `BEDROCK_MODEL_ID` | anthropic.claude-3-sonnet-20240229-v1:0 | Bedrock model identifier |
| `PYTHONUNBUFFERED` | 1 | Immediate stdout/stderr output |
| `AWS_LWA_INVOKE_MODE` | response_stream | Lambda Web Adapter mode |
| `AWS_LWA_PORT` | 8080 | Lambda Web Adapter port |

### IAM Role Permissions

The Lambda execution role requires the following permissions:

#### Basic Lambda Execution
- AWS Managed Policy: `AWSLambdaBasicExecutionRole`

#### Bedrock Access
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "bedrock:InvokeModel",
                "bedrock:InvokeModelWithResponseStream",
                "bedrock:ListFoundationModels"
            ],
            "Resource": "*"
        }
    ]
}
```

#### CloudWatch Logs
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams"
            ],
            "Resource": "arn:aws:logs:us-east-1:*:*"
        }
    ]
}
```

## Configuration Scripts

### configure-lambda-function.ps1 (PowerShell)

**Features:**
- Cross-platform PowerShell support
- Comprehensive error handling
- Dry-run mode for testing
- Detailed logging and validation

**Usage:**
```powershell
# Create role and update function
.\configure-lambda-function.ps1 -CreateRole -UpdateFunction

# Test connectivity only
.\configure-lambda-function.ps1 -TestConnectivity

# Dry run to see what would be done
.\configure-lambda-function.ps1 -CreateRole -UpdateFunction -DryRun

# Custom parameters
.\configure-lambda-function.ps1 -FunctionName "my-function" -Region "us-west-2" -CreateRole -UpdateFunction
```

### configure-lambda-function.bat (Windows Batch)

**Features:**
- Windows-native batch script
- Simple command-line interface
- Automatic policy creation
- Built-in validation

**Usage:**
```batch
REM Create role and update function
configure-lambda-function.bat --create-role --update-function

REM Test connectivity
configure-lambda-function.bat --test-connectivity

REM Custom function name
configure-lambda-function.bat --function-name my-function --create-role
```

### validate-lambda-config.bat

Quick validation script that checks:
- Function existence and basic configuration
- Environment variables
- IAM role and policies
- Basic connectivity
- Bedrock service access
- CloudWatch log group

### test-lambda-bedrock.py

Comprehensive Python test script that validates:
- AWS credentials and permissions
- Bedrock service access and model availability
- Bedrock runtime with actual model invocation
- CloudWatch Logs access
- Environment variables
- Complete end-to-end connectivity

## Troubleshooting

### Common Issues

#### 1. Access Denied to Bedrock
**Error:** `AccessDeniedException` when calling Bedrock
**Solution:** 
- Ensure IAM role has `bedrock:InvokeModel` permission
- Check if Bedrock is available in your region
- Verify model ID is correct

#### 2. Lambda Function Not Found
**Error:** Function does not exist
**Solution:**
- Deploy the function first using `deploy-lambda.bat`
- Verify function name matches configuration

#### 3. Timeout Issues
**Error:** Lambda function times out
**Solution:**
- Increase timeout to 300 seconds (5 minutes)
- Check memory allocation (should be 2048 MB)
- Monitor CloudWatch logs for performance issues

#### 4. Environment Variables Not Set
**Error:** Missing required environment variables
**Solution:**
- Run configuration script with `--update-function` flag
- Manually set variables in Lambda console if needed

#### 5. IAM Role Issues
**Error:** Role does not exist or lacks permissions
**Solution:**
- Run configuration script with `--create-role` flag
- Verify role has correct trust policy for Lambda
- Check attached policies include Bedrock and CloudWatch permissions

### Validation Commands

```bash
# Check function configuration
aws lambda get-function-configuration --function-name talentmatch-ai

# Test function invocation
aws lambda invoke --function-name talentmatch-ai --payload '{"httpMethod":"GET","path":"/api/status"}' response.json

# Check CloudWatch logs
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/talentmatch-ai

# List Bedrock models
aws bedrock list-foundation-models --region us-east-1

# Check IAM role
aws iam get-role --role-name talentmatch-lambda-role
aws iam list-attached-role-policies --role-name talentmatch-lambda-role
```

## Integration with Deployment

The configuration is automatically integrated into the deployment process:

1. **deploy-lambda.bat** - Includes configuration step after function update
2. **full-lambda-deploy.bat** - Comprehensive pipeline including configuration
3. **validate-lambda-deployment.bat** - Post-deployment validation

## Monitoring and Maintenance

### CloudWatch Metrics to Monitor
- Duration
- Memory utilization
- Error rate
- Throttles
- Cold starts

### Log Analysis
- Check `/aws/lambda/talentmatch-ai` log group
- Monitor for Bedrock API errors
- Watch for timeout warnings
- Review memory usage patterns

### Regular Maintenance
- Review and rotate IAM credentials
- Update Bedrock model versions as needed
- Monitor AWS service limits
- Update timeout/memory based on usage patterns

## Security Considerations

1. **Least Privilege:** IAM role has minimal required permissions
2. **Resource Restrictions:** Bedrock access limited to required models
3. **Logging:** All API calls logged to CloudWatch
4. **Encryption:** All data encrypted in transit and at rest
5. **Access Control:** Function accessible only through API Gateway or direct invocation

## Cost Optimization

1. **Right-sizing:** Memory allocated based on actual usage (2048 MB)
2. **Timeout:** Set to minimum required time (300s)
3. **Log Retention:** Set to 14 days to control storage costs
4. **Monitoring:** Track usage patterns for optimization opportunities

## Support and Troubleshooting

For issues with Lambda configuration:

1. Run validation scripts first
2. Check CloudWatch logs for detailed error messages
3. Verify IAM permissions using AWS CLI
4. Test Bedrock connectivity independently
5. Review AWS service limits and quotas

## Version History

- **v1.0** - Initial Lambda configuration support
- **v1.1** - Added comprehensive testing and validation
- **v1.2** - Integrated with deployment pipeline
- **v1.3** - Enhanced error handling and troubleshooting