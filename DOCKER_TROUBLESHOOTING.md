# Docker Build Troubleshooting Guide

## Issue: Docker Build Fails with Network Errors

### Symptoms
```
ERROR: Failed to fetch http://deb.debian.org/...
E: Unable to fetch some archives
```

### Root Cause
Docker Desktop on Windows sometimes has DNS/network issues when building images, especially when running `apt-get update`.

## Solutions

### Solution 1: Use Minimal Dockerfile (Recommended)

We've created `Dockerfile.minimal` that avoids `apt-get` entirely:

```bash
# Run the automated script
build-and-push.bat
```

OR manually:

```bash
# Build with minimal Dockerfile
docker build -f Dockerfile.minimal -t ai_resume_anaylsis .

# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 225989360749.dkr.ecr.us-east-1.amazonaws.com

# Tag
docker tag ai_resume_anaylsis:latest 225989360749.dkr.ecr.us-east-1.amazonaws.com/ai_resume_anaylsis:latest

# Push
docker push 225989360749.dkr.ecr.us-east-1.amazonaws.com/ai_resume_anaylsis:latest
```

### Solution 2: Fix Docker Desktop DNS

1. **Open Docker Desktop**
2. **Go to Settings** → **Resources** → **Network**
3. **Change DNS Server** to:
   ```
   8.8.8.8
   8.8.4.4
   ```
4. **Click "Apply & Restart"**
5. **Try building again**

### Solution 3: Restart Docker Desktop

1. **Right-click Docker Desktop** icon in system tray
2. **Click "Restart"**
3. **Wait for Docker to fully restart** (30-60 seconds)
4. **Try building again**

### Solution 4: Use Docker BuildKit

```bash
# Enable BuildKit for better caching and error handling
set DOCKER_BUILDKIT=1
docker build -t ai_resume_anaylsis .
```

### Solution 5: Build on Linux/WSL2

If you have WSL2 installed:

```bash
# In WSL2 terminal
cd /mnt/c/AIAgents/Resume_Anaylsis_v1
docker build -t ai_resume_anaylsis .
```

## Verification

After successful build:

```bash
# Check image exists
docker images | findstr ai_resume

# Expected output:
# ai_resume_anaylsis   latest   <image-id>   <time>   <size>
```

## Common Errors

### Error: "No such image"
**Cause**: Build failed, image wasn't created  
**Solution**: Check build output for errors, try minimal Dockerfile

### Error: "Login failed"
**Cause**: AWS credentials not configured  
**Solution**: Run `aws configure` and enter your credentials

### Error: "Access denied" when pushing
**Cause**: IAM user doesn't have ECR permissions  
**Solution**: Add `AmazonEC2ContainerRegistryFullAccess` policy to IAM user

### Error: "Repository does not exist"
**Cause**: ECR repository not created  
**Solution**: 
```bash
aws ecr create-repository --repository-name ai_resume_anaylsis --region us-east-1
```

## Files Created

- `Dockerfile.minimal` - Simplified Dockerfile without apt-get
- `build-and-push.bat` - Automated build and push script
- `DOCKER_TROUBLESHOOTING.md` - This file

## Next Steps

Once image is pushed to ECR:
1. See `deployment/lambda-deploy.md` for Lambda deployment
2. See `deployment/apprunner-deploy.md` for App Runner deployment
3. See `deployment/ecs-deploy.md` for ECS deployment
