# Lambda Function Configuration Script
# Configures Lambda function settings and IAM permissions for TalentMatch AI

param(
    [string]$FunctionName = "talentmatch-ai",
    [string]$Region = "us-east-1",
    [string]$RoleName = "talentmatch-lambda-role",
    [int]$Timeout = 300,
    [int]$Memory = 2048,
    [int]$EphemeralStorage = 512,
    [switch]$CreateRole,
    [switch]$UpdateFunction,
    [switch]$TestConnectivity,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Configuration
$BedrockModelId = "anthropic.claude-3-sonnet-20240229-v1:0"
$LogRetentionDays = 14

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

# Check prerequisites
function Test-Prerequisites {
    Write-Log "Checking prerequisites..." "INFO"
    
    try {
        $awsVersion = aws --version 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "AWS CLI is not available"
        }
        Write-Log "AWS CLI available: $awsVersion" "INFO"
        
        # Test AWS credentials
        $identity = aws sts get-caller-identity --output json 2>$null | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0) {
            throw "AWS credentials not configured"
        }
        Write-Log "AWS credentials validated for: $($identity.Arn)" "INFO"
        
    } catch {
        Write-Log "Prerequisites check failed: $($_.Exception.Message)" "ERROR"
        exit 1
    }
}

# Create IAM role with required permissions
function New-LambdaIAMRole {
    param([string]$RoleName)
    
    Write-Log "Creating IAM role: $RoleName" "INFO"
    
    if ($DryRun) {
        Write-Log "DRY RUN: Would create IAM role $RoleName" "INFO"
        return
    }
    
    try {
        # Check if role already exists
        $existingRole = aws iam get-role --role-name $RoleName 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "IAM role $RoleName already exists" "INFO"
            return
        }
        
        # Create trust policy for Lambda
        $trustPolicy = @{
            Version = "2012-10-17"
            Statement = @(
                @{
                    Effect = "Allow"
                    Principal = @{
                        Service = "lambda.amazonaws.com"
                    }
                    Action = "sts:AssumeRole"
                }
            )
        } | ConvertTo-Json -Depth 10 -Compress
        
        # Create the role
        $roleResult = aws iam create-role --role-name $RoleName --assume-role-policy-document $trustPolicy --output json 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create IAM role: $roleResult"
        }
        
        Write-Log "IAM role created successfully" "INFO"
        
        # Attach basic Lambda execution policy
        aws iam attach-role-policy --role-name $RoleName --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Warning: Failed to attach basic execution policy" "WARN"
        }
        
        # Create and attach custom policy for Bedrock and CloudWatch
        $customPolicy = @{
            Version = "2012-10-17"
            Statement = @(
                @{
                    Effect = "Allow"
                    Action = @(
                        "bedrock:InvokeModel",
                        "bedrock:InvokeModelWithResponseStream",
                        "bedrock:ListFoundationModels"
                    )
                    Resource = "*"
                },
                @{
                    Effect = "Allow"
                    Action = @(
                        "logs:CreateLogGroup",
                        "logs:CreateLogStream",
                        "logs:PutLogEvents",
                        "logs:DescribeLogGroups",
                        "logs:DescribeLogStreams"
                    )
                    Resource = "arn:aws:logs:${Region}:*:*"
                }
            )
        } | ConvertTo-Json -Depth 10 -Compress
        
        $policyName = "${RoleName}-policy"
        $policyResult = aws iam create-policy --policy-name $policyName --policy-document $customPolicy --output json 2>&1
        if ($LASTEXITCODE -eq 0) {
            $policyArn = ($policyResult | ConvertFrom-Json).Policy.Arn
            aws iam attach-role-policy --role-name $RoleName --policy-arn $policyArn
            Write-Log "Custom policy attached successfully" "INFO"
        } else {
            Write-Log "Warning: Failed to create custom policy: $policyResult" "WARN"
        }
        
        # Wait for role to be available
        Write-Log "Waiting for IAM role to be available..." "INFO"
        Start-Sleep -Seconds 10
        
    } catch {
        Write-Log "Failed to create IAM role: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Update Lambda function configuration
function Update-LambdaConfiguration {
    param([string]$FunctionName, [string]$RoleName)
    
    Write-Log "Updating Lambda function configuration..." "INFO"
    
    if ($DryRun) {
        Write-Log "DRY RUN: Would update Lambda function $FunctionName" "INFO"
        return
    }
    
    try {
        # Get role ARN
        $roleInfo = aws iam get-role --role-name $RoleName --output json | ConvertFrom-Json
        $roleArn = $roleInfo.Role.Arn
        
        Write-Log "Using IAM role: $roleArn" "INFO"
        
        # Check if function exists
        $functionExists = $false
        try {
            aws lambda get-function --function-name $FunctionName --output json >$null 2>&1
            $functionExists = ($LASTEXITCODE -eq 0)
        } catch {
            $functionExists = $false
        }
        
        if ($functionExists) {
            Write-Log "Updating existing Lambda function configuration..." "INFO"
            
            # Update function configuration
            $configResult = aws lambda update-function-configuration `
                --function-name $FunctionName `
                --role $roleArn `
                --timeout $Timeout `
                --memory-size $Memory `
                --ephemeral-storage Size=$EphemeralStorage `
                --environment Variables="{AWS_REGION=$Region,BEDROCK_MODEL_ID=$BedrockModelId,PYTHONUNBUFFERED=1,AWS_LWA_INVOKE_MODE=response_stream,AWS_LWA_PORT=8080}" `
                --output json 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to update function configuration: $configResult"
            }
            
            Write-Log "Lambda function configuration updated successfully" "INFO"
            
        } else {
            Write-Log "Lambda function $FunctionName does not exist. Please deploy the function first." "WARN"
            Write-Log "Use deploy-lambda.bat to create the function with container image" "INFO"
        }
        
    } catch {
        Write-Log "Failed to update Lambda configuration: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Set up CloudWatch log group
function Set-CloudWatchLogGroup {
    param([string]$FunctionName)
    
    Write-Log "Setting up CloudWatch log group..." "INFO"
    
    if ($DryRun) {
        Write-Log "DRY RUN: Would setup CloudWatch log group" "INFO"
        return
    }
    
    try {
        $logGroupName = "/aws/lambda/$FunctionName"
        
        # Check if log group exists
        $existingGroup = aws logs describe-log-groups --log-group-name-prefix $logGroupName --output json 2>$null
        if ($LASTEXITCODE -eq 0) {
            $groups = ($existingGroup | ConvertFrom-Json).logGroups
            if ($groups.Count -gt 0) {
                Write-Log "CloudWatch log group already exists" "INFO"
                return
            }
        }
        
        # Create log group
        aws logs create-log-group --log-group-name $logGroupName 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "CloudWatch log group created" "INFO"
            
            # Set retention policy
            aws logs put-retention-policy --log-group-name $logGroupName --retention-in-days $LogRetentionDays 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Log retention policy set to $LogRetentionDays days" "INFO"
            }
        } else {
            Write-Log "Warning: Failed to create CloudWatch log group" "WARN"
        }
        
    } catch {
        Write-Log "CloudWatch setup warning: $($_.Exception.Message)" "WARN"
    }
}

# Test AWS Bedrock connectivity
function Test-BedrockConnectivity {
    param([string]$FunctionName)
    
    Write-Log "Testing AWS Bedrock connectivity..." "INFO"
    
    if ($DryRun) {
        Write-Log "DRY RUN: Would test Bedrock connectivity" "INFO"
        return
    }
    
    try {
        # Test payload for Bedrock connectivity
        $testPayload = @{
            httpMethod = "GET"
            path = "/api/status"
            headers = @{}
            body = ""
        } | ConvertTo-Json -Compress
        
        Write-Log "Invoking Lambda function for connectivity test..." "INFO"
        
        $tempFile = [System.IO.Path]::GetTempFileName()
        $invokeResult = aws lambda invoke --function-name $FunctionName --payload $testPayload $tempFile 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $response = Get-Content $tempFile -Raw
            Write-Log "Lambda function responded successfully" "INFO"
            Write-Log "Response preview: $($response.Substring(0, [Math]::Min(200, $response.Length)))" "INFO"
            
            # Test Bedrock model access directly
            Write-Log "Testing Bedrock model access..." "INFO"
            $bedrockTest = aws bedrock list-foundation-models --region $Region --output json 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                $models = ($bedrockTest | ConvertFrom-Json).modelSummaries
                $targetModel = $models | Where-Object { $_.modelId -eq $BedrockModelId }
                
                if ($targetModel) {
                    Write-Log "Bedrock model $BedrockModelId is available" "INFO"
                } else {
                    Write-Log "Warning: Bedrock model $BedrockModelId not found in available models" "WARN"
                    Write-Log "Available models: $($models.modelId -join ', ')" "INFO"
                }
            } else {
                Write-Log "Warning: Could not list Bedrock models: $bedrockTest" "WARN"
            }
            
        } else {
            Write-Log "Warning: Lambda function invocation failed: $invokeResult" "WARN"
        }
        
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        
    } catch {
        Write-Log "Connectivity test warning: $($_.Exception.Message)" "WARN"
    }
}

# Display configuration summary
function Show-ConfigurationSummary {
    param([string]$FunctionName, [string]$RoleName)
    
    Write-Log "========================================" "INFO"
    Write-Log "LAMBDA CONFIGURATION SUMMARY" "INFO"
    Write-Log "========================================" "INFO"
    Write-Log "Function Name: $FunctionName" "INFO"
    Write-Log "IAM Role: $RoleName" "INFO"
    Write-Log "Region: $Region" "INFO"
    Write-Log "Timeout: ${Timeout}s" "INFO"
    Write-Log "Memory: ${Memory}MB" "INFO"
    Write-Log "Ephemeral Storage: ${EphemeralStorage}MB" "INFO"
    Write-Log "Bedrock Model: $BedrockModelId" "INFO"
    Write-Log "Log Retention: $LogRetentionDays days" "INFO"
    Write-Log "========================================" "INFO"
    
    if (!$DryRun) {
        try {
            # Get current function configuration
            $currentConfig = aws lambda get-function-configuration --function-name $FunctionName --output json 2>$null | ConvertFrom-Json
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Current Function Configuration:" "INFO"
                Write-Log "  State: $($currentConfig.State)" "INFO"
                Write-Log "  Runtime: $($currentConfig.PackageType)" "INFO"
                Write-Log "  Timeout: $($currentConfig.Timeout)s" "INFO"
                Write-Log "  Memory: $($currentConfig.MemorySize)MB" "INFO"
                Write-Log "  Role: $($currentConfig.Role)" "INFO"
                
                if ($currentConfig.Environment -and $currentConfig.Environment.Variables) {
                    Write-Log "  Environment Variables:" "INFO"
                    $currentConfig.Environment.Variables.PSObject.Properties | ForEach-Object {
                        Write-Log "    $($_.Name): $($_.Value)" "INFO"
                    }
                }
            }
        } catch {
            Write-Log "Could not retrieve current configuration" "WARN"
        }
    }
}

# Main execution
try {
    Write-Log "========================================" "INFO"
    Write-Log "Lambda Function Configuration Started" "INFO"
    Write-Log "========================================" "INFO"
    
    if ($DryRun) {
        Write-Log "DRY RUN MODE - No actual changes will be made" "WARN"
    }
    
    # Step 1: Check prerequisites
    Test-Prerequisites
    
    # Step 2: Create IAM role if requested
    if ($CreateRole) {
        New-LambdaIAMRole -RoleName $RoleName
    }
    
    # Step 3: Update Lambda function configuration if requested
    if ($UpdateFunction) {
        Update-LambdaConfiguration -FunctionName $FunctionName -RoleName $RoleName
        Set-CloudWatchLogGroup -FunctionName $FunctionName
    }
    
    # Step 4: Test connectivity if requested
    if ($TestConnectivity) {
        Test-BedrockConnectivity -FunctionName $FunctionName
    }
    
    # Step 5: Show summary
    Show-ConfigurationSummary -FunctionName $FunctionName -RoleName $RoleName
    
    Write-Log "========================================" "INFO"
    Write-Log "Configuration completed successfully!" "INFO"
    Write-Log "========================================" "INFO"
    
    if (!$CreateRole -and !$UpdateFunction -and !$TestConnectivity) {
        Write-Log "No actions specified. Use the following flags:" "INFO"
        Write-Log "  -CreateRole      Create IAM role with required permissions" "INFO"
        Write-Log "  -UpdateFunction  Update Lambda function configuration" "INFO"
        Write-Log "  -TestConnectivity Test AWS Bedrock connectivity" "INFO"
        Write-Log "  -DryRun          Show what would be done without making changes" "INFO"
        Write-Log "" "INFO"
        Write-Log "Example: .\configure-lambda-function.ps1 -CreateRole -UpdateFunction -TestConnectivity" "INFO"
    }
    
} catch {
    Write-Log "Configuration failed: $($_.Exception.Message)" "ERROR"
    exit 1
}