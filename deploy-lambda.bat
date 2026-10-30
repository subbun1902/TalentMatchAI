@echo off
echo ========================================
echo Lambda Deployment Automation
echo ========================================
echo.

REM Set variables for Lambda deployment
set IMAGE_NAME=talentmatch-lambda
set ECR_REGISTRY=225989360749.dkr.ecr.us-east-1.amazonaws.com
set ECR_REPO=%ECR_REGISTRY%/%IMAGE_NAME%
set LAMBDA_FUNCTION_NAME=talentmatch-ai
set DEPLOYMENT_LOG=deployment_%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%.log
set HEALTH_CHECK_TIMEOUT=60
set ROLLBACK_ENABLED=true

REM Create logs directory if it doesn't exist
if not exist "logs" mkdir logs
set DEPLOYMENT_LOG=logs\%DEPLOYMENT_LOG%

echo Deployment started at %date% %time% > %DEPLOYMENT_LOG%
echo ========================================

echo Step 1: Validating prerequisites...
echo Checking Docker availability...
docker --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Docker is not available or not running! | tee -a %DEPLOYMENT_LOG%
    echo Please ensure Docker Desktop is installed and running.
    pause
    exit /b 1
)

echo Checking AWS CLI availability...
aws --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: AWS CLI is not available! | tee -a %DEPLOYMENT_LOG%
    echo Please install and configure AWS CLI.
    pause
    exit /b 1
)

echo Prerequisites validated successfully. >> %DEPLOYMENT_LOG%
echo.

echo Step 2: Getting current Lambda function configuration for rollback...
echo Retrieving current function configuration... >> %DEPLOYMENT_LOG%
aws lambda get-function --function-name %LAMBDA_FUNCTION_NAME% --query "Code.ImageUri" --output text > current_image_uri.tmp 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo WARNING: Could not retrieve current Lambda function configuration.
    echo WARNING: Rollback functionality will be limited. >> %DEPLOYMENT_LOG%
    set ROLLBACK_ENABLED=false
) else (
    set /p CURRENT_IMAGE_URI=<current_image_uri.tmp
    echo Current image URI: %CURRENT_IMAGE_URI% >> %DEPLOYMENT_LOG%
    echo Rollback capability enabled.
)
del current_image_uri.tmp 2>nul

echo.
echo Step 3: Building and pushing Docker image...
echo Calling build-lambda.bat for image build and ECR push...
call build-lambda.bat
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Image build and push failed! | tee -a %DEPLOYMENT_LOG%
    echo Deployment aborted.
    pause
    exit /b 1
)

echo Image build and push completed successfully. >> %DEPLOYMENT_LOG%
echo.

echo Step 4: Updating Lambda function...
echo Updating Lambda function with new image... >> %DEPLOYMENT_LOG%
aws lambda update-function-code --function-name %LAMBDA_FUNCTION_NAME% --image-uri %ECR_REPO%:latest > lambda_update_result.tmp 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Lambda function update failed! | tee -a %DEPLOYMENT_LOG%
    type lambda_update_result.tmp >> %DEPLOYMENT_LOG%
    echo.
    echo Attempting rollback...
    goto :rollback
)

echo Lambda function updated successfully. >> %DEPLOYMENT_LOG%
del lambda_update_result.tmp 2>nul

echo.
echo Step 4.1: Configuring Lambda function settings...
echo Configuring Lambda function settings and permissions... >> %DEPLOYMENT_LOG%
call configure-lambda-function.bat --update-function >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo WARNING: Lambda function configuration may have issues
    echo WARNING: Lambda function configuration issues >> %DEPLOYMENT_LOG%
) else (
    echo Lambda function configuration updated successfully
    echo Lambda function configuration updated >> %DEPLOYMENT_LOG%
)

echo.
echo Step 5: Waiting for function to be ready...
echo Waiting for Lambda function to reach Active state...
:wait_active
aws lambda get-function --function-name %LAMBDA_FUNCTION_NAME% --query "Configuration.State" --output text > function_state.tmp 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Could not check function state! | tee -a %DEPLOYMENT_LOG%
    goto :rollback
)

set /p FUNCTION_STATE=<function_state.tmp
if "%FUNCTION_STATE%"=="Active" (
    echo Function is now Active. >> %DEPLOYMENT_LOG%
    del function_state.tmp
    goto :health_check
)

echo Function state: %FUNCTION_STATE%, waiting...
timeout /t 5 /nobreak >nul
goto :wait_active

:health_check
echo.
echo Step 6: Performing health check validation...
echo Starting health check validation... >> %DEPLOYMENT_LOG%

REM Test the /api/status endpoint
echo Testing /api/status endpoint...
aws lambda invoke --function-name %LAMBDA_FUNCTION_NAME% --payload "{\"httpMethod\":\"GET\",\"path\":\"/api/status\",\"headers\":{},\"body\":\"\"}" health_check_response.json 2>health_check_error.tmp
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Health check invocation failed! | tee -a %DEPLOYMENT_LOG%
    type health_check_error.tmp >> %DEPLOYMENT_LOG%
    goto :rollback
)

