@echo off
echo ========================================
echo Docker Build and Push to ECR
echo ========================================
echo.

REM Set variables
set IMAGE_NAME=ai_resume_anaylsis
set ECR_REGISTRY=225989360749.dkr.ecr.us-east-1.amazonaws.com
set ECR_REPO=%ECR_REGISTRY%/%IMAGE_NAME%

echo Step 1: Building Docker image...
echo Using minimal Dockerfile to avoid network issues
docker build -f Dockerfile.minimal -t %IMAGE_NAME% .

if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Docker build failed!
    echo.
    echo Troubleshooting:
    echo 1. Make sure Docker Desktop is running
    echo 2. Try restarting Docker Desktop
    echo 3. Check your internet connection
    echo 4. Try building again
    pause
    exit /b 1
)

echo.
echo Step 2: Logging in to AWS ECR...
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin %ECR_REGISTRY%

if %ERRORLEVEL% NEQ 0 (
    echo ERROR: ECR login failed!
    echo.
    echo Troubleshooting:
    echo 1. Make sure AWS CLI is installed and configured
    echo 2. Run: aws configure
    echo 3. Check your AWS credentials
    pause
    exit /b 1
)

echo.
echo Step 3: Tagging image...
docker tag %IMAGE_NAME%:latest %ECR_REPO%:latest

if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Docker tag failed!
    pause
    exit /b 1
)

echo.
echo Step 4: Pushing image to ECR...
docker push %ECR_REPO%:latest

if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Docker push failed!
    pause
    exit /b 1
)

echo.
echo ========================================
echo SUCCESS! Image pushed to ECR
echo ========================================
echo.
echo Image: %ECR_REPO%:latest
echo.
echo Next steps:
echo 1. Deploy to AWS Lambda, App Runner, or ECS
echo 2. See deployment guides in deployment/ folder
echo.
pause
