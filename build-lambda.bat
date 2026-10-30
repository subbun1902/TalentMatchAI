@echo off
echo ========================================
echo Lambda Docker Build and ECR Push
echo ========================================
echo.

REM Set variables for Lambda deployment
set IMAGE_NAME=talentmatch-lambda
set ECR_REGISTRY=225989360749.dkr.ecr.us-east-1.amazonaws.com
set ECR_REPO=%ECR_REGISTRY%/%IMAGE_NAME%
set LAMBDA_FUNCTION_NAME=talentmatch-ai

echo Step 1: Validating prerequisites...
echo Checking Docker availability...
docker --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Docker is not available or not running!
    echo Please ensure Docker Desktop is installed and running.
    pause
    exit /b 1
)

echo Checking AWS CLI availability...
aws --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: AWS CLI is not available!
    echo Please install and configure AWS CLI.
    pause
    exit /b 1
)

echo Checking Dockerfile exists...
if not exist "Dockerfile" (
    echo ERROR: Dockerfile not found!
    echo Please ensure Dockerfile exists in the current directory.
    pause
    exit /b 1
)

echo Prerequisites validated successfully.
echo.

echo Step 2: Building Lambda-compatible Docker image...
echo Using Dockerfile with Linux/AMD64 platform for Lambda compatibility
docker build --platform linux/amd64 -f Dockerfile -t %IMAGE_NAME% .

if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Docker build failed!
    echo.
    echo Troubleshooting:
    echo 1. Make sure Docker Desktop is running
    echo 2. Check that Dockerfile exists and is valid
    echo 3. Verify all required files (app_simple.py, requirements.txt, etc.) exist
    echo 4. Try restarting Docker Desktop
    echo 5. Check your internet connection for base image download
    pause
    exit /b 1
)

echo.
echo Step 3: Validating built image...
echo Testing if the image was built successfully...
docker images %IMAGE_NAME%:latest --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Built image validation failed!
    echo The image was not found in local Docker registry.
    pause
    exit /b 1
) else (
    echo Image validation successful - image found in local registry.
)

echo Image validation successful.
echo.

echo Step 4: Authenticating with AWS ECR...
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin %ECR_REGISTRY%

if %ERRORLEVEL% NEQ 0 (
    echo ERROR: ECR authentication failed!
    echo.
    echo Troubleshooting:
    echo 1. Make sure AWS CLI is configured: aws configure
    echo 2. Check your AWS credentials and permissions
    echo 3. Verify ECR repository exists: aws ecr describe-repositories --repository-names %IMAGE_NAME%
    echo 4. Ensure you have ECR permissions (ecr:GetAuthorizationToken, ecr:BatchCheckLayerAvailability, etc.)
    pause
    exit /b 1
)

echo.
echo Step 5: Tagging image for ECR...
docker tag %IMAGE_NAME%:latest %ECR_REPO%:latest

if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Docker tag operation failed!
    pause
    exit /b 1
)

echo.
echo Step 6: Pushing image to ECR...
echo This may take several minutes depending on image size and network speed...
docker push %ECR_REPO%:latest

if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Docker push to ECR failed!
    echo.
    echo Troubleshooting:
    echo 1. Check your internet connection
    echo 2. Verify ECR repository exists and you have push permissions
    echo 3. Try re-authenticating with ECR
    echo 4. Check ECR repository policies
    pause
    exit /b 1
)

echo.
echo Step 7: Final validation...
echo Verifying image was pushed successfully...
aws ecr describe-images --repository-name %IMAGE_NAME% --region us-east-1 --query "imageDetails[0].imageTags" --output text >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo WARNING: Could not verify image in ECR repository.
    echo The push may have succeeded, but verification failed.
    echo Please check manually: aws ecr describe-images --repository-name %IMAGE_NAME%
) else (
    echo Image successfully verified in ECR repository.
)

echo.
echo ========================================
echo SUCCESS! Lambda image built and pushed
echo ========================================
echo.
echo Image Details:
echo - Name: %IMAGE_NAME%
echo - ECR URI: %ECR_REPO%:latest
echo - Platform: linux/amd64 (Lambda compatible)
echo - Dockerfile: Dockerfile
echo.
echo Next Steps:
echo 1. Update Lambda function with new image:
echo    aws lambda update-function-code --function-name %LAMBDA_FUNCTION_NAME% --image-uri %ECR_REPO%:latest
echo.
echo 2. Or run the deployment script:
echo    deploy-lambda.bat
echo.
echo 3. Test the deployment:
echo    aws lambda invoke --function-name %LAMBDA_FUNCTION_NAME% --payload {} response.json
echo.
pause