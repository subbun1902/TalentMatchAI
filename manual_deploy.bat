@echo off
echo Deploying Lambda function... > deploy_log.txt 2>&1

set FUNCTION_NAME=talentmatch-ai
set ROLE_ARN=arn:aws:iam::225989360749:role/talentmatch-lambda-role
set PACKAGE_FILE=lambda-deployment.zip

echo Checking if function exists... >> deploy_log.txt 2>&1
aws lambda get-function --function-name %FUNCTION_NAME% >> deploy_log.txt 2>&1

if %ERRORLEVEL% EQU 0 (
    echo Function exists - updating code... >> deploy_log.txt 2>&1
    aws lambda update-function-code --function-name %FUNCTION_NAME% --zip-file fileb://%PACKAGE_FILE% >> deploy_log.txt 2>&1
) else (
    echo Function does not exist - creating... >> deploy_log.txt 2>&1
    aws lambda create-function --function-name %FUNCTION_NAME% --runtime python3.11 --role %ROLE_ARN% --handler app_simple.handler --zip-file fileb://%PACKAGE_FILE% --timeout 300 --memory-size 2048 --ephemeral-storage Size=512 --environment Variables="{BEDROCK_MODEL_ID=anthropic.claude-3-sonnet-20240229-v1:0,PYTHONUNBUFFERED=1}" >> deploy_log.txt 2>&1
)

echo Done. >> deploy_log.txt 2>&1
type deploy_log.txt
