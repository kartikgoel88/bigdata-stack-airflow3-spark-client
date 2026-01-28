# Corporate Proxy and Certificate Configuration

Scripts to configure certificate and proxy settings for working behind a corporate proxy.

## Available Scripts

### Windows PowerShell: `setup-corporate-proxy.ps1`
For Windows PowerShell users.

### Windows CMD: `setup-corporate-proxy.bat`
For Windows Command Prompt users.

### Linux/Mac/WSL: `setup-corporate-proxy.sh`
For Linux, macOS, or WSL users.

## Quick Start

### Windows PowerShell

```powershell
# Basic usage - will prompt for proxy URL
.\scripts\setup-corporate-proxy.ps1

# With proxy URL
.\scripts\setup-corporate-proxy.ps1 -ProxyUrl "http://proxy.company.com:8080"

# Disable SSL verification (temporary workaround)
.\scripts\setup-corporate-proxy.ps1 -ProxyUrl "http://proxy.company.com:8080" -DisableSSLVerification

# Use corporate CA certificate
.\scripts\setup-corporate-proxy.ps1 -ProxyUrl "http://proxy.company.com:8080" -CaCertPath "C:\corporate-ca.crt"

# Set permanently (requires admin or user permissions)
.\scripts\setup-corporate-proxy.ps1 -ProxyUrl "http://proxy.company.com:8080" -Permanent

# Test Docker connectivity after configuration
.\scripts\setup-corporate-proxy.ps1 -ProxyUrl "http://proxy.company.com:8080" -Test
```

### Windows CMD

```cmd
REM Basic usage
scripts\setup-corporate-proxy.bat

REM With proxy URL
scripts\setup-corporate-proxy.bat "http://proxy.company.com:8080"

REM Disable SSL verification
scripts\setup-corporate-proxy.bat "http://proxy.company.com:8080" "" true

REM With certificate path
scripts\setup-corporate-proxy.bat "http://proxy.company.com:8080" "C:\corporate-ca.crt"

REM Test Docker connectivity
scripts\setup-corporate-proxy.bat "http://proxy.company.com:8080" "" false true
```

### Linux/Mac/WSL

```bash
# Basic usage
./scripts/setup-corporate-proxy.sh

# With proxy URL
./scripts/setup-corporate-proxy.sh --proxy-url "http://proxy.company.com:8080"

# Disable SSL verification
./scripts/setup-corporate-proxy.sh --proxy-url "http://proxy.company.com:8080" --disable-ssl-verification

# Use corporate CA certificate
./scripts/setup-corporate-proxy.sh --proxy-url "http://proxy.company.com:8080" --ca-cert-path "/path/to/corporate-ca.crt"

# Set permanently (adds to ~/.bashrc or ~/.zshrc)
./scripts/setup-corporate-proxy.sh --proxy-url "http://proxy.company.com:8080" --permanent

# Test Docker connectivity
./scripts/setup-corporate-proxy.sh --proxy-url "http://proxy.company.com:8080" --test
```

## Getting Your Corporate CA Certificate

### Method 1: Export from Browser (Easiest)

1. Open Chrome/Edge/Firefox
2. Visit any HTTPS site through your corporate proxy
3. Click the lock icon in the address bar
4. Click "Certificate" or "Connection is secure" → "Certificate"
5. Go to "Details" tab
6. Click "Copy to File" → Next → "Base-64 encoded X.509 (.CER)"
7. Save as `corporate-ca.crt`

### Method 2: Windows Certificate Store (PowerShell)

```powershell
# Export all trusted root certificates
Get-ChildItem -Path Cert:\LocalMachine\Root | Export-Certificate -FilePath C:\corporate-ca.crt

# Or export specific company certificate
Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object {$_.Subject -like "*YourCompany*"} | Export-Certificate -FilePath C:\corporate-ca.crt
```

### Method 3: Windows Certificate Manager (GUI)

1. Press `Win + R`, type `certmgr.msc`, press Enter
2. Navigate to **Trusted Root Certification Authorities** → **Certificates**
3. Find your corporate CA certificate
4. Right-click → **All Tasks** → **Export**
5. Choose **Base-64 encoded X.509 (.CER)** format
6. Save to `C:\corporate-ca.crt`

