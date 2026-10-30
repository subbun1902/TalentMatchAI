@echo off
echo ========================================
echo Building Lambda-Compatible Docker Image
echo ========================================
echo.

set REGION=us-east-1
set ACCOUNT_ID=225989360749
set REPO_NAME=ai_resume_anaylsis
set ECR_URI=%ACCOUNT_ID%.dkr.ecr.%REGION%.amazonaws.com

echo Step 1: Authenticating with ECR...
aws ecr get-login-password --region %REGION% | docker login --username AWS --password-stdin %ECR_URI%
if %ERRORLEVEL% NEQ 0 (
    echo Authentication failed!
    pause
    exit /b 1
)

echo.
echo Step 2: Building image for Lambda (linux/amd64)...
echo NOTE: Using AWS Lambda Python base image
docker build --platform linux/amd64 --no-cache -t %REPO_NAME% .
if %ERRORLEVEL% NEQ 0 (
    echo Build failed!
    pause
    exit /b 1
)

echo.
echo Step 3: Tagging image...
docker tag %REPO_NAME%:latest %ECR_URI%/%REPO_NAME%:latest

echo.
echo Step 4: Pushing image to ECR...
docker push %ECR_URI%/%REPO_NAME%:latest
if %ERRORLEVEL% NEQ 0 (
    echo Push failed!
    pause
    exit /b 1
)

echo.
echo Step 5: Verifying image in ECR...
aws ecr describe-images --repository-name %REPO_NAME% --region %REGION% --query "imageDetails[0].{Digest:imageDigest,Tags:imageTags,Size:imageSizeInBytes}" --output table

echo.
echo SUCCESS! Lambda-compatible image pushed to ECR
echo Image URI: %ECR_URI%/%REPO_NAME%:latest
echo.
echo You can now create your Lambda function using this image.
pause
