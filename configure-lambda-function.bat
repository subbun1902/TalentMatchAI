@echo off
REM Lambda Function Configuration Script (Batch Version)
REM Configures Lambda function settings and IAM permissions for TalentMatch AI

setlocal enabledelayedexpansion

REM Default configuration
set FUNCTION_NAME=talentmatch-ai
set REGION=us-east-1
set ROLE_NAME=talentmatch-lambda-role
set TIMEOUT=300
set MEMORY=2048
set EPHEMERAL_STORAGE=512
set BEDROCK_MODEL_ID=anthropic.claude-3-sonnet-20240229-v1:0
set LOG_RETENTION_DAYS=14

set CREATE_ROLE=false
set UPDATE_FUNCTION=false
set TEST_CONNECTIVITY=false
set DRY_RUN=false

REM Parse command line arguments
:parse_args
if "%1"=="--create-role" (
    set CREATE_ROLE=true
    shift
    goto :parse_args
)
if "%1"=="--update-function" (
    set UPDATE_FUNCTION=true
    shift
    goto :parse_args
)
if "%1"=="--test-connectivity" (
    set TEST_CONNECTIVITY=true
    shift
    goto :parse_args
)
if "%1"=="--dry-run" (
    set DRY_RUN=true
    shift
    goto :parse_args
)
if "%1"=="--function-name" (
    set FUNCTION_NAME=%2
    shift
    shift
    goto :parse_args
)
if "%1"=="--region" (
    set REGION=%2
    shift
    shift
    goto :parse_args
)
if "%1"=="--role-name" (
    set ROLE_NAME=%2
    shift
    shift
    goto :parse_args
)
if "%1"=="--help" goto :show_help
if "%1"=="-h" goto :show_help
if not "%1"=="" (
    echo Unknown argument: %1
    goto :show_help
)

echo ========================================
echo Lambda Function Configuration Started
echo ========================================
echo Function Name: %FUNCTION_NAME%
echo IAM Role: %ROLE_NAME%
echo Region: %REGION%
echo Timeout: %TIMEOUT%s
echo Memory: %MEMORY%MB
echo Ephemeral Storage: %EPHEMERAL_STORAGE%MB
echo Bedrock Model: %BEDROCK_MODEL_ID%
echo ========================================

if "%DRY_RUN%"=="true" (
    echo DRY RUN MODE - No actual changes will be made
    echo.
)

REM Check prerequisites
echo Step 1: Checking prerequisites...
aws --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: AWS CLI is not available!
    echo Please install and configure AWS CLI.
    pause
    exit /b 1
)

aws sts get-caller-identity >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: AWS credentials not configured!
    echo Please configure AWS credentials using 'aws configure'.
    pause
    exit /b 1
)

echo Prerequisites validated successfully.
echo.

REM Create IAM role if requested
if "%CREATE_ROLE%"=="true" (
    echo Step 2: Creating IAM role...
    call :create_iam_role
    if %ERRORLEVEL% NEQ 0 (
        echo ERROR: Failed to create IAM role!
        pause
        exit /b 1
    )
    echo.
)

REM Update Lambda function if requested
if "%UPDATE_FUNCTION%"=="true" (
    echo Step 3: Updating Lambda function configuration...
    call :update_lambda_function
    if %ERRORLEVEL% NEQ 0 (
        echo ERROR: Failed to update Lambda function!
        pause
        exit /b 1
    )
    echo.
)

REM Test connectivity if requested
if "%TEST_CONNECTIVITY%"=="true" (
    echo Step 4: Testing AWS Bedrock connectivity...
    call :test_connectivity
    echo.
)

REM Show summary
call :show_summary

echo ========================================
echo Configuration completed successfully!
echo ========================================

if "%CREATE_ROLE%"=="false" if "%UPDATE_FUNCTION%"=="false" if "%TEST_CONNECTIVITY%"=="false" (
    echo.
    echo No actions specified. Use the following flags:
    echo   --create-role      Create IAM role with required permissions
    echo   --update-function  Update Lambda function configuration
    echo   --test-connectivity Test AWS Bedrock connectivity
    echo   --dry-run          Show what would be done without making changes
    echo.
    echo Example: configure-lambda-function.bat --create-role --update-function --test-connectivity
)

pause
exit /b 0

:create_iam_role
echo Creating IAM role: %ROLE_NAME%

if "%DRY_RUN%"=="true" (
    echo DRY RUN: Would create IAM role %ROLE_NAME%
    exit /b 0
)

REM Check if role already exists
aws iam get-role --role-name %ROLE_NAME% >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo IAM role %ROLE_NAME% already exists
    exit /b 0
)

REM Create trust policy file
echo Creating trust policy...
echo { > trust-policy.json
echo   "Version": "2012-10-17", >> trust-policy.json
echo   "Statement": [ >> trust-policy.json
echo     { >> trust-policy.json
echo       "Effect": "Allow", >> trust-policy.json
echo       "Principal": { >> trust-policy.json
echo         "Service": "lambda.amazonaws.com" >> trust-policy.json
echo       }, >> trust-policy.json
echo       "Action": "sts:AssumeRole" >> trust-policy.json
echo     } >> trust-policy.json
echo   ] >> trust-policy.json
echo } >> trust-policy.json