## Configuration Options

### Environment Variables Set

The scripts configure the following environment variables:

- `HTTP_PROXY` / `http_proxy` - HTTP proxy URL
- `HTTPS_PROXY` / `https_proxy` - HTTPS proxy URL  
- `NO_PROXY` / `no_proxy` - Comma-separated list of hosts to bypass proxy
- `REQUESTS_CA_BUNDLE` - Path to CA certificate bundle for Python requests
- `CURL_CA_BUNDLE` - Path to CA certificate bundle for curl
- `SSL_CERT_FILE` - Path to SSL certificate file
- `DOCKER_BUILDKIT` - Enable Docker BuildKit

### Permanent vs Session-Only

- **Session-only**: Variables are set for the current terminal session only
- **Permanent**: Variables are added to your shell profile (`.bashrc`, `.zshrc`) or Windows registry

**Note**: For permanent Windows changes, you may need to restart your terminal or command prompt.

## Docker Desktop Configuration

After running the script, also configure Docker Desktop:

1. Open **Docker Desktop**
2. Go to **Settings** → **Resources** → **Proxies**
3. Enable **Manual proxy configuration**
4. Enter:
   - **Web Server (HTTP)**: `http://proxy.company.com:8080`
   - **Secure Web Server (HTTPS)**: `http://proxy.company.com:8080`
   - **Bypass**: `localhost,127.0.0.1`
5. Click **Apply & Restart**

## Troubleshooting

### Certificate Verification Failed

**Option 1**: Use your corporate CA certificate
```powershell
.\scripts\setup-corporate-proxy.ps1 -CaCertPath "C:\corporate-ca.crt"
```

**Option 2**: Temporarily disable SSL verification (not recommended for production)
```powershell
.\scripts\setup-corporate-proxy.ps1 -DisableSSLVerification
```

### Docker Pull Fails

1. Verify proxy settings in Docker Desktop (Settings → Resources → Proxies)
2. Check if proxy requires authentication:
   ```powershell
   # If proxy requires auth, use format:
   http://username:password@proxy.company.com:8080
   ```
3. Test connectivity:
   ```powershell
   docker pull hello-world
   ```

### Environment Variables Not Persisting

- **Windows**: Restart your terminal/command prompt after using `setx`
- **Linux/Mac**: Run `source ~/.bashrc` (or `source ~/.zshrc`) after using `--permanent`

### Script Execution Policy (PowerShell)

If you get an execution policy error:

```powershell
# Allow script execution for current session
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Or run script directly
powershell -ExecutionPolicy Bypass -File .\scripts\setup-corporate-proxy.ps1
```

## Examples

### Example 1: Quick Setup with Proxy Only

```powershell
.\scripts\setup-corporate-proxy.ps1 -ProxyUrl "http://proxy.company.com:8080" -DisableSSLVerification -Test
```

### Example 2: Production Setup with Certificate

```powershell
.\scripts\setup-corporate-proxy.ps1 -ProxyUrl "http://proxy.company.com:8080" -CaCertPath "C:\corporate-ca.crt" -Permanent
```

### Example 3: Linux/WSL Setup

```bash
./scripts/setup-corporate-proxy.sh --proxy-url "http://proxy.company.com:8080" --ca-cert-path "$HOME/corporate-ca.crt" --permanent --test
source ~/.bashrc  # or source ~/.zshrc
```

## Next Steps

After running the script:

1. **Restart your terminal** (if you used permanent settings)
2. **Configure Docker Desktop** proxy settings (if on Windows)
3. **Test Docker connectivity**:
   ```bash
   docker pull hello-world
   docker-compose --version
   ```
4. **Build and start your stack**:
   ```bash
   docker-compose up -d --build
   ```

## Security Notes

⚠️ **Warning**: Disabling SSL verification (`--disable-ssl-verification` or `-DisableSSLVerification`) is a security risk and should only be used temporarily for troubleshooting. Always use your corporate CA certificate in production environments.

## Support

If you continue to experience issues:

1. Check your corporate proxy documentation
2. Verify proxy URL and port are correct
3. Ensure proxy doesn't require authentication
4. Check firewall rules
5. Contact your IT department for proxy configuration details
