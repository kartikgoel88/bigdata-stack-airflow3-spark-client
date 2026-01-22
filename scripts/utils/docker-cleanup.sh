#!/bin/bash

# Docker Cleanup Script for Big Data Stack Airflow 3
# This script provides various levels of Docker cleanup for the project

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_DIR"

# Load environment variables from .env if it exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
cd b
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

print_header() {
    echo -e "${BLUE}[HEADER]${NC} $1"
}

# Function to confirm action
confirm() {
    local prompt="$1"
    local response
    read -p "$(echo -e ${YELLOW}$prompt${NC} [y/N]: )" response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to stop and remove containers
cleanup_containers() {
    print_header "Cleaning up containers..."
    if docker-compose ps -q | grep -q .; then
        print_info "Stopping containers..."
        docker-compose down
        print_info "Containers stopped and removed"
    else
        print_warn "No running containers found"
    fi
}

# Function to remove volumes
cleanup_volumes() {
    print_header "Cleaning up volumes..."
    if docker volume ls | grep -q "airflow-"; then
        print_warn "This will remove all Airflow volumes including database data!"
        if confirm "Remove volumes?"; then
            print_info "Removing volumes..."
            docker-compose down -v
            print_info "Volumes removed"
        else
            print_info "Skipping volume removal"
        fi
    else
        print_warn "No Airflow volumes found"
    fi
}

# Function to remove images
cleanup_images() {
    print_header "Cleaning up images..."
    AIRFLOW_IMAGE_NAME=${AIRFLOW_IMAGE_NAME:-apache/airflow-spark}
    AIRFLOW_IMAGE_TAG=${AIRFLOW_IMAGE_TAG:-latest}
    FULL_IMAGE_NAME="${AIRFLOW_IMAGE_NAME}:${AIRFLOW_IMAGE_TAG}"
    
    if docker images | grep -q "${AIRFLOW_IMAGE_NAME}"; then
        print_info "Found Airflow image: ${FULL_IMAGE_NAME}"
        if confirm "Remove Airflow image?"; then
            print_info "Removing Airflow image..."
            docker rmi "${FULL_IMAGE_NAME}" 2>/dev/null || print_warn "Image may be in use or already removed"
            print_info "Airflow image removed"
        else
            print_info "Skipping image removal"
        fi
    else
        print_warn "Airflow image not found"
    fi
    
    # Check for PostgreSQL image
    POSTGRES_VERSION=${POSTGRES_VERSION:-16}
    POSTGRES_IMAGE="postgres:${POSTGRES_VERSION}"
    if docker images | grep -q "postgres.*${POSTGRES_VERSION}"; then
        print_info "Found PostgreSQL image: ${POSTGRES_IMAGE}"
        if confirm "Remove PostgreSQL image?"; then
            print_info "Removing PostgreSQL image..."
            docker rmi "${POSTGRES_IMAGE}" 2>/dev/null || print_warn "Image may be in use or already removed"
            print_info "PostgreSQL image removed"
        else
            print_info "Skipping PostgreSQL image removal"
        fi
    fi
}

# Function to remove networks
cleanup_networks() {
    print_header "Cleaning up networks..."
    NETWORK_NAME=${NETWORK_NAME:-hadoop-network}
    NETWORK_EXTERNAL=${NETWORK_EXTERNAL:-false}
    
    if [ "$NETWORK_EXTERNAL" = "true" ]; then
        print_warn "Network ${NETWORK_NAME} is marked as external, skipping removal"
        return
    fi
    
    if docker network ls | grep -q "${NETWORK_NAME}"; then
        print_info "Found network: ${NETWORK_NAME}"
        if confirm "Remove network?"; then
            print_info "Removing network..."
            docker network rm "${NETWORK_NAME}" 2>/dev/null || print_warn "Network may be in use or already removed"
            print_info "Network removed"
        else
            print_info "Skipping network removal"
        fi
    else
        print_warn "Network ${NETWORK_NAME} not found"
    fi
}

# Function to clean up dangling images and build cache
cleanup_dangling() {
    print_header "Cleaning up dangling images and build cache..."
    
    # Remove dangling images
    DANGLING_IMAGES=$(docker images -f "dangling=true" -q)
    if [ -n "$DANGLING_IMAGES" ]; then
        print_info "Found dangling images"
        if confirm "Remove dangling images?"; then
            docker rmi $DANGLING_IMAGES 2>/dev/null || print_warn "Some dangling images may be in use"
            print_info "Dangling images removed"
        else
            print_info "Skipping dangling images removal"
        fi
    else
        print_info "No dangling images found"
    fi
    
    # Prune build cache
    if confirm "Prune Docker build cache?"; then
        print_info "Pruning build cache..."
        docker builder prune -f
        print_info "Build cache pruned"
    else
        print_info "Skipping build cache pruning"
    fi
}

# Function to perform full cleanup
full_cleanup() {
    print_header "Performing full cleanup..."
    print_warn "This will remove containers, volumes, images, and networks!"
    
    if ! confirm "Are you sure you want to perform a full cleanup?"; then
        print_info "Full cleanup cancelled"
        return
    fi
    
    # Stop and remove containers with volumes
    print_info "Stopping and removing containers with volumes..."
    docker-compose down -v 2>/dev/null || print_warn "Some containers may not have been running"
    
    # Remove images
    AIRFLOW_IMAGE_NAME=${AIRFLOW_IMAGE_NAME:-apache/airflow-spark}
    AIRFLOW_IMAGE_TAG=${AIRFLOW_IMAGE_TAG:-latest}
    FULL_IMAGE_NAME="${AIRFLOW_IMAGE_NAME}:${AIRFLOW_IMAGE_TAG}"
    
    if docker images | grep -q "${AIRFLOW_IMAGE_NAME}"; then
        print_info "Removing Airflow image..."
        docker rmi "${FULL_IMAGE_NAME}" 2>/dev/null || print_warn "Airflow image may be in use"
    fi
    
    # Remove network (if not external)
    NETWORK_NAME=${NETWORK_NAME:-hadoop-network}
    NETWORK_EXTERNAL=${NETWORK_EXTERNAL:-false}
    if [ "$NETWORK_EXTERNAL" != "true" ]; then
        if docker network ls | grep -q "${NETWORK_NAME}"; then
            print_info "Removing network..."
            docker network rm "${NETWORK_NAME}" 2>/dev/null || print_warn "Network may be in use"
        fi
    fi
    
    # Clean up dangling resources
    print_info "Cleaning up dangling resources..."
    docker system prune -f
    
    print_info "Full cleanup completed!"
}

# Function to show current Docker resources
show_status() {
    print_header "Current Docker Resources"
    echo ""
    print_info "Containers:"
    docker-compose ps 2>/dev/null || print_warn "No containers found"
    echo ""
    print_info "Volumes:"
    docker volume ls | grep -E "(airflow-|postgres)" || print_warn "No project volumes found"
    echo ""
    print_info "Images:"
    docker images | grep -E "(airflow|postgres)" || print_warn "No project images found"
    echo ""
    print_info "Networks:"
    NETWORK_NAME=${NETWORK_NAME:-hadoop-network}
    docker network ls | grep "${NETWORK_NAME}" || print_warn "Network ${NETWORK_NAME} not found"
    echo ""
}

# Main menu
show_menu() {
    echo ""
    print_header "Docker Cleanup Script"
    echo "=========================================="
    echo "1. Stop and remove containers"
    echo "2. Remove volumes (includes database data!)"
    echo "3. Remove images"
    echo "4. Remove networks"
    echo "5. Clean up dangling images and build cache"
    echo "6. Full cleanup (containers + volumes + images + networks)"
    echo "7. Show current status"
    echo "8. Exit"
    echo "=========================================="
}

# Main execution
main() {
    if [ "$1" = "--full" ] || [ "$1" = "-f" ]; then
        full_cleanup
        exit 0
    fi
    
    if [ "$1" = "--status" ] || [ "$1" = "-s" ]; then
        show_status
        exit 0
    fi
    
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        echo "Usage: $0 [OPTION]"
        echo ""
        echo "Options:"
        echo "  -f, --full     Perform full cleanup (non-interactive)"
        echo "  -s, --status   Show current Docker resources status"
        echo "  -h, --help     Show this help message"
        echo ""
        echo "If no option is provided, an interactive menu will be shown."
        exit 0
    fi
    
    # Interactive mode
    while true; do
        show_menu
        read -p "$(echo -e ${YELLOW}Select an option:${NC} )" choice
        
        case $choice in
            1)
                cleanup_containers
                ;;
            2)
                cleanup_volumes
                ;;
            3)
                cleanup_images
                ;;
            4)
                cleanup_networks
                ;;
            5)
                cleanup_dangling
                ;;
            6)
                full_cleanup
                ;;
            7)
                show_status
                ;;
            8)
                print_info "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid option. Please try again."
                ;;
        esac
        
        echo ""
        read -p "$(echo -e ${YELLOW}Press Enter to continue...${NC} )" dummy
    done
}

# Run main function
main "$@"

