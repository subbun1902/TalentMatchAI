@echo off
REM Validate Lambda Configuration Script
REM Quick validation of Lambda function settings and permissions

setlocal enabledelayedexpansion

set FUNCTION_NAME=talentmatch-ai
set REGION=us-east-1

echo ========================================
echo Lambda Configuration Validation
echo ========================================
echo Function: %FUNCTION_NAME%
echo Region: %REGION%
echo ========================================

REM Check if function exists
echo Checking if Lambda function exists...
aws lambda get-function --function-name %FUNCTION_NAME% --region %REGION% >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Lambda function %FUNCTION_NAME% not found!
    echo Please deploy the function first.
    pause
    exit /b 1
)
echo ✓ Lambda function exists

REM Get function configuration
echo.
echo Retrieving function configuration...
aws lambda get-function-configuration --function-name %FUNCTION_NAME% --region %REGION% --output table --query "{State:State,Runtime:PackageType,Timeout:Timeout,Memory:MemorySize,Role:Role,LastModified:LastModified}" 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo WARNING: Could not retrieve function configuration
)

REM Check environment variables
echo.
echo Checking environment variables...
aws lambda get-function-configuration --function-name %FUNCTION_NAME% --region %REGION% --query "Environment.Variables" --output json > env-vars.tmp 2>nul
if %ERRORLEVEL% EQU 0 (
    findstr /C:"AWS_REGION" env-vars.tmp >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo ✓ AWS_REGION is set
    ) else (
        echo ✗ AWS_REGION not set
    )
    
    findstr /C:"BEDROCK_MODEL_ID" env-vars.tmp >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo ✓ BEDROCK_MODEL_ID is set
    ) else (
        echo ✗ BEDROCK_MODEL_ID not set
    )
    
    findstr /C:"AWS_LWA_INVOKE_MODE" env-vars.tmp >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo ✓ AWS_LWA_INVOKE_MODE is set
    ) else (
        echo ✗ AWS_LWA_INVOKE_MODE not set
    )
    
    findstr /C:"AWS_LWA_PORT" env-vars.tmp >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo ✓ AWS_LWA_PORT is set
    ) else (
        echo ✗ AWS_LWA_PORT not set
    )
) else (
    echo WARNING: Could not retrieve environment variables
)

REM Check IAM role permissions
echo.
echo Checking IAM role...
for /f "tokens=*" %%a in ('aws lambda get-function-configuration --function-name %FUNCTION_NAME% --region %REGION% --query "Role" --output text 2^>nul') do set ROLE_ARN=%%a

if not "%ROLE_ARN%"=="" (
    echo Role ARN: %ROLE_ARN%
    
    REM Extract role name from ARN
    for /f "tokens=6 delims=/" %%a in ("%ROLE_ARN%") do set ROLE_NAME=%%a
    
    if not "%ROLE_NAME%"=="" (
        echo Checking role policies...
        aws iam list-attached-role-policies --role-name %ROLE_NAME% --output table --query "AttachedPolicies[*].{PolicyName:PolicyName,PolicyArn:PolicyArn}" 2>nul
        if %ERRORLEVEL% EQU 0 (
            echo ✓ Role policies listed successfully
        ) else (
            echo WARNING: Could not list role policies
        )
    )
) else (
    echo WARNING: Could not retrieve role information
)

REM Test basic connectivity
echo.
echo Testing basic connectivity...
echo {"httpMethod":"GET","path":"/api/status","headers":{},"body":""} > test-payload.json

aws lambda invoke --function-name %FUNCTION_NAME% --region %REGION% --payload file://test-payload.json response.json >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo ✓ Lambda function invocation successful
    
    REM Check response
    findstr /C:"status" response.json >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo ✓ Status endpoint responding correctly
    ) else (
        echo ✗ Status endpoint not responding as expected
        echo Response content:
        type response.json
    )
) else (
    echo ✗ Lambda function invocation failed
)

REM Test Bedrock access
echo.
echo Testing Bedrock model access...
aws bedrock list-foundation-models --region %REGION% --output json > bedrock-models.tmp 2>&1
if %ERRORLEVEL% EQU 0 (
    findstr /C:"anthropic.claude-3-sonnet" bedrock-models.tmp >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo ✓ Bedrock Claude model is available
    ) else (
        echo ✗ Bedrock Claude model not found
        echo Available models:
        findstr /C:"modelId" bedrock-models.tmp | head -5
    )
) else (
    echo ✗ Could not access Bedrock service
    echo This may indicate IAM permission issues
)

REM Check CloudWatch log group
echo.
echo Checking CloudWatch log group...
set LOG_GROUP_NAME=/aws/lambda/%FUNCTION_NAME%
aws logs describe-log-groups --log-group-name-prefix %LOG_GROUP_NAME% --region %REGION% --output table --query "logGroups[*].{LogGroup:logGroupName,RetentionDays:retentionInDays,SizeBytes:storedBytes}" 2>nul
if %ERRORLEVEL% EQU 0 (
    echo ✓ CloudWatch log group accessible
) else (
    echo ✗ CloudWatch log group not accessible
)

echo.
echo ========================================
echo Validation completed
echo ========================================

REM Cleanup
del env-vars.tmp 2>nul
del test-payload.json 2>nul
del response.json 2>nul
del bedrock-models.tmp 2>nul

echo.
echo Next steps:
echo 1. If any checks failed, run: configure-lambda-function.bat --create-role --update-function
echo 2. For detailed connectivity testing, run: python test-lambda-bedrock.py
echo 3. Monitor function logs: aws logs tail /aws/lambda/%FUNCTION_NAME% --follow
echo.

pause
exit /b 0