REM Create the role
aws iam create-role --role-name %ROLE_NAME% --assume-role-policy-document file://trust-policy.json >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Failed to create IAM role
    del trust-policy.json 2>nul
    exit /b 1
)

echo IAM role created successfully

REM Attach basic Lambda execution policy
aws iam attach-role-policy --role-name %ROLE_NAME% --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo WARNING: Failed to attach basic execution policy
)

REM Create custom policy for Bedrock and CloudWatch
echo Creating custom policy...
echo { > custom-policy.json
echo   "Version": "2012-10-17", >> custom-policy.json
echo   "Statement": [ >> custom-policy.json
echo     { >> custom-policy.json
echo       "Effect": "Allow", >> custom-policy.json
echo       "Action": [ >> custom-policy.json
echo         "bedrock:InvokeModel", >> custom-policy.json
echo         "bedrock:InvokeModelWithResponseStream", >> custom-policy.json
echo         "bedrock:ListFoundationModels" >> custom-policy.json
echo       ], >> custom-policy.json
echo       "Resource": "*" >> custom-policy.json
echo     }, >> custom-policy.json
echo     { >> custom-policy.json
echo       "Effect": "Allow", >> custom-policy.json
echo       "Action": [ >> custom-policy.json
echo         "logs:CreateLogGroup", >> custom-policy.json
echo         "logs:CreateLogStream", >> custom-policy.json
echo         "logs:PutLogEvents", >> custom-policy.json
echo         "logs:DescribeLogGroups", >> custom-policy.json
echo         "logs:DescribeLogStreams" >> custom-policy.json
echo       ], >> custom-policy.json
echo       "Resource": "arn:aws:logs:%REGION%:*:*" >> custom-policy.json
echo     } >> custom-policy.json
echo   ] >> custom-policy.json
echo } >> custom-policy.json

set POLICY_NAME=%ROLE_NAME%-policy
aws iam create-policy --policy-name %POLICY_NAME% --policy-document file://custom-policy.json >policy-result.tmp 2>&1
if %ERRORLEVEL% EQU 0 (
    REM Extract policy ARN and attach it
    for /f "tokens=2 delims=:" %%a in ('findstr "Arn" policy-result.tmp') do (
        set POLICY_ARN=%%a
        set POLICY_ARN=!POLICY_ARN:"=!
        set POLICY_ARN=!POLICY_ARN: =!
        set POLICY_ARN=!POLICY_ARN:,=!
    )
    aws iam attach-role-policy --role-name %ROLE_NAME% --policy-arn arn:aws:iam::!POLICY_ARN! >nul 2>&1
    echo Custom policy attached successfully
) else (
    echo WARNING: Failed to create custom policy
)

REM Cleanup temporary files
del trust-policy.json 2>nul
del custom-policy.json 2>nul
del policy-result.tmp 2>nul

echo Waiting for IAM role to be available...
timeout /t 10 /nobreak >nul

exit /b 0

:update_lambda_function
echo Updating Lambda function configuration...

if "%DRY_RUN%"=="true" (
    echo DRY RUN: Would update Lambda function %FUNCTION_NAME%
    exit /b 0
)

REM Get role ARN
for /f "tokens=*" %%a in ('aws iam get-role --role-name %ROLE_NAME% --query "Role.Arn" --output text 2^>nul') do set ROLE_ARN=%%a

if "%ROLE_ARN%"=="" (
    echo ERROR: Could not get IAM role ARN
    exit /b 1
)

echo Using IAM role: %ROLE_ARN%

REM Check if function exists
aws lambda get-function --function-name %FUNCTION_NAME% >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Function %FUNCTION_NAME% does not exist. Creating it...
    
    REM Get Account ID for Image URI construction
    for /f "tokens=*" %%a in ('aws sts get-caller-identity --query "Account" --output text') do set ACCOUNT_ID=%%a
    set IMAGE_URI=!ACCOUNT_ID!.dkr.ecr.%REGION%.amazonaws.com/ai_resume_anaylsis:latest
    
    echo Creating function using image: !IMAGE_URI!
    
    aws lambda create-function ^
        --function-name %FUNCTION_NAME% ^
        --package-type Image ^
        --code ImageUri=!IMAGE_URI! ^
        --role %ROLE_ARN% ^
        --timeout %TIMEOUT% ^
        --memory-size %MEMORY% ^
        --ephemeral-storage Size=%EPHEMERAL_STORAGE% ^
        --environment Variables="{AWS_REGION=%REGION%,BEDROCK_MODEL_ID=%BEDROCK_MODEL_ID%,PYTHONUNBUFFERED=1,AWS_LWA_INVOKE_MODE=response_stream,AWS_LWA_PORT=8080}" >nul 2>&1
        
    if !ERRORLEVEL! NEQ 0 (
        echo ERROR: Failed to create Lambda function
        exit /b 1
    )
    echo Lambda function created successfully
) else (
    echo Updating existing function configuration...
    aws lambda update-function-configuration --function-name %FUNCTION_NAME% --role %ROLE_ARN% --timeout %TIMEOUT% --memory-size %MEMORY% --ephemeral-storage Size=%EPHEMERAL_STORAGE% --environment Variables="{AWS_REGION=%REGION%,BEDROCK_MODEL_ID=%BEDROCK_MODEL_ID%,PYTHONUNBUFFERED=1,AWS_LWA_INVOKE_MODE=response_stream,AWS_LWA_PORT=8080}" >nul 2>&1

    if !ERRORLEVEL! NEQ 0 (
        echo ERROR: Failed to update function configuration
        exit /b 1
    )
    echo Lambda function configuration updated successfully
)

