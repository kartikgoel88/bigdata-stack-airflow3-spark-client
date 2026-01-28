#!/bin/bash

# Bash script to configure certificate and proxy settings for corporate proxy
# Usage: ./scripts/setup-corporate-proxy.sh [options]
# Options:
#   --proxy-url <url>          : Set proxy URL (e.g., http://proxy.company.com:8080)
#   --ca-cert-path <path>      : Path to corporate CA certificate file
#   --disable-ssl-verification : Disable SSL certificate verification (not recommended)
#   --permanent                : Add to shell profile (~/.bashrc or ~/.zshrc)
#   --test                     : Test Docker connectivity after configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info "Corporate Proxy and Certificate Configuration Script"
print_info "====================================================="
echo ""

# Default values
PROXY_URL=""
CA_CERT_PATH=""
DISABLE_SSL=false
PERMANENT=false
TEST=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --proxy-url)
            PROXY_URL="$2"
            shift 2
            ;;
        --ca-cert-path)
            CA_CERT_PATH="$2"
            shift 2
            ;;
        --disable-ssl-verification)
            DISABLE_SSL=true
            shift
            ;;
        --permanent)
            PERMANENT=true
            shift
            ;;
        --test)
            TEST=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Usage: $0 [--proxy-url <url>] [--ca-cert-path <path>] [--disable-ssl-verification] [--permanent] [--test]"
            exit 1
            ;;
    esac
done

# Function to set environment variable
set_env_var() {
    local name=$1
    local value=$2
    local permanent=$3
    
    export $name="$value"
    print_info "Set environment variable: $name = $value"
    
    if [ "$permanent" = true ]; then
        # Detect shell
        if [ -n "$ZSH_VERSION" ]; then
            SHELL_PROFILE="$HOME/.zshrc"
        elif [ -n "$BASH_VERSION" ]; then
            SHELL_PROFILE="$HOME/.bashrc"
        else
            SHELL_PROFILE="$HOME/.profile"
        fi
        
        # Check if already exists
        if ! grep -q "export $name=" "$SHELL_PROFILE" 2>/dev/null; then
            echo "export $name=\"$value\"" >> "$SHELL_PROFILE"
            print_info "Added to $SHELL_PROFILE"
        else
            print_warn "Variable $name already exists in $SHELL_PROFILE"
        fi
    fi
}

# Get proxy URL if not provided
if [ -z "$PROXY_URL" ]; then
    # Try to detect from system
    if command -v git &> /dev/null; then
        GIT_PROXY=$(git config --global --get http.proxy 2>/dev/null || echo "")
        if [ -n "$GIT_PROXY" ]; then
            PROXY_URL="$GIT_PROXY"
            print_info "Detected Git proxy: $PROXY_URL"
        fi
    fi
    
    if [ -z "$PROXY_URL" ]; then
        read -p "Enter proxy URL (e.g., http://proxy.company.com:8080) or press Enter to skip: " PROXY_URL
    fi
fi

# Configure proxy settings
if [ -n "$PROXY_URL" ]; then
    set_env_var "HTTP_PROXY" "$PROXY_URL" "$PERMANENT"
    set_env_var "HTTPS_PROXY" "$PROXY_URL" "$PERMANENT"
    set_env_var "http_proxy" "$PROXY_URL" "$PERMANENT"
    set_env_var "https_proxy" "$PROXY_URL" "$PERMANENT"
    
    # Set NO_PROXY
    NO_PROXY_VAL="localhost,127.0.0.1,.local"
    set_env_var "NO_PROXY" "$NO_PROXY_VAL" "$PERMANENT"
    set_env_var "no_proxy" "$NO_PROXY_VAL" "$PERMANENT"
fi

