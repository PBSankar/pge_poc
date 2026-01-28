#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== CRM Application Docker Build and Push Script ===${NC}"
echo

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Get application name and version
APP_NAME="crm-app"
VERSION=$(date +%Y%m%d-%H%M%S)
echo "Application: $APP_NAME"
echo "Version: $VERSION"
echo

# Registry selection
echo "Select container registry:"
echo "1) AWS ECR"
echo "2) Docker Hub"
echo "3) Other Registry"
read -p "Enter your choice (1-3): " REGISTRY_CHOICE

case $REGISTRY_CHOICE in
    1)
        echo
        print_status "Setting up AWS ECR..."
        read -p "Enter AWS Region (e.g., us-east-1): " AWS_REGION
        read -p "Enter AWS Account ID: " AWS_ACCOUNT_ID
        read -p "Enter ECR Repository name (default: crm-app): " ECR_REPO
        ECR_REPO=${ECR_REPO:-crm-app}
        
        REGISTRY_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        IMAGE_NAME="${REGISTRY_URL}/${ECR_REPO}"
        
        # AWS CLI check
        if ! command -v aws &> /dev/null; then
            print_error "AWS CLI is not installed. Please install it first."
            exit 1
        fi
        
        # Create ECR repository if it doesn't exist
        print_status "Creating ECR repository if it doesn't exist..."
        aws ecr describe-repositories --region $AWS_REGION --repository-names $ECR_REPO 2>/dev/null || \
        aws ecr create-repository --region $AWS_REGION --repository-name $ECR_REPO
        
        # Login to ECR
        print_status "Logging into AWS ECR..."
        aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $REGISTRY_URL
        ;;
    2)
        echo
        print_status "Setting up Docker Hub..."
        read -p "Enter Docker Hub username: " DOCKER_USERNAME
        read -s -p "Enter Docker Hub password/token: " DOCKER_PASSWORD
        echo
        
        IMAGE_NAME="${DOCKER_USERNAME}/${APP_NAME}"
        
        # Login to Docker Hub
        print_status "Logging into Docker Hub..."
        echo $DOCKER_PASSWORD | docker login --username $DOCKER_USERNAME --password-stdin
        ;;
    3)
        echo
        print_status "Setting up custom registry..."
        read -p "Enter registry URL (e.g., registry.example.com): " CUSTOM_REGISTRY
        read -p "Enter username: " REGISTRY_USERNAME
        read -s -p "Enter password: " REGISTRY_PASSWORD
        echo
        
        IMAGE_NAME="${CUSTOM_REGISTRY}/${APP_NAME}"
        
        # Login to custom registry
        print_status "Logging into custom registry..."
        echo $REGISTRY_PASSWORD | docker login --username $REGISTRY_USERNAME --password-stdin $CUSTOM_REGISTRY
        ;;
    *)
        print_error "Invalid choice. Exiting."
        exit 1
        ;;
esac

echo
print_status "Building Docker image..."
echo "Image: ${IMAGE_NAME}:${VERSION}"
echo "Image: ${IMAGE_NAME}:latest"

# Build the Docker image
if docker build -t "${IMAGE_NAME}:${VERSION}" -t "${IMAGE_NAME}:latest" .; then
    print_status "Docker image built successfully!"
else
    print_error "Docker build failed!"
    exit 1
fi

echo
print_status "Pushing Docker images..."

# Push versioned image
if docker push "${IMAGE_NAME}:${VERSION}"; then
    print_status "Pushed ${IMAGE_NAME}:${VERSION}"
else
    print_error "Failed to push ${IMAGE_NAME}:${VERSION}"
    exit 1
fi

# Push latest image
if docker push "${IMAGE_NAME}:latest"; then
    print_status "Pushed ${IMAGE_NAME}:latest"
else
    print_error "Failed to push ${IMAGE_NAME}:latest"
    exit 1
fi

echo
print_status "Build and push completed successfully!"
echo "Images pushed:"
echo "  - ${IMAGE_NAME}:${VERSION}"
echo "  - ${IMAGE_NAME}:latest"
echo
print_warning "Remember to update your Kubernetes deployment files with the new image:"
echo "  ${IMAGE_NAME}:${VERSION}"
echo