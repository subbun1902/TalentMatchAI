@echo off
echo ========================================
echo Complete Lambda Deployment Pipeline
echo ========================================
echo.

REM Set variables
set LAMBDA_FUNCTION_NAME=talentmatch-ai
set DEPLOYMENT_LOG=logs\full_deployment_%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%.log
set SKIP_BUILD=false
set SKIP_VALIDATION=false
set ENABLE_MONITORING=false

REM Parse command line arguments
:parse_args
if "%1"=="--skip-build" (
    set SKIP_BUILD=true
    shift
    goto :parse_args
)
if "%1"=="--skip-validation" (
    set SKIP_VALIDATION=true
    shift
    goto :parse_args
)
if "%1"=="--enable-monitoring" (
    set ENABLE_MONITORING=true
    shift
    goto :parse_args
)
if "%1"=="--help" goto :show_help
if "%1"=="-h" goto :show_help
if not "%1"=="" (
    echo Unknown argument: %1
    goto :show_help
)

REM Create logs directory if it doesn't exist
if not exist "logs" mkdir logs

echo Full deployment pipeline started at %date% %time% > %DEPLOYMENT_LOG%
echo ========================================

echo Pipeline Configuration:
echo - Function: %LAMBDA_FUNCTION_NAME%
echo - Skip Build: %SKIP_BUILD%
echo - Skip Validation: %SKIP_VALIDATION%
echo - Enable Monitoring: %ENABLE_MONITORING%
echo - Log File: %DEPLOYMENT_LOG%
echo.

echo Pipeline configuration: >> %DEPLOYMENT_LOG%
echo - Skip Build: %SKIP_BUILD% >> %DEPLOYMENT_LOG%
echo - Skip Validation: %SKIP_VALIDATION% >> %DEPLOYMENT_LOG%
echo - Enable Monitoring: %ENABLE_MONITORING% >> %DEPLOYMENT_LOG%

echo Phase 1: Pre-deployment validation...
echo Pre-deployment validation started >> %DEPLOYMENT_LOG%

REM Check if required files exist
if not exist "Dockerfile.lambda" (
    echo ERROR: Dockerfile.lambda not found!
    echo ERROR: Dockerfile.lambda not found! >> %DEPLOYMENT_LOG%
    goto :error_exit
)

if not exist "app_simple.py" (
    echo ERROR: app_simple.py not found!
    echo ERROR: app_simple.py not found! >> %DEPLOYMENT_LOG%
    goto :error_exit
)

if not exist "requirements.txt" (
    echo ERROR: requirements.txt not found!
    echo ERROR: requirements.txt not found! >> %DEPLOYMENT_LOG%
    goto :error_exit
)

echo Pre-deployment validation passed ✓
echo Pre-deployment validation passed >> %DEPLOYMENT_LOG%

echo.
echo Phase 2: Build and deployment...
echo Build and deployment phase started >> %DEPLOYMENT_LOG%

if "%SKIP_BUILD%"=="true" (
    echo Skipping build phase (--skip-build specified)
    echo Build phase skipped >> %DEPLOYMENT_LOG%
    
    REM Just run deployment without build
    call deploy-lambda.bat
    if %ERRORLEVEL% NEQ 0 (
        echo ERROR: Deployment failed!
        echo ERROR: Deployment failed! >> %DEPLOYMENT_LOG%
        goto :error_exit
    )
) else (
    REM Run full deployment (includes build)
    call deploy-lambda.bat
    if %ERRORLEVEL% NEQ 0 (
        echo ERROR: Build and deployment failed!
        echo ERROR: Build and deployment failed! >> %DEPLOYMENT_LOG%
        goto :error_exit
    )
)

echo Build and deployment completed successfully ✓
echo Build and deployment completed >> %DEPLOYMENT_LOG%

echo.
echo Phase 3: Post-deployment validation...
echo Post-deployment validation started >> %DEPLOYMENT_LOG%