# Configure SSL certificate settings
if [ "$DISABLE_SSL" = true ]; then
    print_warn "Disabling SSL certificate verification (not recommended for production)"
    set_env_var "REQUESTS_CA_BUNDLE" "" "$PERMANENT"
    set_env_var "CURL_CA_BUNDLE" "" "$PERMANENT"
    set_env_var "SSL_CERT_FILE" "" "$PERMANENT"
    set_env_var "REQUESTS_VERIFY" "false" "$PERMANENT"
    set_env_var "PYTHONHTTPSVERIFY" "0" "$PERMANENT"
elif [ -n "$CA_CERT_PATH" ]; then
    if [ -f "$CA_CERT_PATH" ]; then
        print_info "Using corporate CA certificate: $CA_CERT_PATH"
        set_env_var "REQUESTS_CA_BUNDLE" "$CA_CERT_PATH" "$PERMANENT"
        set_env_var "CURL_CA_BUNDLE" "$CA_CERT_PATH" "$PERMANENT"
        set_env_var "SSL_CERT_FILE" "$CA_CERT_PATH" "$PERMANENT"
    else
        print_error "Certificate file not found: $CA_CERT_PATH"
        print_warn "Falling back to disabling SSL verification"
        set_env_var "REQUESTS_CA_BUNDLE" "" "$PERMANENT"
        set_env_var "CURL_CA_BUNDLE" "" "$PERMANENT"
    fi
else
    # Try to find certificate in common locations
    CERT_PATHS=(
        "$HOME/corporate-ca.crt"
        "/etc/ssl/certs/ca-certificates.crt"
        "/usr/local/share/ca-certificates/corporate-ca.crt"
    )
    
    FOUND_CERT=false
    for path in "${CERT_PATHS[@]}"; do
        if [ -f "$path" ]; then
            print_info "Found certificate at: $path"
            set_env_var "REQUESTS_CA_BUNDLE" "$path" "$PERMANENT"
            set_env_var "CURL_CA_BUNDLE" "$path" "$PERMANENT"
            set_env_var "SSL_CERT_FILE" "$path" "$PERMANENT"
            FOUND_CERT=true
            break
        fi
    done
    
    if [ "$FOUND_CERT" = false ]; then
        print_warn "No certificate file found. SSL verification may fail."
        print_info "To disable SSL verification, use: --disable-ssl-verification"
        print_info "To specify certificate, use: --ca-cert-path <path>"
    fi
fi

# Docker-specific environment variables
set_env_var "DOCKER_BUILDKIT" "1" "$PERMANENT"

echo ""
print_info "Configuration Summary:"
echo "  HTTP_PROXY: $HTTP_PROXY"
echo "  HTTPS_PROXY: $HTTPS_PROXY"
echo "  NO_PROXY: $NO_PROXY"
echo "  REQUESTS_CA_BUNDLE: $REQUESTS_CA_BUNDLE"
echo "  CURL_CA_BUNDLE: $CURL_CA_BUNDLE"
echo ""

# Test Docker connectivity if requested
if [ "$TEST" = true ]; then
    print_info "Testing Docker connectivity..."
    echo ""
    
    if command -v docker &> /dev/null; then
        print_info "Testing Docker pull (hello-world)..."
        if docker pull hello-world > /dev/null 2>&1; then
            print_info "✓ Docker pull successful!"
        else
            print_error "✗ Docker pull failed"
        fi
    else
        print_warn "⚠ Docker not found"
    fi
    
    echo ""
    if command -v docker-compose &> /dev/null; then
        COMPOSE_VERSION=$(docker-compose --version)
        print_info "✓ Docker Compose available: $COMPOSE_VERSION"
    else
        print_warn "⚠ Docker Compose not found"
    fi
fi

echo ""
print_info "Configuration complete!"
echo ""
print_info "Next steps:"
echo "  1. If you used --permanent, run: source ~/.bashrc (or ~/.zshrc)"
echo "  2. Configure Docker daemon proxy if needed"
echo "  3. Run: docker-compose up -d --build"
echo ""
