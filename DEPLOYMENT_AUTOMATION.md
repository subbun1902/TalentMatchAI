# Lambda Deployment Automation

This document describes the automated deployment scripts for the TalentMatch AI Lambda function.

## Overview

The deployment automation provides a complete pipeline for building, deploying, validating, and monitoring Lambda container deployments with automatic rollback capabilities.

## Scripts Overview

### Core Deployment Scripts

| Script | Purpose | Platform | Key Features |
|--------|---------|----------|--------------|
| `build-lambda.bat` | Build and push Docker image | Windows | ECR authentication, image validation |
| `deploy-lambda.bat` | Deploy with rollback | Windows | Health checks, automatic rollback |
| `deploy-lambda.ps1` | Deploy with rollback | PowerShell | Enhanced error handling, dry-run mode |
| `full-lambda-deploy.bat` | Complete pipeline | Windows | End-to-end automation |

### Validation and Monitoring

| Script | Purpose | Platform | Key Features |
|--------|---------|----------|--------------|
| `validate-lambda-deployment.bat` | Post-deployment testing | Windows | Endpoint testing, configuration validation |
| `monitor-lambda-deployment.ps1` | Continuous monitoring | PowerShell | CloudWatch metrics, health checks |

## Quick Start

### Basic Deployment
```bash
# Complete deployment pipeline
full-lambda-deploy.bat

# Or step by step
build-lambda.bat
deploy-lambda.bat
validate-lambda-deployment.bat
```

### Advanced Options
```bash
# Deploy without rebuilding image
full-lambda-deploy.bat --skip-build

# Deploy with monitoring
full-lambda-deploy.bat --enable-monitoring

# PowerShell deployment with dry-run
powershell -File deploy-lambda.ps1 -DryRun
```

## Detailed Script Documentation

### build-lambda.bat

Builds a Lambda-compatible Docker image and pushes it to ECR.

**Prerequisites:**
- Docker Desktop running
- AWS CLI configured
- ECR repository exists

**Process:**
1. Validates prerequisites (Docker, AWS CLI, Dockerfile.lambda)
2. Builds image with `--platform linux/amd64` for Lambda compatibility
3. Authenticates with ECR
4. Tags and pushes image to ECR
5. Validates successful push

**Error Handling:**
- Comprehensive error messages with troubleshooting steps
- Validation at each step
- Clear success/failure indicators

### deploy-lambda.bat

Deploys the Lambda function with automatic rollback capabilities.

**Features:**
- **Rollback Support**: Automatically saves current image URI before deployment
- **Health Checks**: Tests `/api/status` endpoint after deployment
- **Deployment Validation**: Verifies function state and configuration
- **Comprehensive Logging**: Detailed logs with timestamps

**Process:**
1. Validates prerequisites
2. Saves current Lambda configuration for rollback
3. Calls `build-lambda.bat` for image build/push
4. Updates Lambda function with new image
5. Waits for function to reach Active state
6. Performs health check validation
7. Validates final deployment state

**Rollback Triggers:**
- Lambda function update failure
- Health check failure
- Function not reaching Active state within timeout

### deploy-lambda.ps1

PowerShell version with enhanced features.

**Additional Features:**
- **Dry Run Mode**: Test deployment without making changes
- **Skip Build Option**: Deploy existing image without rebuilding
- **Enhanced Error Handling**: Structured error management
- **Better Logging**: Colored console output and structured logs

**Usage:**
```powershell
# Basic deployment
.\deploy-lambda.ps1

# Dry run to test process
.\deploy-lambda.ps1 -DryRun

# Deploy existing image without rebuilding
.\deploy-lambda.ps1 -SkipBuild

# Custom function name
.\deploy-lambda.ps1 -FunctionName "my-function"
```

### validate-lambda-deployment.bat

Comprehensive post-deployment validation.

**Tests Performed:**
1. **Function Existence**: Verifies Lambda function exists and is accessible
2. **Configuration Check**: Reviews function settings (timeout, memory, etc.)
3. **Status Endpoint Test**: Tests `/api/status` endpoint functionality
4. **Basic Invocation**: Tests Lambda invocation with empty payload
5. **Error Handling**: Tests error response handling
6. **CloudWatch Integration**: Checks log group accessibility

**Output:**
- Console summary with pass/fail indicators
- Detailed log file with all test results
- Configuration details for troubleshooting

### monitor-lambda-deployment.ps1

Continuous monitoring with CloudWatch integration.

**Monitoring Capabilities:**
- **Function State**: Tracks Lambda function state changes
- **Health Checks**: Regular endpoint testing
- **CloudWatch Metrics**: Invocation count, errors, duration
- **Real-time Alerts**: Immediate notification of issues