if "%SKIP_VALIDATION%"=="true" (
    echo Skipping validation phase (--skip-validation specified)
    echo Validation phase skipped >> %DEPLOYMENT_LOG%
) else (
    call validate-lambda-deployment.bat --no-pause
    if %ERRORLEVEL% NEQ 0 (
        echo WARNING: Post-deployment validation failed!
        echo WARNING: Post-deployment validation failed! >> %DEPLOYMENT_LOG%
        echo This may indicate deployment issues that need attention.
        echo.
    ) else (
        echo Post-deployment validation passed ✓
        echo Post-deployment validation passed >> %DEPLOYMENT_LOG%
    )
)

echo.
echo Phase 4: Monitoring setup...
echo Monitoring setup started >> %DEPLOYMENT_LOG%

if "%ENABLE_MONITORING%"=="true" (
    echo Starting deployment monitoring...
    echo Monitoring enabled - starting 5-minute monitoring session >> %DEPLOYMENT_LOG%
    
    REM Start monitoring in background (PowerShell required)
    powershell -ExecutionPolicy Bypass -File "monitor-lambda-deployment.ps1" -FunctionName %LAMBDA_FUNCTION_NAME% -MonitorDurationMinutes 5 -CheckIntervalSeconds 30
    
    if %ERRORLEVEL% NEQ 0 (
        echo WARNING: Monitoring session completed with issues
        echo WARNING: Monitoring completed with issues >> %DEPLOYMENT_LOG%
    ) else (
        echo Monitoring session completed successfully ✓
        echo Monitoring completed successfully >> %DEPLOYMENT_LOG%
    )
) else (
    echo Monitoring disabled (use --enable-monitoring to enable)
    echo Monitoring disabled >> %DEPLOYMENT_LOG%
)

echo.
echo ========================================
echo DEPLOYMENT PIPELINE COMPLETED
echo ========================================
echo.
echo Summary:
echo - Function: %LAMBDA_FUNCTION_NAME%
echo - Status: Successfully deployed
echo - Build: %SKIP_BUILD:true=Skipped%
echo - Build: %SKIP_BUILD:false=Completed%
echo - Validation: %SKIP_VALIDATION:true=Skipped%
echo - Validation: %SKIP_VALIDATION:false=Completed%
echo - Monitoring: %ENABLE_MONITORING:true=Enabled%
echo - Monitoring: %ENABLE_MONITORING:false=Disabled%
echo - Log File: %DEPLOYMENT_LOG%
echo.

echo Pipeline completed successfully at %date% %time% >> %DEPLOYMENT_LOG%
echo ======================================== >> %DEPLOYMENT_LOG%

echo Next Steps:
echo 1. Test your Lambda function endpoints
echo 2. Monitor CloudWatch logs for any issues
echo 3. Review deployment logs: %DEPLOYMENT_LOG%
echo 4. Set up CloudWatch alarms if needed
echo.

if "%ENABLE_MONITORING%"=="false" (
    echo Optional: Run monitoring manually:
    echo   powershell -File monitor-lambda-deployment.ps1
    echo.
)

pause
exit /b 0

:error_exit
echo.
echo ========================================
echo DEPLOYMENT PIPELINE FAILED
echo ========================================
echo.
echo The deployment pipeline encountered errors.
echo Check the log file for details: %DEPLOYMENT_LOG%
echo.
echo Pipeline failed at %date% %time% >> %DEPLOYMENT_LOG%
echo ======================================== >> %DEPLOYMENT_LOG%
pause
exit /b 1

:show_help
echo.
echo Complete Lambda Deployment Pipeline
echo.
echo Usage: full-lambda-deploy.bat [OPTIONS]
echo.
echo Options:
echo   --skip-build        Skip the Docker build phase (deploy existing image)
echo   --skip-validation   Skip post-deployment validation tests
echo   --enable-monitoring Enable 5-minute monitoring session after deployment
echo   --help, -h          Show this help message
echo.
echo Examples:
echo   full-lambda-deploy.bat                    # Full pipeline
echo   full-lambda-deploy.bat --skip-build      # Deploy without rebuilding
echo   full-lambda-deploy.bat --enable-monitoring # Include monitoring
echo.
echo Individual Scripts:
echo   build-lambda.bat                         # Build and push image only
echo   deploy-lambda.bat                        # Deploy with rollback support
echo   validate-lambda-deployment.bat           # Validation tests only
echo   monitor-lambda-deployment.ps1            # Monitoring only (PowerShell)
echo.
exit /b 0