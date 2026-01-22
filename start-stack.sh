#!/bin/bash

# Big Data Stack Airflow 3 - Startup Script
# This script brings down containers, rebuilds images, and starts all services

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load environment variables from .env if it exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

echo "=========================================="
echo "Big Data Stack Airflow 3 - Startup Script"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if .env file exists
if [ ! -f .env ]; then
    print_warn ".env file not found. Creating from env.example..."
    cp env.example .env
    print_info "Please review and update .env file if needed"
fi

# Load environment variables from .env
export $(grep -v '^#' .env | xargs)

# Step 1: Stop and remove containers
print_info "Step 1: Stopping and removing existing containers..."
docker-compose down -v
if [ $? -eq 0 ]; then
    print_info "Containers stopped and removed successfully"
else
    print_warn "Some containers may not have been running"
fi

echo ""

# Step 2: Check if Spark tarball exists
print_info "Step 2: Checking for Spark tarball..."
SPARK_VERSION=${SPARK_VERSION:-3.5.8}
if [ ! -f "downloads/spark-${SPARK_VERSION}-bin-hadoop3.tar.gz" ]; then
    print_warn "Spark tarball not found in downloads/"
    print_info "Please download Spark ${SPARK_VERSION}:"
    print_info "  mkdir -p downloads"
    print_info "  cd downloads"
    print_info "  wget https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz"
    print_info "  mv spark-${SPARK_VERSION}-bin-hadoop3.tgz spark-${SPARK_VERSION}-bin-hadoop3.tar.gz"
    print_error "Cannot proceed without Spark tarball"
    exit 1
else
    print_info "Spark tarball found (version ${SPARK_VERSION})"
fi

echo ""

# Step 3: Build Airflow image
print_info "Step 3: Building Airflow image with Spark client..."
docker-compose build --no-cache airflow-image
if [ $? -eq 0 ]; then
    print_info "Airflow image built successfully"
else
    print_error "Failed to build Airflow image"
    exit 1
fi

echo ""

# Step 4: Start all services
print_info "Step 4: Starting all services..."
docker-compose up -d
if [ $? -eq 0 ]; then
    print_info "Services started successfully"
else
    print_error "Failed to start services"
    exit 1
fi

echo ""

# Step 5: Wait for services to be ready
print_info "Step 5: Waiting for services to be ready..."
print_info "This may take 30-60 seconds..."

# Wait for PostgreSQL
print_info "Waiting for PostgreSQL..."
AIRFLOW_POSTGRES_USER=${AIRFLOW_POSTGRES_USER:-airflow}
AIRFLOW_POSTGRES_DB=${AIRFLOW_POSTGRES_DB:-airflow}
AIRFLOW_POSTGRES_CONTAINER_NAME=${AIRFLOW_POSTGRES_CONTAINER_NAME:-airflow-postgres}
for i in {1..30}; do
    if docker-compose exec -T ${AIRFLOW_POSTGRES_CONTAINER_NAME} pg_isready -U ${AIRFLOW_POSTGRES_USER} -d ${AIRFLOW_POSTGRES_DB} > /dev/null 2>&1; then
        print_info "PostgreSQL is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        print_warn "PostgreSQL may not be ready yet"
    else
        echo -n "."
        sleep 2
    fi
done
echo ""

# Wait for Airflow API Server
print_info "Waiting for Airflow API Server..."
AIRFLOW_API_SERVER_CONTAINER_NAME=${AIRFLOW_API_SERVER_CONTAINER_NAME:-airflow-api-server}
AIRFLOW_WEB_PORT_CONTAINER=${AIRFLOW_WEB_PORT_CONTAINER:-8080}
for i in {1..60}; do
    if docker-compose exec -T ${AIRFLOW_API_SERVER_CONTAINER_NAME} curl -f http://localhost:${AIRFLOW_WEB_PORT_CONTAINER}/api/v2/monitor/health > /dev/null 2>&1; then
        print_info "Airflow API Server is ready"
        break
    fi
    if [ $i -eq 60 ]; then
        print_warn "Airflow API Server may not be ready yet"
    else
        echo -n "."
        sleep 2
    fi
done
echo ""

# Step 6: Show service status
echo ""
print_info "Step 6: Service Status"
echo "=========================================="
docker-compose ps

echo ""
print_info "Startup complete!"
echo ""
print_info "Service URLs:"
AIRFLOW_WEB_PORT=${AIRFLOW_WEB_PORT:-8082}
AIRFLOW_ADMIN_USERNAME=${AIRFLOW_ADMIN_USERNAME:-admin}
AIRFLOW_ADMIN_PASSWORD=${AIRFLOW_ADMIN_PASSWORD:-admin}
echo "  - Airflow Web UI: http://localhost:${AIRFLOW_WEB_PORT}"
echo "  - Username: ${AIRFLOW_ADMIN_USERNAME}"
echo "  - Password: ${AIRFLOW_ADMIN_PASSWORD}"
echo ""
print_info "To view logs: docker-compose logs -f [service-name]"
echo ""

