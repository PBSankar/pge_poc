#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== CRM Application EKS Deployment Script ===${NC}"
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

# Check required tools
check_dependencies() {
    local deps=("kubectl" "aws")
    for dep in "${deps[@]}"; do
        if ! command -v $dep &> /dev/null; then
            print_error "$dep is not installed. Please install it first."
            exit 1
        fi
    done
    print_status "All required dependencies are installed."
}

# Get EKS cluster information
get_cluster_info() {
    echo "EKS Cluster Configuration:"
    read -p "Enter AWS Region (e.g., us-east-1): " AWS_REGION
    read -p "Enter EKS Cluster Name: " CLUSTER_NAME
    read -p "Enter Docker Image (with tag, e.g., your-registry/crm-app:latest): " DOCKER_IMAGE
    echo
}

# Update kubeconfig
update_kubeconfig() {
    print_status "Updating kubeconfig for EKS cluster..."
    if aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME; then
        print_status "Kubeconfig updated successfully."
    else
        print_error "Failed to update kubeconfig. Check your AWS credentials and cluster name."
        exit 1
    fi
    echo
}

# Verify cluster connection
verify_connection() {
    print_status "Verifying cluster connection..."
    if kubectl cluster-info &>/dev/null; then
        print_status "Successfully connected to cluster."
        kubectl get nodes
    else
        print_error "Cannot connect to cluster. Please check your configuration."
        exit 1
    fi
    echo
}

# Update deployment image
update_deployment_image() {
    print_status "Updating deployment image to: $DOCKER_IMAGE"
    
    # Create a temporary deployment file with the updated image
    cp kubernetes/deployment.yaml kubernetes/deployment-temp.yaml
    
    # Replace the image in the deployment file
    sed -i "s|image: crm-app:latest|image: $DOCKER_IMAGE|g" kubernetes/deployment-temp.yaml
    
    print_status "Deployment file updated with new image."
}

# Apply Kubernetes manifests
apply_manifests() {
    print_status "Applying Kubernetes manifests..."
    
    # Apply manifests in order
    local manifests=(
        "kubernetes/namespace.yaml"
        "kubernetes/configmap.yaml"
        "kubernetes/secret.yaml"
        "kubernetes/deployment-temp.yaml"
        "kubernetes/service.yaml"
        "kubernetes/ingress.yaml"
    )
    
    for manifest in "${manifests[@]}"; do
        if [ -f "$manifest" ]; then
            print_status "Applying $manifest..."
            if kubectl apply -f "$manifest"; then
                print_status "Successfully applied $manifest"
            else
                print_error "Failed to apply $manifest"
                exit 1
            fi
        else
            print_warning "Manifest file $manifest not found, skipping..."
        fi
    done
    
    # Clean up temporary file
    rm -f kubernetes/deployment-temp.yaml
    echo
}

# Wait for deployment
wait_for_deployment() {
    print_status "Waiting for deployment to be ready..."
    
    if kubectl wait --for=condition=available --timeout=300s deployment/crm-app-deployment -n crm-app; then
        print_status "Deployment is ready!"
    else
        print_error "Deployment failed to become ready within 5 minutes."
        print_status "Checking deployment status..."
        kubectl get pods -n crm-app
        kubectl describe deployment crm-app-deployment -n crm-app
        exit 1
    fi
    echo
}

# Get deployment status
get_deployment_status() {
    print_status "Deployment Status:"
    kubectl get all -n crm-app
    echo
    
    print_status "Pod Details:"
    kubectl get pods -n crm-app -o wide
    echo
    
    print_status "Service Details:"
    kubectl get svc -n crm-app
    echo
    
    print_status "Ingress Details:"
    kubectl get ingress -n crm-app
    echo
}

# Get application URL
get_application_url() {
    print_status "Getting application URL..."
    
    # Try to get LoadBalancer service external IP
    EXTERNAL_IP=$(kubectl get svc crm-app-service -n crm-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [ -n "$EXTERNAL_IP" ]; then
        echo "Application URL: http://$EXTERNAL_IP"
        echo "Health Check: http://$EXTERNAL_IP/appinfo/health"
    else
        # Get ingress URL if available
        INGRESS_HOST=$(kubectl get ingress crm-app-ingress -n crm-app -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "")
        if [ -n "$INGRESS_HOST" ]; then
            echo "Application URL: https://$INGRESS_HOST"
            echo "Health Check: https://$INGRESS_HOST/appinfo/health"
        else
            print_warning "External URL not available yet. Use port-forward for testing:"
            echo "kubectl port-forward svc/crm-app-service 8080:80 -n crm-app"
            echo "Then access: http://localhost:8080"
        fi
    fi
    echo
}

# Rollback function
rollback_deployment() {
    print_warning "Do you want to rollback the deployment? (y/n)"
    read -p "Enter your choice: " ROLLBACK_CHOICE
    
    if [[ $ROLLBACK_CHOICE =~ ^[Yy]$ ]]; then
        print_status "Rolling back deployment..."
        kubectl rollout undo deployment/crm-app-deployment -n crm-app
        kubectl rollout status deployment/crm-app-deployment -n crm-app
        print_status "Rollback completed."
    fi
}

# Main execution
main() {
    check_dependencies
    get_cluster_info
    update_kubeconfig
    verify_connection
    update_deployment_image
    apply_manifests
    wait_for_deployment
    get_deployment_status
    get_application_url
    
    print_status "Deployment completed successfully!"
    
    # Ask for rollback if deployment fails
    if kubectl get deployment crm-app-deployment -n crm-app -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' | grep -q "False"; then
        print_error "Deployment is not fully available."
        rollback_deployment
    fi
}

# Trap for cleanup on exit
trap 'echo; print_warning "Script interrupted. Deployment may be incomplete."' INT TERM

# Run main function
main

echo
print_status "For logs, use: kubectl logs -f deployment/crm-app-deployment -n crm-app"
print_status "For shell access, use: kubectl exec -it deployment/crm-app-deployment -n crm-app -- /bin/bash"
echo