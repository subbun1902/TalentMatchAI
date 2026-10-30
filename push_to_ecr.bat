@echo off
echo ========================================
echo Build and Push to ECR (ai_resume_anaylsis)
echo ========================================
echo.

set REGION=us-east-1
set ACCOUNT_ID=225989360749
set REPO_NAME=ai_resume_anaylsis
set ECR_URI=%ACCOUNT_ID%.dkr.ecr.%REGION%.amazonaws.com

echo Step 1: Authenticating...
aws ecr get-login-password --region %REGION% | docker login --username AWS --password-stdin %ECR_URI%
if %ERRORLEVEL% NEQ 0 (
    echo Authentication failed!
    pause
    exit /b 1
)

echo.
echo Step 2: Building image (linux/amd64)...
docker build --platform linux/amd64 -t %REPO_NAME% .
if %ERRORLEVEL% NEQ 0 (
    echo Build failed!
    pause
    exit /b 1
)

echo.
echo Step 3: Tagging image...
docker tag %REPO_NAME%:latest %ECR_URI%/%REPO_NAME%:latest

echo.
echo Step 4: Pushing image...
docker push %ECR_URI%/%REPO_NAME%:latest
if %ERRORLEVEL% NEQ 0 (
    echo Push failed!
    pause
    exit /b 1
)

echo.
echo SUCCESS! Image pushed to %ECR_URI%/%REPO_NAME%:latest
pause
