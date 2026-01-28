# PowerShell script to configure certificate and proxy settings for corporate proxy
# Usage: .\scripts\setup-corporate-proxy.ps1 [options]
# Options:
#   -ProxyUrl <url>          : Set proxy URL (e.g., http://proxy.company.com:8080)
#   -CaCertPath <path>       : Path to corporate CA certificate file
#   -DisableSSLVerification  : Disable SSL certificate verification (not recommended)
#   -Permanent               : Set environment variables permanently (requires admin)
#   -Test                    : Test Docker connectivity after configuration

param(
    [string]$ProxyUrl = "",
    [string]$CaCertPath = "",
    [switch]$DisableSSLVerification = $false,
    [switch]$Permanent = $false,
    [switch]$Test = $false
)

# Colors for output
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

Write-Info "Corporate Proxy and Certificate Configuration Script"
Write-Info "====================================================="
Write-Host ""

# Get current proxy settings from system if not provided
if ([string]::IsNullOrEmpty($ProxyUrl)) {
    $systemProxy = [System.Net.WebRequest]::GetSystemWebProxy()
    if ($systemProxy -and $systemProxy.IsBypassed("http://www.google.com") -eq $false) {
        $proxyUri = $systemProxy.GetProxy("http://www.google.com")
        if ($proxyUri -ne "http://www.google.com") {
            $ProxyUrl = $proxyUri.ToString()
            Write-Info "Detected system proxy: $ProxyUrl"
        }
    }
    
    if ([string]::IsNullOrEmpty($ProxyUrl)) {
        $ProxyUrl = Read-Host "Enter proxy URL (e.g., http://proxy.company.com:8080) or press Enter to skip"
    }
}

# Function to set environment variable
function Set-EnvVar {
    param(
        [string]$Name,
        [string]$Value,
        [bool]$Permanent = $false
    )
    
    if ($Permanent) {
        # Set permanently in registry
        try {
            [System.Environment]::SetEnvironmentVariable($Name, $Value, [System.EnvironmentVariableTarget]::User)
            Write-Info "Set permanent environment variable: $Name = $Value"
        } catch {
            Write-Warn "Failed to set permanent environment variable. Run as Administrator or set manually."
            Write-Info "Setting for current session only: $Name = $Value"
            [System.Environment]::SetEnvironmentVariable($Name, $Value, [System.EnvironmentVariableTarget]::Process)
        }
    } else {
        # Set for current session only
        [System.Environment]::SetEnvironmentVariable($Name, $Value, [System.EnvironmentVariableTarget]::Process)
        Set-Item -Path "env:$Name" -Value $Value
        Write-Info "Set environment variable (current session): $Name = $Value"
    }
}

# Configure proxy settings
if (-not [string]::IsNullOrEmpty($ProxyUrl)) {
    Set-EnvVar -Name "HTTP_PROXY" -Value $ProxyUrl -Permanent $Permanent
    Set-EnvVar -Name "HTTPS_PROXY" -Value $ProxyUrl -Permanent $Permanent
    Set-EnvVar -Name "http_proxy" -Value $ProxyUrl -Permanent $Permanent
    Set-EnvVar -Name "https_proxy" -Value $ProxyUrl -Permanent $Permanent
    
    # Set NO_PROXY
    $noProxy = "localhost,127.0.0.1,.local"
    Set-EnvVar -Name "NO_PROXY" -Value $noProxy -Permanent $Permanent
    Set-EnvVar -Name "no_proxy" -Value $noProxy -Permanent $Permanent
}

