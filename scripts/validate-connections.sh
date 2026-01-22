#!/bin/bash

# Validation script for Airflow 3 with Spark Client
# This script validates that all services are running and accessible

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

print_info "Validating Airflow 3 Stack Connections..."
echo ""

# Check if services are running
print_info "Checking service status..."
docker-compose ps

echo ""

# Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Set defaults
AIRFLOW_POSTGRES_CONTAINER_NAME=${AIRFLOW_POSTGRES_CONTAINER_NAME:-airflow-postgres}
AIRFLOW_POSTGRES_USER=${AIRFLOW_POSTGRES_USER:-airflow}
AIRFLOW_POSTGRES_DB=${AIRFLOW_POSTGRES_DB:-airflow}
AIRFLOW_API_SERVER_CONTAINER_NAME=${AIRFLOW_API_SERVER_CONTAINER_NAME:-airflow-api-server}
AIRFLOW_WEB_PORT_CONTAINER=${AIRFLOW_WEB_PORT_CONTAINER:-8080}
SPARK_HOME=${SPARK_HOME:-/opt/spark}
NETWORK_NAME=${NETWORK_NAME:-bigdata-hadoop-network}

# Check PostgreSQL
print_info "Checking PostgreSQL connection..."
if docker-compose exec -T ${AIRFLOW_POSTGRES_CONTAINER_NAME} pg_isready -U ${AIRFLOW_POSTGRES_USER} -d ${AIRFLOW_POSTGRES_DB} > /dev/null 2>&1; then
    print_info "✓ PostgreSQL is accessible"
else
    print_error "✗ PostgreSQL is not accessible"
fi

# Check Airflow API Server
print_info "Checking Airflow API Server..."
if docker-compose exec -T ${AIRFLOW_API_SERVER_CONTAINER_NAME} curl -f http://localhost:${AIRFLOW_WEB_PORT_CONTAINER}/api/v2/monitor/health > /dev/null 2>&1; then
    print_info "✓ Airflow API Server is accessible"
else
    print_error "✗ Airflow API Server is not accessible"
fi

# Check Spark client
print_info "Checking Spark client installation..."
if docker-compose exec -T ${AIRFLOW_API_SERVER_CONTAINER_NAME} test -f ${SPARK_HOME}/bin/spark-submit; then
    print_info "✓ Spark client (spark-submit) is installed"
    # Check Spark version
    SPARK_VERSION_OUT=$(docker-compose exec -T ${AIRFLOW_API_SERVER_CONTAINER_NAME} ${SPARK_HOME}/bin/spark-submit --version 2>&1 | head -n 1 || echo "")
    if [ -n "$SPARK_VERSION_OUT" ]; then
        print_info "  $SPARK_VERSION_OUT"
    fi
else
    print_error "✗ Spark client (spark-submit) is not found"
fi

# Check network connectivity
print_info "Checking network connectivity..."
if docker network inspect ${NETWORK_NAME} > /dev/null 2>&1; then
    print_info "✓ Network '${NETWORK_NAME}' exists"
    
    # Check if we can resolve Spark master (if bigdata-stack-java8 is running)
    if docker-compose exec -T ${AIRFLOW_API_SERVER_CONTAINER_NAME} getent hosts spark-master > /dev/null 2>&1; then
        print_info "✓ Can resolve spark-master hostname"
    else
        print_warn "⚠ Cannot resolve spark-master (bigdata-stack-java8 may not be running)"
    fi
else
    print_warn "⚠ Network '${NETWORK_NAME}' does not exist"
    print_info "  Create it by running: docker network create ${NETWORK_NAME}"
    print_info "  Or start bigdata-stack-java8 first to create the network"
fi

echo ""
print_info "Validation complete!"

