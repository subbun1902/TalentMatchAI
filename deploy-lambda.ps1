# Lambda Deployment Automation PowerShell Script
param(
    [string]$FunctionName = "talentmatch-ai",
    [string]$ImageName = "talentmatch-lambda",
    [string]$ECRRegistry = "225989360749.dkr.ecr.us-east-1.amazonaws.com",
    [string]$Region = "us-east-1",
    [switch]$SkipBuild,
    [switch]$DryRun
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Initialize variables
$ECRRepo = "$ECRRegistry/$ImageName"
$DeploymentLog = "logs/deployment_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$HealthCheckTimeout = 60
$RollbackEnabled = $true
$CurrentImageUri = $null

# Ensure logs directory exists
if (!(Test-Path "logs")) {
    New-Item -ItemType Directory -Path "logs" -Force | Out-Null
}

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
    Add-Content -Path $DeploymentLog -Value $logEntry
}

# Error handling function
function Handle-Error {
    param([string]$ErrorMessage, [bool]$ShouldRollback = $true)
    Write-Log "ERROR: $ErrorMessage" "ERROR"
    
    if ($ShouldRollback -and $RollbackEnabled -and $CurrentImageUri) {
        Write-Log "Initiating rollback to previous image: $CurrentImageUri" "WARN"
        try {
            Invoke-Rollback
        }
        catch {
            Write-Log "CRITICAL: Rollback failed! Manual intervention required." "CRITICAL"
            Write-Log "Rollback error: $($_.Exception.Message)" "CRITICAL"
        }
    }
    
    Write-Log "Deployment failed. Check log: $DeploymentLog" "ERROR"
    exit 1
}

# Rollback function
function Invoke-Rollback {
    Write-Log "Starting rollback process..." "WARN"
    
    try {
        $rollbackResult = aws lambda update-function-code --function-name $FunctionName --image-uri $CurrentImageUri 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "AWS CLI rollback command failed: $rollbackResult"
        }
        
        Write-Log "Rollback command executed successfully" "INFO"
        
        # Wait for rollback to complete
        $maxWait = 30
        $waited = 0
        do {
            Start-Sleep -Seconds 2
            $waited += 2
            $state = aws lambda get-function --function-name $FunctionName --query "Configuration.State" --output text 2>$null
            Write-Log "Rollback state: $state (waited ${waited}s)" "INFO"
        } while ($state -ne "Active" -and $waited -lt $maxWait)
        
        if ($state -eq "Active") {
            Write-Log "Rollback completed successfully" "INFO"
        } else {
            Write-Log "Rollback may not be complete - function state: $state" "WARN"
        }
    }
    catch {
        throw "Rollback failed: $($_.Exception.Message)"
    }
}

# Health check function
function Test-LambdaHealth {
    Write-Log "Starting health check validation..." "INFO"
    
    try {
        # Test /api/status endpoint
        $payload = @{
            httpMethod = "GET"
            path = "/api/status"
            headers = @{}
            body = ""
        } | ConvertTo-Json -Compress
        
        $tempFile = [System.IO.Path]::GetTempFileName()
        $result = aws lambda invoke --function-name $FunctionName --payload $payload $tempFile 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            throw "Health check invocation failed: $result"
        }
        
        $response = Get-Content $tempFile -Raw | ConvertFrom-Json
        Remove-Item $tempFile -Force
        
        # Check if response contains expected status
        if ($response.body -match '"status"') {
            Write-Log "Health check passed - status endpoint responding correctly" "INFO"
            return $true
        } else {
            Write-Log "Health check failed - invalid response format" "ERROR"
            Write-Log "Response: $($response | ConvertTo-Json)" "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Health check failed with exception: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Prerequisite validation
function Test-Prerequisites {
    Write-Log "Validating prerequisites..." "INFO"
    
    # Check Docker
    try {
        $dockerVersion = docker --version 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Docker is not available or not running"
        }
        Write-Log "Docker available: $dockerVersion" "INFO"
    }
    catch {
        Handle-Error "Docker is not available. Please ensure Docker Desktop is installed and running." $false
    }
    
    # Check AWS CLI
    try {
        $awsVersion = aws --version 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "AWS CLI is not available"
        }
        Write-Log "AWS CLI available: $awsVersion" "INFO"
    }
    catch {
        Handle-Error "AWS CLI is not available. Please install and configure AWS CLI." $false
    }
    
    Write-Log "Prerequisites validated successfully" "INFO"
}

