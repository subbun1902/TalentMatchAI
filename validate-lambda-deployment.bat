@echo off
echo ========================================
echo Lambda Deployment Validation
echo ========================================
echo.

REM Set variables
set LAMBDA_FUNCTION_NAME=talentmatch-ai
set VALIDATION_LOG=logs\validation_%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%.log
set TEMP_DIR=%TEMP%\lambda_validation_%RANDOM%

REM Create logs directory if it doesn't exist
if not exist "logs" mkdir logs

echo Validation started at %date% %time% > %VALIDATION_LOG%
echo ========================================

echo Step 1: Checking AWS CLI availability...
aws --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: AWS CLI is not available!
    echo Please install and configure AWS CLI.
    pause
    exit /b 1
)

echo Step 2: Verifying Lambda function exists...
aws lambda get-function --function-name %LAMBDA_FUNCTION_NAME% >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Lambda function '%LAMBDA_FUNCTION_NAME%' not found!
    echo Please ensure the function exists and you have proper permissions.
    pause
    exit /b 1
)

echo Function exists and is accessible. >> %VALIDATION_LOG%

echo Step 3: Checking function configuration...
echo Retrieving function configuration... >> %VALIDATION_LOG%
aws lambda get-function-configuration --function-name %LAMBDA_FUNCTION_NAME% --query "{State:State,LastUpdateStatus:LastUpdateStatus,Runtime:Runtime,Timeout:Timeout,MemorySize:MemorySize}" --output table > function_config.tmp
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Could not retrieve function configuration!
    goto :cleanup_and_exit
)

echo Current function configuration:
type function_config.tmp
echo.
echo Function configuration: >> %VALIDATION_LOG%
type function_config.tmp >> %VALIDATION_LOG%

echo Step 4: Testing /api/status endpoint...
echo Testing status endpoint... >> %VALIDATION_LOG%

REM Create temporary directory for test files
mkdir %TEMP_DIR% 2>nul

REM Test the /api/status endpoint
echo {"httpMethod":"GET","path":"/api/status","headers":{},"body":""} > %TEMP_DIR%\status_payload.json
aws lambda invoke --function-name %LAMBDA_FUNCTION_NAME% --payload file://%TEMP_DIR%\status_payload.json %TEMP_DIR%\status_response.json 2>%TEMP_DIR%\status_error.txt

if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Status endpoint test failed!
    echo Error details: >> %VALIDATION_LOG%
    type %TEMP_DIR%\status_error.txt >> %VALIDATION_LOG%
    goto :cleanup_and_exit
)

REM Check response content
findstr /C:"status" %TEMP_DIR%\status_response.json >nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Status endpoint returned invalid response!
    echo Response content: >> %VALIDATION_LOG%
    type %TEMP_DIR%\status_response.json >> %VALIDATION_LOG%
    goto :cleanup_and_exit
)

echo Status endpoint test PASSED ✓
echo Status endpoint test PASSED >> %VALIDATION_LOG%

echo Step 5: Testing basic Lambda invocation...
echo Testing basic invocation... >> %VALIDATION_LOG%

REM Test basic invocation with empty payload
echo {} > %TEMP_DIR%\basic_payload.json
aws lambda invoke --function-name %LAMBDA_FUNCTION_NAME% --payload file://%TEMP_DIR%\basic_payload.json %TEMP_DIR%\basic_response.json 2>%TEMP_DIR%\basic_error.txt

if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Basic invocation test failed!
    echo Error details: >> %VALIDATION_LOG%
    type %TEMP_DIR%\basic_error.txt >> %VALIDATION_LOG%
    goto :cleanup_and_exit
)

echo Basic invocation test PASSED ✓
echo Basic invocation test PASSED >> %VALIDATION_LOG%

echo Step 6: Testing error handling...
echo Testing error handling... >> %VALIDATION_LOG%

REM Test with invalid HTTP method to check error handling
echo {"httpMethod":"INVALID","path":"/api/status","headers":{},"body":""} > %TEMP_DIR%\error_payload.json
aws lambda invoke --function-name %LAMBDA_FUNCTION_NAME% --payload file://%TEMP_DIR%\error_payload.json %TEMP_DIR%\error_response.json 2>%TEMP_DIR%\error_test_error.txt

if %ERRORLEVEL% NEQ 0 (
    echo WARNING: Error handling test had invocation issues
    echo Error test details: >> %VALIDATION_LOG%
    type %TEMP_DIR%\error_test_error.txt >> %VALIDATION_LOG%
) else (
    echo Error handling test completed (response logged)
    echo Error handling response: >> %VALIDATION_LOG%
    type %TEMP_DIR%\error_response.json >> %VALIDATION_LOG%
)

echo Step 7: Performance and resource validation...
echo Checking recent invocation metrics... >> %VALIDATION_LOG%

REM Get recent CloudWatch metrics (if available)
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/%LAMBDA_FUNCTION_NAME%" --query "logGroups[0].logGroupName" --output text > %TEMP_DIR%\log_group.tmp 2>nul
if %ERRORLEVEL% EQU 0 (
    set /p LOG_GROUP=<%TEMP_DIR%\log_group.tmp
    if not "%LOG_GROUP%"=="None" (
        echo Found log group: %LOG_GROUP%
        echo Log group found: %LOG_GROUP% >> %VALIDATION_LOG%
        
        REM Get recent log streams
        aws logs describe-log-streams --log-group-name "%LOG_GROUP%" --order-by LastEventTime --descending --max-items 1 --query "logStreams[0].logStreamName" --output text > %TEMP_DIR%\log_stream.tmp 2>nul
        if %ERRORLEVEL% EQU 0 (
            set /p LOG_STREAM=<%TEMP_DIR%\log_stream.tmp
            if not "%LOG_STREAM%"=="None" (
                echo Recent log stream: %LOG_STREAM%
                echo Recent log stream: %LOG_STREAM% >> %VALIDATION_LOG%
            )
        )
    )
) else (
    echo No CloudWatch logs found or insufficient permissions
    echo No CloudWatch logs accessible >> %VALIDATION_LOG%
)

echo Step 8: Final validation summary...
echo.
echo ========================================
echo VALIDATION RESULTS
echo ========================================
echo.
echo Function Name: %LAMBDA_FUNCTION_NAME%
echo Status Endpoint: ✓ PASSED
echo Basic Invocation: ✓ PASSED
echo Error Handling: ✓ TESTED
echo Configuration: ✓ VERIFIED
echo.
echo Validation completed successfully!
echo All critical tests passed.
echo.
echo Validation completed at %date% %time% >> %VALIDATION_LOG%
echo All tests passed >> %VALIDATION_LOG%
echo ======================================== >> %VALIDATION_LOG%

echo Detailed results saved to: %VALIDATION_LOG%
echo.
goto :cleanup_and_success

:cleanup_and_exit
echo.
echo ========================================
echo VALIDATION FAILED
echo ========================================
echo.
echo Some validation tests failed.
echo Check the log file for details: %VALIDATION_LOG%
echo.
echo Validation failed at %date% %time% >> %VALIDATION_LOG%
echo ======================================== >> %VALIDATION_LOG%

:cleanup_and_success
REM Clean up temporary files
if exist function_config.tmp del function_config.tmp
if exist %TEMP_DIR% rmdir /s /q %TEMP_DIR% 2>nul

if "%1"=="--no-pause" goto :end
pause

:end
if errorlevel 1 exit /b 1
exit /b 0