REM Set up CloudWatch log group
set LOG_GROUP_NAME=/aws/lambda/%FUNCTION_NAME%
aws logs describe-log-groups --log-group-name-prefix %LOG_GROUP_NAME% >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Creating CloudWatch log group...
    aws logs create-log-group --log-group-name %LOG_GROUP_NAME% >nul 2>&1
    if !ERRORLEVEL! EQU 0 (
        echo CloudWatch log group created
        aws logs put-retention-policy --log-group-name %LOG_GROUP_NAME% --retention-in-days %LOG_RETENTION_DAYS% >nul 2>&1
        if !ERRORLEVEL! EQU 0 (
            echo Log retention policy set to %LOG_RETENTION_DAYS% days
        )
    )
)

exit /b 0

:test_connectivity
echo Testing AWS Bedrock connectivity...

if "%DRY_RUN%"=="true" (
    echo DRY RUN: Would test Bedrock connectivity
    exit /b 0
)

REM Test Lambda function invocation
echo Invoking Lambda function for connectivity test...
echo {"httpMethod":"GET","path":"/api/status","headers":{},"body":""} > test-payload.json

aws lambda invoke --function-name %FUNCTION_NAME% --payload file://test-payload.json response.json >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Lambda function responded successfully
    echo Response preview:
    type response.json | findstr /C:"status" >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo Status endpoint is working
    )
) else (
    echo WARNING: Lambda function invocation failed
)

REM Test Bedrock model access
echo Testing Bedrock model access...
aws bedrock list-foundation-models --region %REGION% >bedrock-models.json 2>&1
if %ERRORLEVEL% EQU 0 (
    findstr /C:"%BEDROCK_MODEL_ID%" bedrock-models.json >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo Bedrock model %BEDROCK_MODEL_ID% is available
    ) else (
        echo WARNING: Bedrock model %BEDROCK_MODEL_ID% not found in available models
    )
) else (
    echo WARNING: Could not list Bedrock models
)

REM Cleanup
del test-payload.json 2>nul
del response.json 2>nul
del bedrock-models.json 2>nul

exit /b 0

:show_summary
echo ========================================
echo LAMBDA CONFIGURATION SUMMARY
echo ========================================
echo Function Name: %FUNCTION_NAME%
echo IAM Role: %ROLE_NAME%
echo Region: %REGION%
echo Timeout: %TIMEOUT%s
echo Memory: %MEMORY%MB
echo Ephemeral Storage: %EPHEMERAL_STORAGE%MB
echo Bedrock Model: %BEDROCK_MODEL_ID%
echo Log Retention: %LOG_RETENTION_DAYS% days
echo ========================================

if "%DRY_RUN%"=="false" (
    echo Current Function Configuration:
    aws lambda get-function-configuration --function-name %FUNCTION_NAME% --query "{State:State,Timeout:Timeout,Memory:MemorySize,Role:Role}" --output table 2>nul
)

exit /b 0

:show_help
echo.
echo Lambda Function Configuration Script
echo.
echo Usage: configure-lambda-function.bat [OPTIONS]
echo.
echo Options:
echo   --create-role           Create IAM role with required permissions
echo   --update-function       Update Lambda function configuration
echo   --test-connectivity     Test AWS Bedrock connectivity
echo   --dry-run              Show what would be done without making changes
echo   --function-name NAME    Lambda function name (default: talentmatch-ai)
echo   --region REGION         AWS region (default: us-east-1)
echo   --role-name NAME        IAM role name (default: talentmatch-lambda-role)
echo   --help, -h             Show this help message
echo.
echo Examples:
echo   configure-lambda-function.bat --create-role --update-function
echo   configure-lambda-function.bat --test-connectivity
echo   configure-lambda-function.bat --dry-run --create-role
echo.
echo Required Permissions:
echo   - IAM: CreateRole, AttachRolePolicy, CreatePolicy
echo   - Lambda: UpdateFunctionConfiguration, GetFunction
echo   - Logs: CreateLogGroup, PutRetentionPolicy
echo   - Bedrock: ListFoundationModels
echo.
exit /b 0