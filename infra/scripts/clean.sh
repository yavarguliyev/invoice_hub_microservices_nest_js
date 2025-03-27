#!/bin/bash
set -e

# Script to clean up the invoice-hub application from Kubernetes and Docker

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Define project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INFRA_DIR="${PROJECT_ROOT}/infra"
K8S_DIR="${INFRA_DIR}/k8s"
PORT_FORWARD_PID_FILE="/tmp/port-forward.pid"

# Print with color
print_info() {
  echo -e "${GREEN}[INFO] $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}[WARNING] $1${NC}"
}

print_error() {
  echo -e "${RED}[ERROR] $1${NC}" >&2
}

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
  print_error "kubectl is not installed. Please install it first."
  exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
  print_warning "Docker is not running. Will skip Docker cleanup."
  SKIP_DOCKER=true
else
  SKIP_DOCKER=false
fi

# Terminate any existing port forwarding
terminate_port_forwarding() {
  if [ -f "$PORT_FORWARD_PID_FILE" ]; then
    PID=$(cat "$PORT_FORWARD_PID_FILE")
    if ps -p "$PID" > /dev/null; then
      print_info "Terminating existing port forwarding (PID: $PID)..."
      kill "$PID" 2>/dev/null || true
    fi
    rm -f "$PORT_FORWARD_PID_FILE"
    print_info "Port forwarding terminated."
  else
    print_info "No port forwarding PID file found."
  fi
}

# Delete Kubernetes resources
delete_k8s_resources() {
  print_info "Deleting Kubernetes resources..."
  
  # Check if the namespace exists
  if kubectl get namespace invoice-hub &> /dev/null; then
    # Delete debug pod if it exists
    if kubectl get pod network-debug -n invoice-hub &> /dev/null; then
      print_info "Deleting debug pod..."
      kubectl delete -f "${K8S_DIR}/debug-pod.yaml" --ignore-not-found
    fi

    # Delete Ingress resources first
    print_info "Deleting Ingress resources..."
    kubectl delete -f "${K8S_DIR}/ingress-srv.yaml" -n invoice-hub --ignore-not-found

    # Delete all resources in the namespace
    print_info "Deleting all resources in the invoice-hub namespace..."
    kubectl delete -f "${K8S_DIR}/api-gateway.yaml" -n invoice-hub --ignore-not-found
    kubectl delete -f "${K8S_DIR}/auth-service.yaml" -n invoice-hub --ignore-not-found
    kubectl delete -f "${K8S_DIR}/invoice-service.yaml" -n invoice-hub --ignore-not-found
    kubectl delete -f "${K8S_DIR}/order-service.yaml" -n invoice-hub --ignore-not-found
    
    # Delete the namespace
    print_info "Deleting invoice-hub namespace..."
    kubectl delete -f "${K8S_DIR}/namespace.yaml" --ignore-not-found
    
    # Wait for namespace deletion
    print_info "Waiting for namespace to be deleted..."
    kubectl wait --for=delete namespace/invoice-hub --timeout=300s 2>/dev/null || true
  else
    print_warning "The invoice-hub namespace doesn't exist. Skipping Kubernetes cleanup."
  fi
  
  print_info "Kubernetes resources deleted successfully!"
}

# Remove Docker images
remove_docker_images() {
  if [ "$SKIP_DOCKER" = true ]; then
    print_warning "Skipping Docker cleanup as Docker is not running."
    return
  fi

  print_info "Removing Docker images..."
  
  # Remove invoice-hub images
  docker rmi -f invoice-hub/api-gateway:latest 2>/dev/null || true
  docker rmi -f invoice-hub/auth-service:latest 2>/dev/null || true
  docker rmi -f invoice-hub/invoice-service:latest 2>/dev/null || true
  docker rmi -f invoice-hub/order-service:latest 2>/dev/null || true
  
  print_info "Docker images removed successfully!"
}

# Clean up Docker resources
cleanup_docker_resources() {
  if [ "$SKIP_DOCKER" = true ]; then
    print_warning "Skipping Docker cleanup as Docker is not running."
    return
  fi

  print_info "Cleaning up unused Docker resources..."
  
  # Remove unused containers
  print_info "Removing unused containers..."
  docker container prune -f
  
  # Remove dangling images
  print_info "Removing dangling images..."
  docker image prune -f
  
  # Remove unused volumes
  print_info "Removing unused volumes..."
  docker volume prune -f
  
  # Remove unused networks
  print_info "Removing unused networks..."
  docker network prune -f
  
  print_info "Docker cleanup completed!"
}

# Main cleanup flow
main() {
  print_info "Starting cleanup of invoice-hub microservices..."
  
  # First terminate any port forwarding
  terminate_port_forwarding
  
  delete_k8s_resources
  remove_docker_images
  cleanup_docker_resources
  
  print_info "Cleanup process completed successfully!"
}

# Execute main function
main 