REM Check if response contains expected status
findstr /C:"\"status\"" health_check_response.json >nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Health check failed - invalid response format! | tee -a %DEPLOYMENT_LOG%
    echo Response content: >> %DEPLOYMENT_LOG%
    type health_check_response.json >> %DEPLOYMENT_LOG%
    goto :rollback
)

echo Health check passed successfully. >> %DEPLOYMENT_LOG%
del health_check_response.json health_check_error.tmp 2>nul

echo.
echo Step 7: Final deployment validation...
echo Performing final deployment validation... >> %DEPLOYMENT_LOG%

REM Verify function configuration
aws lambda get-function-configuration --function-name %LAMBDA_FUNCTION_NAME% --query "{State:State,LastUpdateStatus:LastUpdateStatus,ImageUri:Code.ImageUri}" --output table > final_validation.tmp 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo WARNING: Could not retrieve final function configuration.
    echo WARNING: Manual verification recommended. >> %DEPLOYMENT_LOG%
) else (
    echo Final function configuration: >> %DEPLOYMENT_LOG%
    type final_validation.tmp >> %DEPLOYMENT_LOG%
    type final_validation.tmp
)
del final_validation.tmp 2>nul

echo.
echo ========================================
echo SUCCESS! Deployment completed
echo ========================================
echo.
echo Deployment Summary:
echo - Function: %LAMBDA_FUNCTION_NAME%
echo - New Image: %ECR_REPO%:latest
echo - Status: Successfully deployed and validated
echo - Log File: %DEPLOYMENT_LOG%
echo.
echo Deployment completed successfully at %date% %time% >> %DEPLOYMENT_LOG%
echo ======================================== >> %DEPLOYMENT_LOG%

echo Next Steps:
echo 1. Test your application endpoints
echo 2. Monitor CloudWatch logs for any issues
echo 3. Review deployment log: %DEPLOYMENT_LOG%
echo.
pause
exit /b 0

:rollback
echo.
echo ========================================
echo DEPLOYMENT FAILED - INITIATING ROLLBACK
echo ========================================
echo.
echo Rollback initiated at %date% %time% >> %DEPLOYMENT_LOG%

if "%ROLLBACK_ENABLED%"=="false" (
    echo ERROR: Rollback not available - no previous image URI found.
    echo ERROR: Manual intervention required. >> %DEPLOYMENT_LOG%
    echo.
    echo Manual rollback steps:
    echo 1. Check Lambda function configuration: aws lambda get-function --function-name %LAMBDA_FUNCTION_NAME%
    echo 2. Identify last known good image URI
    echo 3. Update function manually: aws lambda update-function-code --function-name %LAMBDA_FUNCTION_NAME% --image-uri [GOOD_IMAGE_URI]
    echo.
    pause
    exit /b 1
)

echo Rolling back to previous image: %CURRENT_IMAGE_URI%
echo Rolling back to: %CURRENT_IMAGE_URI% >> %DEPLOYMENT_LOG%

aws lambda update-function-code --function-name %LAMBDA_FUNCTION_NAME% --image-uri %CURRENT_IMAGE_URI% > rollback_result.tmp 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Rollback failed! | tee -a %DEPLOYMENT_LOG%
    type rollback_result.tmp >> %DEPLOYMENT_LOG%
    echo.
    echo CRITICAL: Both deployment and rollback failed!
    echo Manual intervention required immediately.
    echo Check deployment log: %DEPLOYMENT_LOG%
    pause
    exit /b 1
)

echo Rollback completed successfully. >> %DEPLOYMENT_LOG%
del rollback_result.tmp 2>nul

echo.
echo Waiting for rollback to complete...
:wait_rollback_active
aws lambda get-function --function-name %LAMBDA_FUNCTION_NAME% --query "Configuration.State" --output text > rollback_state.tmp 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo WARNING: Could not verify rollback state.
    del rollback_state.tmp 2>nul
    goto :rollback_complete
)

set /p ROLLBACK_STATE=<rollback_state.tmp
if "%ROLLBACK_STATE%"=="Active" (
    del rollback_state.tmp
    goto :rollback_complete
)

echo Rollback state: %ROLLBACK_STATE%, waiting...
timeout /t 3 /nobreak >nul
goto :wait_rollback_active

:rollback_complete
echo.
echo ========================================
echo ROLLBACK COMPLETED
echo ========================================
echo.
echo Rollback Summary:
echo - Function: %LAMBDA_FUNCTION_NAME%
echo - Restored Image: %CURRENT_IMAGE_URI%
echo - Status: Rollback completed
echo - Log File: %DEPLOYMENT_LOG%
echo.
echo Rollback completed at %date% %time% >> %DEPLOYMENT_LOG%
echo ======================================== >> %DEPLOYMENT_LOG%

echo The deployment failed but rollback was successful.
echo Please review the deployment log and fix issues before retrying.
echo Log file: %DEPLOYMENT_LOG%
echo.
pause
exit /b 1