@echo off
REM Batch script to configure certificate and proxy settings for corporate proxy (Windows)
REM Usage: scripts\setup-corporate-proxy.bat [proxy_url] [ca_cert_path] [disable_ssl] [test]
REM 
REM Arguments:
REM   proxy_url      : Proxy URL (e.g., http://proxy.company.com:8080)
REM   ca_cert_path   : Path to corporate CA certificate file
REM   disable_ssl    : Set to "true" to disable SSL verification
REM   test           : Set to "true" to test Docker connectivity

setlocal enabledelayedexpansion

echo [INFO] Corporate Proxy and Certificate Configuration Script
echo [INFO] =====================================================
echo.

set PROXY_URL=%1
set CA_CERT_PATH=%2
set DISABLE_SSL=%3
set TEST=%4

REM Get proxy URL if not provided
if "%PROXY_URL%"=="" (
    set /p PROXY_URL="Enter proxy URL (e.g., http://proxy.company.com:8080) or press Enter to skip: "
)

REM Configure proxy settings
if not "%PROXY_URL%"=="" (
    setx HTTP_PROXY "%PROXY_URL%" >nul 2>&1
    set HTTP_PROXY=%PROXY_URL%
    echo [INFO] Set HTTP_PROXY=%PROXY_URL%
    
    setx HTTPS_PROXY "%PROXY_URL%" >nul 2>&1
    set HTTPS_PROXY=%PROXY_URL%
    echo [INFO] Set HTTPS_PROXY=%PROXY_URL%
    
    setx http_proxy "%PROXY_URL%" >nul 2>&1
    set http_proxy=%PROXY_URL%
    
    setx https_proxy "%PROXY_URL%" >nul 2>&1
    set https_proxy=%PROXY_URL%
    
    setx NO_PROXY "localhost,127.0.0.1,.local" >nul 2>&1
    set NO_PROXY=localhost,127.0.0.1,.local
    echo [INFO] Set NO_PROXY=localhost,127.0.0.1,.local
)

REM Configure SSL certificate settings
if "%DISABLE_SSL%"=="true" (
    echo [WARN] Disabling SSL certificate verification (not recommended for production)
    setx REQUESTS_CA_BUNDLE "" >nul 2>&1
    set REQUESTS_CA_BUNDLE=
    echo [INFO] Set REQUESTS_CA_BUNDLE=
    
    setx CURL_CA_BUNDLE "" >nul 2>&1
    set CURL_CA_BUNDLE=
    echo [INFO] Set CURL_CA_BUNDLE=
    
    setx PYTHONHTTPSVERIFY "0" >nul 2>&1
    set PYTHONHTTPSVERIFY=0
) else if not "%CA_CERT_PATH%"=="" (
    if exist "%CA_CERT_PATH%" (
        echo [INFO] Using corporate CA certificate: %CA_CERT_PATH%
        setx REQUESTS_CA_BUNDLE "%CA_CERT_PATH%" >nul 2>&1
        set REQUESTS_CA_BUNDLE=%CA_CERT_PATH%
        echo [INFO] Set REQUESTS_CA_BUNDLE=%CA_CERT_PATH%
        
        setx CURL_CA_BUNDLE "%CA_CERT_PATH%" >nul 2>&1
        set CURL_CA_BUNDLE=%CA_CERT_PATH%
        echo [INFO] Set CURL_CA_BUNDLE=%CA_CERT_PATH%
    ) else (
        echo [ERROR] Certificate file not found: %CA_CERT_PATH%
        echo [WARN] Falling back to disabling SSL verification
        setx REQUESTS_CA_BUNDLE "" >nul 2>&1
        set REQUESTS_CA_BUNDLE=
        setx CURL_CA_BUNDLE "" >nul 2>&1
        set CURL_CA_BUNDLE=
    )
) else (
    REM Try common certificate locations
    set FOUND_CERT=false
    if exist "%USERPROFILE%\corporate-ca.crt" (
        set CA_CERT_PATH=%USERPROFILE%\corporate-ca.crt
        set FOUND_CERT=true
    ) else if exist "C:\corporate-ca.crt" (
        set CA_CERT_PATH=C:\corporate-ca.crt
        set FOUND_CERT=true
    )
    
    if "!FOUND_CERT!"=="true" (
        echo [INFO] Found certificate at: %CA_CERT_PATH%
        setx REQUESTS_CA_BUNDLE "%CA_CERT_PATH%" >nul 2>&1
        set REQUESTS_CA_BUNDLE=%CA_CERT_PATH%
        setx CURL_CA_BUNDLE "%CA_CERT_PATH%" >nul 2>&1
        set CURL_CA_BUNDLE=%CA_CERT_PATH%
    ) else (
        echo [WARN] No certificate file found. SSL verification may fail.
        echo [INFO] To disable SSL verification, use: setup-corporate-proxy.bat "" "" true
        echo [INFO] To specify certificate, use: setup-corporate-proxy.bat "" "C:\path\to\cert.crt"
    )
)

REM Docker-specific environment variables
setx DOCKER_BUILDKIT "1" >nul 2>&1
set DOCKER_BUILDKIT=1

echo.
echo [INFO] Configuration Summary:
echo   HTTP_PROXY: %HTTP_PROXY%
echo   HTTPS_PROXY: %HTTPS_PROXY%
echo   NO_PROXY: %NO_PROXY%
echo   REQUESTS_CA_BUNDLE: %REQUESTS_CA_BUNDLE%
echo   CURL_CA_BUNDLE: %CURL_CA_BUNDLE%
echo.

REM Test Docker connectivity if requested
if "%TEST%"=="true" (
    echo [INFO] Testing Docker connectivity...
    echo.
    
    where docker >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo [INFO] Testing Docker pull (hello-world)...
        docker pull hello-world >nul 2>&1
        if %ERRORLEVEL% EQU 0 (
            echo [INFO] ✓ Docker pull successful!
        ) else (
            echo [ERROR] ✗ Docker pull failed
        )
    ) else (
        echo [WARN] ⚠ Docker not found
    )
    
    echo.
    where docker-compose >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        for /f "tokens=*" %%i in ('docker-compose --version') do set COMPOSE_VERSION=%%i
        echo [INFO] ✓ Docker Compose available: %COMPOSE_VERSION%
    ) else (
        echo [WARN] ⚠ Docker Compose not found
    )
)

echo.
echo [INFO] Configuration complete!
echo.
echo [INFO] Next steps:
echo   1. Restart your terminal/command prompt for permanent changes to take effect
echo   2. Configure Docker Desktop proxy settings (Settings → Resources → Proxies)
echo   3. Run: docker-compose up -d --build
echo.
echo [WARN] Note: For Docker Desktop, also configure proxy in:
echo   Docker Desktop → Settings → Resources → Proxies
echo.

endlocal
