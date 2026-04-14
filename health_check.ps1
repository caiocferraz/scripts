# Service health check with retry logic
param(
    [string]$ServiceUrl = "http://localhost:8080/health",
    [int]$MaxRetries = 3,
    [int]$DelaySeconds = 5
)

for ($i = 1; $i -le $MaxRetries; $i++) {
    try {
        $response = Invoke-RestMethod -Uri $ServiceUrl -Method GET -TimeoutSec 10
        if ($response.status -eq "healthy") {
            Write-Host "Service is healthy!" -ForegroundColor Green
            exit 0
        }
    } catch {
        Write-Warning "Attempt $i/$MaxRetries failed: $_"
        if ($i -lt $MaxRetries) { Start-Sleep -Seconds $DelaySeconds }
    }
}

Write-Error "Service is not responding after $MaxRetries attempts."
exit 1