# Configure SSL certificate settings
if ($DisableSSLVerification) {
    Write-Warn "Disabling SSL certificate verification (not recommended for production)"
    Set-EnvVar -Name "REQUESTS_CA_BUNDLE" -Value "" -Permanent $Permanent
    Set-EnvVar -Name "CURL_CA_BUNDLE" -Value "" -Permanent $Permanent
    Set-EnvVar -Name "SSL_CERT_FILE" -Value "" -Permanent $Permanent
    Set-EnvVar -Name "REQUESTS_VERIFY" -Value "false" -Permanent $Permanent
    Set-EnvVar -Name "PYTHONHTTPSVERIFY" -Value "0" -Permanent $Permanent
} elseif (-not [string]::IsNullOrEmpty($CaCertPath)) {
    if (Test-Path $CaCertPath) {
        Write-Info "Using corporate CA certificate: $CaCertPath"
        Set-EnvVar -Name "REQUESTS_CA_BUNDLE" -Value $CaCertPath -Permanent $Permanent
        Set-EnvVar -Name "CURL_CA_BUNDLE" -Value $CaCertPath -Permanent $Permanent
        Set-EnvVar -Name "SSL_CERT_FILE" -Value $CaCertPath -Permanent $Permanent
    } else {
        Write-Error "Certificate file not found: $CaCertPath"
        Write-Warn "Falling back to disabling SSL verification"
        Set-EnvVar -Name "REQUESTS_CA_BUNDLE" -Value "" -Permanent $Permanent
        Set-EnvVar -Name "CURL_CA_BUNDLE" -Value "" -Permanent $Permanent
    }
} else {
    # Try to find certificate in common locations
    $certPaths = @(
        "$env:USERPROFILE\corporate-ca.crt",
        "C:\corporate-ca.crt",
        "$env:ProgramData\corporate-ca.crt"
    )
    
    $foundCert = $false
    foreach ($path in $certPaths) {
        if (Test-Path $path) {
            Write-Info "Found certificate at: $path"
            Set-EnvVar -Name "REQUESTS_CA_BUNDLE" -Value $path -Permanent $Permanent
            Set-EnvVar -Name "CURL_CA_BUNDLE" -Value $path -Permanent $Permanent
            Set-EnvVar -Name "SSL_CERT_FILE" -Value $path -Permanent $Permanent
            $foundCert = $true
            break
        }
    }
    
    if (-not $foundCert) {
        Write-Warn "No certificate file found. SSL verification may fail."
        Write-Info "To disable SSL verification, use: -DisableSSLVerification"
        Write-Info "To specify certificate, use: -CaCertPath <path>"
    }
}

# Docker-specific environment variables
Set-EnvVar -Name "DOCKER_BUILDKIT" -Value "1" -Permanent $Permanent

Write-Host ""
Write-Info "Configuration Summary:"
Write-Host "  HTTP_PROXY: $env:HTTP_PROXY"
Write-Host "  HTTPS_PROXY: $env:HTTPS_PROXY"
Write-Host "  NO_PROXY: $env:NO_PROXY"
Write-Host "  REQUESTS_CA_BUNDLE: $env:REQUESTS_CA_BUNDLE"
Write-Host "  CURL_CA_BUNDLE: $env:CURL_CA_BUNDLE"
Write-Host ""

# Test Docker connectivity if requested
if ($Test) {
    Write-Info "Testing Docker connectivity..."
    Write-Host ""
    
    try {
        Write-Info "Testing Docker pull (hello-world)..."
        docker pull hello-world 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Info "✓ Docker pull successful!"
        } else {
            Write-Error "✗ Docker pull failed"
        }
    } catch {
        Write-Error "✗ Docker test failed: $_"
    }
    
    Write-Host ""
    Write-Info "Testing Docker Compose..."
    try {
        $composeVersion = docker-compose --version
        Write-Info "✓ Docker Compose available: $composeVersion"
    } catch {
        Write-Warn "⚠ Docker Compose not found or not working"
    }
}

Write-Host ""
Write-Info "Configuration complete!"
Write-Host ""
Write-Info "Next steps:"
Write-Host "  1. If you set permanent variables, restart your terminal/PowerShell"
Write-Host "  2. Configure Docker Desktop proxy settings (Settings → Resources → Proxies)"
Write-Host "  3. Run: docker-compose up -d --build"
Write-Host ""
Write-Warn "Note: For Docker Desktop, also configure proxy in:"
Write-Warn "  Docker Desktop → Settings → Resources → Proxies"