**Usage:**
```powershell
# Monitor for 10 minutes (default)
.\monitor-lambda-deployment.ps1

# Continuous monitoring
.\monitor-lambda-deployment.ps1 -ContinuousMode

# Custom duration and interval
.\monitor-lambda-deployment.ps1 -MonitorDurationMinutes 30 -CheckIntervalSeconds 60

# Enable error alerts
.\monitor-lambda-deployment.ps1 -AlertOnErrors
```

### full-lambda-deploy.bat

Complete deployment pipeline orchestration.

**Pipeline Phases:**
1. **Pre-deployment Validation**: Checks required files exist
2. **Build and Deployment**: Executes build and deploy process
3. **Post-deployment Validation**: Runs comprehensive tests
4. **Monitoring Setup**: Optional monitoring session

**Command Line Options:**
- `--skip-build`: Deploy existing image without rebuilding
- `--skip-validation`: Skip post-deployment tests
- `--enable-monitoring`: Include 5-minute monitoring session
- `--help`: Show usage information

## Configuration

### Environment Variables

The scripts use these key variables (configurable at the top of each script):

```batch
set IMAGE_NAME=talentmatch-lambda
set ECR_REGISTRY=225989360749.dkr.ecr.us-east-1.amazonaws.com
set LAMBDA_FUNCTION_NAME=talentmatch-ai
```

### AWS Configuration

Ensure AWS CLI is configured with appropriate permissions:

```bash
aws configure
```

**Required Permissions:**
- `ecr:GetAuthorizationToken`
- `ecr:BatchCheckLayerAvailability`
- `ecr:GetDownloadUrlForLayer`
- `ecr:BatchGetImage`
- `ecr:PutImage`
- `lambda:UpdateFunctionCode`
- `lambda:GetFunction`
- `lambda:GetFunctionConfiguration`
- `lambda:InvokeFunction`
- `logs:DescribeLogGroups`
- `logs:DescribeLogStreams`
- `cloudwatch:GetMetricStatistics`

## Troubleshooting

### Common Issues

**Docker Build Failures:**
- Ensure Docker Desktop is running
- Check internet connection for base image download
- Verify Dockerfile.lambda exists and is valid

**ECR Push Failures:**
- Verify AWS credentials and permissions
- Check ECR repository exists
- Ensure proper region configuration

**Lambda Update Failures:**
- Verify Lambda function exists
- Check IAM permissions for Lambda operations
- Ensure image URI format is correct

**Health Check Failures:**
- Verify Lambda function is in Active state
- Check function logs in CloudWatch
- Test function manually with AWS CLI

### Log Files

All scripts generate detailed log files in the `logs/` directory:

- `deployment_YYYYMMDD_HHMMSS.log` - Deployment logs
- `validation_YYYYMMDD_HHMMSS.log` - Validation test results
- `monitor_YYYYMMDD_HHMMSS.log` - Monitoring session logs
- `full_deployment_YYYYMMDD_HHMMSS.log` - Complete pipeline logs

### Manual Recovery

If automatic rollback fails:

1. Check current function configuration:
   ```bash
   aws lambda get-function --function-name talentmatch-ai
   ```

2. List available images in ECR:
   ```bash
   aws ecr describe-images --repository-name talentmatch-lambda
   ```

3. Manually rollback to previous image:
   ```bash
   aws lambda update-function-code --function-name talentmatch-ai --image-uri [PREVIOUS_IMAGE_URI]
   ```

## Best Practices

### Development Workflow

1. **Test Locally**: Use Docker Compose for local testing
2. **Build and Test**: Use `build-lambda.bat` to build and validate image
3. **Deploy to Staging**: Use `deploy-lambda.ps1 -DryRun` first
4. **Full Deployment**: Use `full-lambda-deploy.bat --enable-monitoring`
5. **Monitor**: Check CloudWatch logs and metrics

### Production Deployment

1. **Backup Current State**: Scripts automatically handle this
2. **Use Full Pipeline**: `full-lambda-deploy.bat --enable-monitoring`
3. **Monitor Closely**: Watch logs and metrics for first 10-15 minutes
4. **Have Rollback Plan**: Scripts provide automatic rollback, but know manual steps

### Security Considerations

- **Credentials**: Use IAM roles when possible, avoid hardcoded credentials
- **Permissions**: Follow principle of least privilege
- **Logging**: Logs may contain sensitive information, secure appropriately
- **Network**: Ensure ECR and Lambda are in appropriate VPC/security groups

## Integration with CI/CD

These scripts can be integrated into CI/CD pipelines:

### GitHub Actions Example
```yaml
- name: Deploy to Lambda
  run: |
    full-lambda-deploy.bat --skip-validation
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

### Jenkins Example
```groovy
stage('Deploy Lambda') {
    steps {
        bat 'full-lambda-deploy.bat --enable-monitoring'
    }
}
```

## Support

For issues with deployment automation:

1. Check log files in `logs/` directory
2. Verify AWS credentials and permissions
3. Test individual components (Docker, AWS CLI, Lambda function)
4. Review CloudWatch logs for Lambda function errors
5. Use validation script to diagnose specific issues