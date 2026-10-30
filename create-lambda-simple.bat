@echo off
setlocal enabledelayedexpansion

echo Getting AWS Account ID...
for /f "tokens=*" %%a in ('aws sts get-caller-identity --query "Account" --output text') do set ACCOUNT_ID=%%a
echo Account ID: %ACCOUNT_ID%

echo.
echo Getting IAM Role ARN...
for /f "tokens=*" %%a in ('aws iam get-role --role-name talentmatch-lambda-role --query "Role.Arn" --output text') do set ROLE_ARN=%%a
echo Role ARN: %ROLE_ARN%

echo.
echo Creating Lambda function...
echo Image URI: %ACCOUNT_ID%.dkr.ecr.us-east-1.amazonaws.com/ai_resume_anaylsis:latest

aws lambda create-function --function-name talentmatch-ai --package-type Image --code ImageUri=%ACCOUNT_ID%.dkr.ecr.us-east-1.amazonaws.com/ai_resume_anaylsis:latest --role %ROLE_ARN% --timeout 300 --memory-size 2048 --ephemeral-storage Size=512 --environment Variables="{AWS_REGION=us-east-1,BEDROCK_MODEL_ID=anthropic.claude-3-sonnet-20240229-v1:0,PYTHONUNBUFFERED=1,AWS_LWA_INVOKE_MODE=response_stream,AWS_LWA_PORT=8080}" 2>&1

echo.
echo Checking if function was created...
aws lambda get-function --function-name talentmatch-ai 2>&1

pause
