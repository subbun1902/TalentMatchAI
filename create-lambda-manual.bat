@echo off
echo Creating Lambda function manually...

REM Get Account ID
for /f "tokens=*" %%a in ('aws sts get-caller-identity --query "Account" --output text') do set ACCOUNT_ID=%%a
echo Account ID: %ACCOUNT_ID%

REM Get Role ARN
for /f "tokens=*" %%a in ('aws iam get-role --role-name talentmatch-lambda-role --query "Role.Arn" --output text') do set ROLE_ARN=%%a
echo Role ARN: %ROLE_ARN%

REM Set Image URI
set IMAGE_URI=%ACCOUNT_ID%.dkr.ecr.us-east-1.amazonaws.com/ai_resume_anaylsis:latest
echo Image URI: %IMAGE_URI%

echo.
echo Creating Lambda function...
aws lambda create-function ^
    --function-name talentmatch-ai ^
    --package-type Image ^
    --code ImageUri=%IMAGE_URI% ^
    --role %ROLE_ARN% ^
    --timeout 300 ^
    --memory-size 2048 ^
    --ephemeral-storage Size=512 ^
    --environment Variables="{AWS_REGION=us-east-1,BEDROCK_MODEL_ID=anthropic.claude-3-sonnet-20240229-v1:0,PYTHONUNBUFFERED=1,AWS_LWA_INVOKE_MODE=response_stream,AWS_LWA_PORT=8080}"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo SUCCESS! Lambda function created.
    echo.
    echo Checking function status...
    aws lambda get-function-configuration --function-name talentmatch-ai --query "{State:State,Timeout:Timeout,Memory:MemorySize}" --output table
) else (
    echo.
    echo ERROR: Failed to create Lambda function
)

pause
