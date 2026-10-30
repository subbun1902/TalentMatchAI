# Lambda Deployment Monitoring Script
param(
    [string]$FunctionName = "talentmatch-ai",
    [int]$MonitorDurationMinutes = 10,
    [int]$CheckIntervalSeconds = 30,
    [switch]$ContinuousMode,
    [switch]$AlertOnErrors
)

$ErrorActionPreference = "Stop"

# Initialize variables
$MonitorLog = "logs/monitor_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$StartTime = Get-Date
$ErrorCount = 0
$SuccessCount = 0
$LastKnownState = $null

# Ensure logs directory exists
if (!(Test-Path "logs")) {
    New-Item -ItemType Directory -Path "logs" -Force | Out-Null
}

# Logging function
function Write-MonitorLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Color coding for console output
    switch ($Level) {
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "WARN" { Write-Host $logEntry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        default { Write-Host $logEntry }
    }
    
    Add-Content -Path $MonitorLog -Value $logEntry
}

# Function to get Lambda metrics
function Get-LambdaMetrics {
    try {
        $config = aws lambda get-function-configuration --function-name $FunctionName --output json 2>$null | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to get function configuration"
        }
        
        return @{
            State = $config.State
            LastUpdateStatus = $config.LastUpdateStatus
            LastModified = $config.LastModified
            CodeSize = $config.CodeSize
            Timeout = $config.Timeout
            MemorySize = $config.MemorySize
            Version = $config.Version
        }
    }
    catch {
        Write-MonitorLog "Failed to retrieve Lambda metrics: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

# Function to test Lambda health
function Test-LambdaHealth {
    try {
        $payload = @{
            httpMethod = "GET"
            path = "/api/status"
            headers = @{}
            body = ""
        } | ConvertTo-Json -Compress
        
        $tempFile = [System.IO.Path]::GetTempFileName()
        $result = aws lambda invoke --function-name $FunctionName --payload $payload $tempFile 2>$null
        
        if ($LASTEXITCODE -ne 0) {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            return $false
        }
        
        $response = Get-Content $tempFile -Raw
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        
        # Check if response contains expected status
        return $response -match '"status"'
    }
    catch {
        Write-MonitorLog "Health check failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Function to get CloudWatch metrics
function Get-CloudWatchMetrics {
    try {
        $endTime = Get-Date
        $startTime = $endTime.AddMinutes(-5)
        
        $startTimeStr = $startTime.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        $endTimeStr = $endTime.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        
        # Get invocation count
        $invocations = aws cloudwatch get-metric-statistics --namespace "AWS/Lambda" --metric-name "Invocations" --dimensions Name=FunctionName,Value=$FunctionName --start-time $startTimeStr --end-time $endTimeStr --period 300 --statistics Sum --output json 2>$null
        
        # Get error count
        $errors = aws cloudwatch get-metric-statistics --namespace "AWS/Lambda" --metric-name "Errors" --dimensions Name=FunctionName,Value=$FunctionName --start-time $startTimeStr --end-time $endTimeStr --period 300 --statistics Sum --output json 2>$null
        
        # Get duration
        $duration = aws cloudwatch get-metric-statistics --namespace "AWS/Lambda" --metric-name "Duration" --dimensions Name=FunctionName,Value=$FunctionName --start-time $startTimeStr --end-time $endTimeStr --period 300 --statistics Average --output json 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            $invocationData = $invocations | ConvertFrom-Json
            $errorData = $errors | ConvertFrom-Json
            $durationData = $duration | ConvertFrom-Json
            
            return @{
                Invocations = if ($invocationData.Datapoints.Count -gt 0) { ($invocationData.Datapoints | Measure-Object -Property Sum -Sum).Sum } else { 0 }
                Errors = if ($errorData.Datapoints.Count -gt 0) { ($errorData.Datapoints | Measure-Object -Property Sum -Sum).Sum } else { 0 }
                AvgDuration = if ($durationData.Datapoints.Count -gt 0) { [math]::Round(($durationData.Datapoints | Measure-Object -Property Average -Average).Average, 2) } else { 0 }
            }
        }
        
        return $null
    }
    catch {
        Write-MonitorLog "Failed to retrieve CloudWatch metrics: $($_.Exception.Message)" "WARN"
        return $null
    }
}

# Main monitoring loop
try {
    Write-MonitorLog "========================================" "INFO"
    Write-MonitorLog "Lambda Deployment Monitoring Started" "INFO"
    Write-MonitorLog "========================================" "INFO"
    Write-MonitorLog "Function: $FunctionName" "INFO"
    Write-MonitorLog "Monitor Duration: $MonitorDurationMinutes minutes" "INFO"
    Write-MonitorLog "Check Interval: $CheckIntervalSeconds seconds" "INFO"
    Write-MonitorLog "Continuous Mode: $ContinuousMode" "INFO"
    Write-MonitorLog "Alert on Errors: $AlertOnErrors" "INFO"
    Write-MonitorLog "========================================" "INFO"
    
    $monitorCount = 0
    
    do {
        $monitorCount++
        $currentTime = Get-Date
        $elapsed = $currentTime - $StartTime
        
        Write-MonitorLog "Monitor Check #$monitorCount (Elapsed: $($elapsed.ToString('mm\:ss')))" "INFO"
        
        # Get Lambda metrics
        $metrics = Get-LambdaMetrics
        if ($metrics) {
            Write-MonitorLog "Function State: $($metrics.State)" "INFO"
            Write-MonitorLog "Update Status: $($metrics.LastUpdateStatus)" "INFO"
            Write-MonitorLog "Memory: $($metrics.MemorySize)MB, Timeout: $($metrics.Timeout)s" "INFO"
            
            # Check for state changes
            if ($LastKnownState -and $LastKnownState -ne $metrics.State) {
                Write-MonitorLog "State changed from $LastKnownState to $($metrics.State)" "WARN"
            }
            $LastKnownState = $metrics.State
            
            # Alert on problematic states
            if ($metrics.State -eq "Failed" -or $metrics.LastUpdateStatus -eq "Failed") {
                Write-MonitorLog "ALERT: Function is in failed state!" "ERROR"
                $ErrorCount++
                
                if ($AlertOnErrors) {
                    Write-MonitorLog "Error alert triggered - consider manual intervention" "ERROR"
                }
            }
        }
        
        # Perform health check
        Write-MonitorLog "Performing health check..." "INFO"
        $healthCheck = Test-LambdaHealth
        if ($healthCheck) {
            Write-MonitorLog "Health check: PASSED ✓" "SUCCESS"
            $SuccessCount++
        } else {
            Write-MonitorLog "Health check: FAILED ✗" "ERROR"
            $ErrorCount++
        }
        
        # Get CloudWatch metrics
        Write-MonitorLog "Retrieving CloudWatch metrics..." "INFO"
        $cwMetrics = Get-CloudWatchMetrics
        if ($cwMetrics) {
            Write-MonitorLog "Recent metrics - Invocations: $($cwMetrics.Invocations), Errors: $($cwMetrics.Errors), Avg Duration: $($cwMetrics.AvgDuration)ms" "INFO"
            
            if ($cwMetrics.Errors -gt 0) {
                Write-MonitorLog "ALERT: $($cwMetrics.Errors) errors detected in recent metrics!" "ERROR"
            }
        }
        
        Write-MonitorLog "----------------------------------------" "INFO"
        
        # Check if we should continue monitoring
        if (!$ContinuousMode) {
            $shouldContinue = $elapsed.TotalMinutes -lt $MonitorDurationMinutes
        } else {
            $shouldContinue = $true
        }
        
        if ($shouldContinue) {
            Start-Sleep -Seconds $CheckIntervalSeconds
        }
        
    } while ($shouldContinue)
    
    # Final summary
    Write-MonitorLog "========================================" "INFO"
    Write-MonitorLog "Monitoring Summary" "INFO"
    Write-MonitorLog "========================================" "INFO"
    Write-MonitorLog "Total Checks: $monitorCount" "INFO"
    Write-MonitorLog "Successful Health Checks: $SuccessCount" "SUCCESS"
    Write-MonitorLog "Failed Health Checks: $ErrorCount" "ERROR"
    Write-MonitorLog "Success Rate: $([math]::Round(($SuccessCount / $monitorCount) * 100, 1))%" "INFO"
    Write-MonitorLog "Final Function State: $LastKnownState" "INFO"
    Write-MonitorLog "Total Monitoring Time: $($elapsed.ToString('hh\:mm\:ss'))" "INFO"
    Write-MonitorLog "Log File: $MonitorLog" "INFO"
    Write-MonitorLog "========================================" "INFO"
    
    if ($ErrorCount -eq 0) {
        Write-MonitorLog "Monitoring completed successfully - no errors detected" "SUCCESS"
        exit 0
    } else {
        Write-MonitorLog "Monitoring completed with $ErrorCount errors detected" "WARN"
        exit 1
    }
}
catch {
    Write-MonitorLog "Monitoring failed with exception: $($_.Exception.Message)" "ERROR"
    Write-MonitorLog "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    exit 1
}
finally {
    Write-MonitorLog "Monitoring session ended at $(Get-Date)" "INFO"
}