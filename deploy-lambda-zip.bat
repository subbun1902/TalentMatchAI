@echo off
echo ========================================
echo Lambda ZIP Deployment Script
echo ========================================
echo.

set FUNCTION_NAME=talentmatch-ai
set REGION=us-east-1
set ROLE_NAME=talentmatch-lambda-role
set PACKAGE_FILE=lambda-deployment.zip

echo Step 1: Cleaning up old deployment package...
if exist %PACKAGE_FILE% del %PACKAGE_FILE%
if exist package rmdir /s /q package

echo.
echo Step 2: Installing dependencies to package directory...
pip install -r requirements.txt -t package --upgrade

echo.
echo Step 3: Copying application files...
xcopy /E /I /Y templates package\templates
xcopy /E /I /Y services package\services
copy app_simple.py package\
copy .env package\ 2>nul

echo.
echo Step 4: Creating ZIP package...
cd package
powershell -command "Compress-Archive -Path * -DestinationPath ..\%PACKAGE_FILE% -Force"
cd ..

echo.
echo Step 5: Getting IAM role ARN...
for /f "tokens=*" %%a in ('aws iam get-role --role-name %ROLE_NAME% --query "Role.Arn" --output text') do set ROLE_ARN=%%a
echo Role ARN: %ROLE_ARN%

echo.
echo Step 6: Checking if Lambda function exists...
aws lambda get-function --function-name %FUNCTION_NAME% >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Function exists - updating code...
    aws lambda update-function-code --function-name %FUNCTION_NAME% --zip-file fileb://%PACKAGE_FILE%
    
    echo Waiting for update to complete...
    timeout /t 5 /nobreak >nul
    
    echo Updating configuration...
    aws lambda update-function-configuration --function-name %FUNCTION_NAME% --runtime python3.11 --handler app_simple.handler --timeout 300 --memory-size 2048 --environment Variables="{AWS_REGION=%REGION%,BEDROCK_MODEL_ID=anthropic.claude-3-sonnet-20240229-v1:0,PYTHONUNBUFFERED=1}"
) else (
    echo Function does not exist - creating...
    aws lambda create-function --function-name %FUNCTION_NAME% --runtime python3.11 --role %ROLE_ARN% --handler app_simple.handler --zip-file fileb://%PACKAGE_FILE% --timeout 300 --memory-size 2048 --ephemeral-storage Size=512 --environment Variables="{AWS_REGION=%REGION%,BEDROCK_MODEL_ID=anthropic.claude-3-sonnet-20240229-v1:0,PYTHONUNBUFFERED=1}"
)

if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Deployment failed!
    pause
    exit /b 1
)

echo.
echo Step 7: Verifying deployment...
aws lambda get-function-configuration --function-name %FUNCTION_NAME% --query "{State:State,Runtime:Runtime,Handler:Handler,Timeout:Timeout,Memory:MemorySize}" --output table

echo.
echo ========================================
echo SUCCESS! Lambda function deployed
echo ========================================
echo Function: %FUNCTION_NAME%
echo Package: %PACKAGE_FILE%
echo.
echo Next steps:
echo 1. Test the function in AWS Console
echo 2. Set up API Gateway or Function URL
echo 3. Configure CORS if needed
echo.
pause
