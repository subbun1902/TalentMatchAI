# Test Lambda Image Deployment
param(
    [string]$FunctionName = "talentmatch-ai",
    [string]$ImageUri = "225989360749.dkr.ecr.us-east-1.amazonaws.com/ai_resume_anaylsis:latest",
    [string]$Region = "us-east-1"
)

Write-Host "Testing Lambda image deployment..." -ForegroundColor Green
Write-Host "Function: $FunctionName" -ForegroundColor Yellow
Write-Host "Image: $ImageUri" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow

# Check if function exists
Write-Host "`nChecking if Lambda function exists..." -ForegroundColor Cyan
$functionExists = $false
$functionConfig = aws lambda get-function --function-name $FunctionName --region $Region --output json 2>$null
if ($LASTEXITCODE -eq 0) {
    $functionExists = $true
    Write-Host "✓ Function exists" -ForegroundColor Green
} else {
    Write-Host "✗ Function does not exist" -ForegroundColor Red
    Write-Host "Creating new Lambda function..." -ForegroundColor Yellow
    
    # Create function
    $createResult = aws lambda create-function `
        --function-name $FunctionName `
        --package-type Image `
        --code ImageUri=$ImageUri `
        --role "arn:aws:iam::225989360749:role/talentmatch-lambda-role" `
        --timeout 300 `
        --memory-size 2048 `
        --region $Region `
        --output json 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Function created successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ Function creation failed: $createResult" -ForegroundColor Red
        exit 1
    }
}

if ($functionExists) {
    # Update existing function
    Write-Host "`nUpdating Lambda function code..." -ForegroundColor Cyan
    $updateResult = aws lambda update-function-code `
        --function-name $FunctionName `
        --image-uri $ImageUri `
        --region $Region `
        --output json 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Function code updated successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ Function update failed: $updateResult" -ForegroundColor Red
        
        # Check if it's the manifest format error
        if ($updateResult -match "media type.*not supported") {
            Write-Host "`n⚠️  Image format issue detected!" -ForegroundColor Yellow
            Write-Host "The image uses OCI format which may not be supported by Lambda." -ForegroundColor Yellow
            Write-Host "This is a known issue with newer Docker versions." -ForegroundColor Yellow
            exit 2
        } else {
            exit 1
        }
    }
}

# Wait for function to be ready
Write-Host "`nWaiting for function to be ready..." -ForegroundColor Cyan
$maxWait = 60
$waited = 0
do {
    Start-Sleep -Seconds 3
    $waited += 3
    $state = aws lambda get-function --function-name $FunctionName --region $Region --query "Configuration.State" --output text 2>$null
    Write-Host "Function state: $state (waited ${waited}s)" -ForegroundColor Gray
} while ($state -ne "Active" -and $waited -lt $maxWait)

if ($state -eq "Active") {
    Write-Host "✓ Function is ready" -ForegroundColor Green
} else {
    Write-Host "✗ Function did not become ready within timeout" -ForegroundColor Red
    exit 1
}

# Test function invocation
Write-Host "`nTesting function invocation..." -ForegroundColor Cyan
$testPayload = @{
    httpMethod = "GET"
    path = "/api/status"
    headers = @{}
    body = ""
} | ConvertTo-Json -Compress

$tempFile = [System.IO.Path]::GetTempFileName()
$invokeResult = aws lambda invoke `
    --function-name $FunctionName `
    --payload $testPayload `
    --region $Region `
    $tempFile 2>&1

if ($LASTEXITCODE -eq 0) {
    $response = Get-Content $tempFile -Raw
    Write-Host "✓ Function invocation successful" -ForegroundColor Green
    Write-Host "Response: $response" -ForegroundColor Gray
    
    # Check if response looks correct
    if ($response -match '"status"') {
        Write-Host "✓ Function is responding correctly" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Function response may be incorrect" -ForegroundColor Yellow
    }
} else {
    Write-Host "✗ Function invocation failed: $invokeResult" -ForegroundColor Red
    exit 1
}

Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

Write-Host "`n🎉 Lambda image test completed successfully!" -ForegroundColor Green