# Main deployment process
try {
    Write-Log "========================================" "INFO"
    Write-Log "Lambda Deployment Automation Started" "INFO"
    Write-Log "========================================" "INFO"
    Write-Log "Function: $FunctionName" "INFO"
    Write-Log "Image: $ImageName" "INFO"
    Write-Log "ECR: $ECRRepo" "INFO"
    Write-Log "Region: $Region" "INFO"
    Write-Log "Dry Run: $DryRun" "INFO"
    Write-Log "========================================" "INFO"
    
    if ($DryRun) {
        Write-Log "DRY RUN MODE - No actual changes will be made" "WARN"
    }
    
    # Step 1: Validate prerequisites
    Test-Prerequisites
    
    # Step 2: Get current Lambda function configuration for rollback
    Write-Log "Retrieving current Lambda function configuration..." "INFO"
    try {
        $CurrentImageUri = aws lambda get-function --function-name $FunctionName --query "Code.ImageUri" --output text 2>$null
        if ($LASTEXITCODE -eq 0 -and $CurrentImageUri) {
            Write-Log "Current image URI: $CurrentImageUri" "INFO"
            $RollbackEnabled = $true
        } else {
            Write-Log "Could not retrieve current function configuration - rollback will be limited" "WARN"
            $RollbackEnabled = $false
        }
    }
    catch {
        Write-Log "Warning: Could not retrieve current function configuration: $($_.Exception.Message)" "WARN"
        $RollbackEnabled = $false
    }
    
    # Step 3: Build and push image (unless skipped)
    if (!$SkipBuild) {
        Write-Log "Building and pushing Docker image..." "INFO"
        if (!$DryRun) {
            $buildResult = & ".\build-lambda.bat"
            if ($LASTEXITCODE -ne 0) {
                Handle-Error "Image build and push failed"
            }
        } else {
            Write-Log "DRY RUN: Would execute build-lambda.bat" "INFO"
        }
        Write-Log "Image build and push completed successfully" "INFO"
    } else {
        Write-Log "Skipping image build (--SkipBuild specified)" "INFO"
    }
    
    # Step 4: Update Lambda function
    Write-Log "Updating Lambda function with new image..." "INFO"
    if (!$DryRun) {
        $updateResult = aws lambda update-function-code --function-name $FunctionName --image-uri "${ECRRepo}:latest" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Handle-Error "Lambda function update failed: $updateResult"
        }
    } else {
        Write-Log "DRY RUN: Would update Lambda function with image ${ECRRepo}:latest" "INFO"
    }
    Write-Log "Lambda function updated successfully" "INFO"
    
    # Step 5: Wait for function to be ready
    if (!$DryRun) {
        Write-Log "Waiting for Lambda function to reach Active state..." "INFO"
        $maxWait = 60
        $waited = 0
        do {
            Start-Sleep -Seconds 3
            $waited += 3
            $state = aws lambda get-function --function-name $FunctionName --query "Configuration.State" --output text 2>$null
            Write-Log "Function state: $state (waited ${waited}s)" "INFO"
        } while ($state -ne "Active" -and $waited -lt $maxWait)
        
        if ($state -ne "Active") {
            Handle-Error "Function did not reach Active state within timeout (${maxWait}s). Current state: $state"
        }
    } else {
        Write-Log "DRY RUN: Would wait for function to reach Active state" "INFO"
    }
    
    # Step 6: Health check validation
    if (!$DryRun) {
        if (!(Test-LambdaHealth)) {
            Handle-Error "Health check validation failed"
        }
    } else {
        Write-Log "DRY RUN: Would perform health check validation" "INFO"
    }
    
    # Step 7: Final validation
    Write-Log "Performing final deployment validation..." "INFO"
    if (!$DryRun) {
        try {
            $finalConfig = aws lambda get-function-configuration --function-name $FunctionName --query "{State:State,LastUpdateStatus:LastUpdateStatus,ImageUri:Code.ImageUri}" --output json 2>&1
            if ($LASTEXITCODE -eq 0) {
                $config = $finalConfig | ConvertFrom-Json
                Write-Log "Final function state: $($config.State)" "INFO"
                Write-Log "Last update status: $($config.LastUpdateStatus)" "INFO"
                Write-Log "Current image URI: $($config.ImageUri)" "INFO"
            } else {
                Write-Log "Warning: Could not retrieve final function configuration" "WARN"
            }
        }
        catch {
            Write-Log "Warning: Final validation check failed: $($_.Exception.Message)" "WARN"
        }
    } else {
        Write-Log "DRY RUN: Would perform final validation" "INFO"
    }
    
    # Success
    Write-Log "========================================" "INFO"
    Write-Log "SUCCESS! Deployment completed" "INFO"
    Write-Log "========================================" "INFO"
    Write-Log "Function: $FunctionName" "INFO"
    Write-Log "New Image: ${ECRRepo}:latest" "INFO"
    Write-Log "Status: Successfully deployed and validated" "INFO"
    Write-Log "Log File: $DeploymentLog" "INFO"
    Write-Log "========================================" "INFO"
    
    Write-Host "`nNext Steps:" -ForegroundColor Green
    Write-Host "1. Test your application endpoints" -ForegroundColor Yellow
    Write-Host "2. Monitor CloudWatch logs for any issues" -ForegroundColor Yellow
    Write-Host "3. Review deployment log: $DeploymentLog" -ForegroundColor Yellow
    
}
catch {
    Handle-Error "Unexpected error during deployment: $($_.Exception.Message)"
}