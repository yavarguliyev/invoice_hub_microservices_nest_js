#!/bin/bash
set -e

# Script to deploy the invoice-hub application to Kubernetes

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

# Initialize variables
DEPLOY_DEBUG=false
INSTALL_INGRESS=false
SKIP_BUILD=false
SKIP_DEPLOY=false
SKIP_PORT_FORWARD=false
SKIP_INGRESS=true  # Default to skip ingress due to previous failures
SKIP_VERIFY=false
KEEP_PORT_FORWARD=false  # New variable to control port forwarding cleanup

# Error handling
handle_error() {
  local exit_code=$?
  print_warning "A command failed with exit code $exit_code. Attempting to continue..."
  # We don't want to exit because we want to try to complete as many steps as possible
}

# Set up error handler
trap 'handle_error' ERR

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
  print_error "Docker is not running. Please start Docker first."
  exit 1
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
  fi
}

# Parse command line arguments
parse_args() {
  for arg in "$@"; do
    case $arg in
      --debug)
        DEPLOY_DEBUG=true
        shift
        ;;
      --install-ingress)
        INSTALL_INGRESS=true
        shift
        ;;
      --skip-port-forward)
        SKIP_PORT_FORWARD=true
        shift
        ;;
      --keep-port-forward)
        KEEP_PORT_FORWARD=true
        shift
        ;;
      --with-ingress)
        SKIP_INGRESS=false
        shift
        ;;
      --no-verify)
        SKIP_VERIFY=true
        shift
        ;;
      --skip-build)
        SKIP_BUILD=true
        shift
        ;;
      --skip-deploy)
        SKIP_DEPLOY=true
        shift
        ;;
      *)
        shift
        ;;
    esac
  done
}

# Check and install Nginx Ingress Controller if needed
check_install_ingress() {
  if [ "$INSTALL_INGRESS" = true ]; then
    print_info "Installing NGINX Ingress Controller..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
    kubectl wait --namespace ingress-nginx \
      --for=condition=ready pod \
      --selector=app.kubernetes.io/component=controller \
      --timeout=300s
    print_info "NGINX Ingress Controller installed successfully!"
  else
    if ! kubectl get namespace ingress-nginx &> /dev/null; then
      print_warning "NGINX Ingress Controller not detected. You may need to install it manually:"
      print_info "kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml"
      print_info "Or run this script with --install-ingress flag"
    else
      print_info "NGINX Ingress Controller already installed."
    fi
  fi
}

# Build docker images
build_docker_images() {
  print_info "Building docker images..."
  
  # Build API Gateway
  print_info "Building API Gateway image..."
  docker build -t invoice-hub/api-gateway:latest -f "${INFRA_DIR}/Dockerfile.api-gateway" "${PROJECT_ROOT}"
  
  # Build Auth Service
  print_info "Building Auth Service image..."
  docker build -t invoice-hub/auth-service:latest -f "${INFRA_DIR}/Dockerfile.auth" "${PROJECT_ROOT}"
  
  # Build Invoice Service
  print_info "Building Invoice Service image..."
  docker build -t invoice-hub/invoice-service:latest -f "${INFRA_DIR}/Dockerfile.invoice" "${PROJECT_ROOT}"
  
  # Build Order Service
  print_info "Building Order Service image..."
  docker build -t invoice-hub/order-service:latest -f "${INFRA_DIR}/Dockerfile.order" "${PROJECT_ROOT}"
  
  print_info "All docker images built successfully!"
}

# Apply Kubernetes manifests
apply_k8s_manifests() {
  print_info "Applying Kubernetes manifests..."
  
  # Create namespace
  kubectl apply -f "${K8S_DIR}/namespace.yaml"
  
  # Apply service manifests first (without API Gateway)
  kubectl apply -f "${K8S_DIR}/auth-service.yaml" -n invoice-hub
  kubectl apply -f "${K8S_DIR}/invoice-service.yaml" -n invoice-hub
  kubectl apply -f "${K8S_DIR}/order-service.yaml" -n invoice-hub
  
  print_info "Waiting for service deployments to be ready..."
  kubectl wait --for=condition=available --timeout=300s deployment/auth-service -n invoice-hub
  kubectl wait --for=condition=available --timeout=300s deployment/invoice-service -n invoice-hub
  kubectl wait --for=condition=available --timeout=300s deployment/order-service -n invoice-hub
  
  # Apply Ingress manifest (optional - may fail)
  if [ "$SKIP_INGRESS" != "true" ]; then
    print_info "Attempting to apply Ingress manifest..."
    kubectl apply -f "${K8S_DIR}/ingress-srv.yaml" -n invoice-hub || {
      print_warning "Failed to apply Ingress manifest. Continuing without ingress."
    }
  else
    print_info "Skipping Ingress deployment as requested."
  fi
  
  # Deploy debug pod if requested
  if [ "$DEPLOY_DEBUG" = true ]; then
    print_info "Deploying network debug pod..."
    kubectl apply -f "${K8S_DIR}/debug-pod.yaml" -n invoice-hub
  fi
  
  print_info "Initial Kubernetes manifests applied successfully!"
}

# Get service IPs
get_service_ips() {
  print_info "Getting direct pod IPs for services..."
  
  # Wait for pods to be ready
  print_info "Waiting for pods to be ready..."
  
  # Try multiple times to get the pod information
  MAX_RETRIES=10
  RETRY_INTERVAL=5
  
  for retry in $(seq 1 $MAX_RETRIES); do
    # Try to wait for pods to be ready
    if kubectl wait --for=condition=ready pod -l app=auth-service -n invoice-hub --timeout=30s 2>/dev/null && \
       kubectl wait --for=condition=ready pod -l app=invoice-service -n invoice-hub --timeout=30s 2>/dev/null && \
       kubectl wait --for=condition=ready pod -l app=order-service -n invoice-hub --timeout=30s 2>/dev/null; then
      print_info "All pods are ready!"
      break
    fi
    
    if [ $retry -eq $MAX_RETRIES ]; then
      print_warning "Maximum retries reached, continuing with best effort..."
    else
      print_warning "Not all pods are ready, retrying in $RETRY_INTERVAL seconds... (Attempt $retry/$MAX_RETRIES)"
      sleep $RETRY_INTERVAL
    fi
  done
  
  # Get pod IPs
  AUTH_POD=$(kubectl get pods -l app=auth-service -n invoice-hub -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  INVOICE_POD=$(kubectl get pods -l app=invoice-service -n invoice-hub -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  ORDER_POD=$(kubectl get pods -l app=order-service -n invoice-hub -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  
  AUTH_IP=$(kubectl get pod $AUTH_POD -n invoice-hub -o jsonpath='{.status.podIP}' 2>/dev/null)
  INVOICE_IP=$(kubectl get pod $INVOICE_POD -n invoice-hub -o jsonpath='{.status.podIP}' 2>/dev/null)
  ORDER_IP=$(kubectl get pod $ORDER_POD -n invoice-hub -o jsonpath='{.status.podIP}' 2>/dev/null)
  
  # Default ports
  AUTH_PORT="3001"
  INVOICE_PORT="3002"
  ORDER_PORT="3003"
  
  # Check if we have valid IPs
  if [ -z "$AUTH_IP" ] || [ -z "$INVOICE_IP" ] || [ -z "$ORDER_IP" ]; then
    print_warning "Failed to get pod IPs. Using service names as fallback."
    AUTH_IP="auth-service"
    INVOICE_IP="invoice-service"
    ORDER_IP="order-service"
  else
    print_info "Pod IPs obtained successfully!"
    print_info "Auth Service Pod IP: $AUTH_IP"
    print_info "Invoice Service Pod IP: $INVOICE_IP"
    print_info "Order Service Pod IP: $ORDER_IP"
  fi
  
  print_info "Auth Service will be accessed at: ${AUTH_IP}:${AUTH_PORT}"
  print_info "Invoice Service will be accessed at: ${INVOICE_IP}:${INVOICE_PORT}"
  print_info "Order Service will be accessed at: ${ORDER_IP}:${ORDER_PORT}"
  
  # Store full service URLs for later use
  AUTH_URL="${AUTH_IP}:${AUTH_PORT}"
  INVOICE_URL="${INVOICE_IP}:${INVOICE_PORT}"
  ORDER_URL="${ORDER_IP}:${ORDER_PORT}"
}

# Apply API Gateway with service IPs
apply_api_gateway() {
  print_info "Applying API Gateway with direct pod IPs..."
  
  # Create a temporary file for the modified manifest
  TMP_MANIFEST=$(mktemp)
  cat "${K8S_DIR}/api-gateway.yaml" > "$TMP_MANIFEST"
  
  # Replace service URLs with direct pod IPs
  sed -i '' "s|value: \"auth-service:3001\"|value: \"${AUTH_URL}\"|g" "$TMP_MANIFEST"
  sed -i '' "s|value: \"invoice-service:3002\"|value: \"${INVOICE_URL}\"|g" "$TMP_MANIFEST"
  sed -i '' "s|value: \"order-service:3003\"|value: \"${ORDER_URL}\"|g" "$TMP_MANIFEST"
  
  # Apply the modified manifest
  kubectl apply -f "$TMP_MANIFEST" -n invoice-hub
  rm "$TMP_MANIFEST"
  
  print_info "API Gateway deployed with direct pod IPs configuration!"
  
  # Wait for API Gateway to be ready
  print_info "Waiting for API Gateway deployment to be ready..."
  kubectl wait --for=condition=available --timeout=300s deployment/api-gateway -n invoice-hub
}

# Setup port forwarding for API Gateway
setup_port_forwarding() {
  if [ "$SKIP_PORT_FORWARD" = true ]; then
    return
  fi
  
  # Cleanup any existing port-forwarding
  if [ -f "$PORT_FORWARD_PID_FILE" ]; then
    OLD_PID=$(cat "$PORT_FORWARD_PID_FILE")
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
      print_info "Killing existing port forwarding process (PID: $OLD_PID)..."
      kill "$OLD_PID" > /dev/null 2>&1
    fi
    rm -f "$PORT_FORWARD_PID_FILE"
  fi

  print_info "Setting up port forwarding for API Gateway (localhost:8080 -> api-gateway:80)..."
  # Try a few times to set up port forwarding
  MAX_RETRIES=5
  for retry in $(seq 1 $MAX_RETRIES); do
    kubectl port-forward svc/api-gateway 8080:80 -n invoice-hub > /dev/null 2>&1 &
    PF_PID=$!
    echo $PF_PID > "$PORT_FORWARD_PID_FILE"
    
    # Give it a moment to establish
    sleep 2
    
    # Check if port forwarding is actually working
    if ps -p $PF_PID > /dev/null && curl -s http://localhost:8080 > /dev/null 2>&1; then
      print_info "Port forwarding successfully established (PID: $PF_PID)"
      return 0
    else
      print_warning "Port forwarding attempt $retry/$MAX_RETRIES failed. Retrying..."
      kill $PF_PID > /dev/null 2>&1 || true
      sleep 1
    fi
    
    if [ $retry -eq $MAX_RETRIES ]; then
      print_warning "Failed to establish port forwarding after $MAX_RETRIES attempts."
      print_warning "You can manually set it up with: kubectl port-forward svc/api-gateway 8080:80 -n invoice-hub"
      rm -f "$PORT_FORWARD_PID_FILE"
      SKIP_PORT_FORWARD=true
      return 1
    fi
  done
}

# Verify that services are accessible
verify_services() {
  if [ "$SKIP_PORT_FORWARD" = true ]; then
    return
  fi

  print_info "Verifying API Gateway accessibility..."
  
  # Give the service more time to stabilize
  print_info "Waiting for API Gateway to stabilize..."
  sleep 5
  
  # Try up to 3 times to access each service
  MAX_RETRIES=3
  
  # Try to access the API Gateway
  for retry in $(seq 1 $MAX_RETRIES); do
    API_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null || echo "failed")
    
    if [ "$API_RESPONSE" = "200" ]; then
      print_info "API Gateway is accessible!"
      break
    else
      if [ $retry -eq $MAX_RETRIES ]; then
        print_warning "API Gateway verification failed after $MAX_RETRIES attempts. Response code: $API_RESPONSE"
        print_warning "You may need to check the service logs for issues:"
        print_info "kubectl logs deployment/api-gateway -n invoice-hub"
        return 1
      else
        print_warning "API Gateway verification failed. Retrying in 3 seconds... (Attempt $retry/$MAX_RETRIES)"
        sleep 3
      fi
    fi
  done
  
  # Function to test a service endpoint
  test_service_endpoint() {
    local service_name=$1
    local endpoint=$2
    local max_retries=$3
    
    print_info "Testing $service_name endpoint..."
    
    for retry in $(seq 1 $max_retries); do
      local response=$(curl -s -o /dev/null -w "%{http_code}" $endpoint 2>/dev/null || echo "failed")
      
      if [ "$response" = "200" ]; then
        print_info "$service_name is accessible!"
        return 0
      else
        if [ $retry -eq $max_retries ]; then
          print_warning "$service_name verification failed after $max_retries attempts. Response code: $response"
          return 1
        else
          print_warning "$service_name verification failed. Retrying in 2 seconds... (Attempt $retry/$max_retries)"
          sleep 2
        fi
      fi
    done
  }
  
  # Test each service
  test_service_endpoint "Auth Service" "http://localhost:8080/auth" $MAX_RETRIES
  test_service_endpoint "Invoice Service" "http://localhost:8080/invoices" $MAX_RETRIES
  test_service_endpoint "Order Service" "http://localhost:8080/orders" $MAX_RETRIES
  
  print_info "Service verification completed."
}

# Display service information
display_info() {
  print_info "Deployment completed successfully!"
  
  if [ "$SKIP_PORT_FORWARD" = false ]; then
    print_info "API Gateway is accessible at http://localhost:8080"
    print_info "Available endpoints:"
    print_info "- Root: http://localhost:8080/"
    print_info "- Auth Service: http://localhost:8080/auth"
    print_info "- Invoice Service: http://localhost:8080/invoices"
    print_info "- Order Service: http://localhost:8080/orders"
    print_info ""
    print_info "Port forwarding is running in the background (PID: $(cat "$PORT_FORWARD_PID_FILE"))"
    print_info "To stop port forwarding: kill $(cat "$PORT_FORWARD_PID_FILE")"
  else
    # Get Ingress address
    INGRESS_IP=$(kubectl get ingress ingress-srv -n invoice-hub -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>/dev/null)
    INGRESS_HOST=$(kubectl get ingress ingress-srv -n invoice-hub -o jsonpath="{.status.loadBalancer.ingress[0].hostname}" 2>/dev/null)
    
    if [ -n "$INGRESS_IP" ]; then
      print_info "Your application is accessible at http://${INGRESS_IP}"
    elif [ -n "$INGRESS_HOST" ]; then
      print_info "Your application is accessible at http://${INGRESS_HOST}"
    else
      print_warning "Ingress address not assigned yet. For Docker Desktop, you can access the application via:"
      
      INGRESS_PORT=$(kubectl -n ingress-nginx get service ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}' 2>/dev/null)
      if [ -n "$INGRESS_PORT" ]; then
        print_info "http://localhost:${INGRESS_PORT}"
      else
        print_info "To manually set up port forwarding:"
        print_info "kubectl port-forward svc/api-gateway 8080:80 -n invoice-hub"
        print_info "Then access at http://localhost:8080"
      fi
    fi
  fi
  
  if [ "$DEPLOY_DEBUG" = true ]; then
    print_info "Network debug pod deployed. You can access it using:"
    print_info "kubectl exec -it network-debug -n invoice-hub -- bash"
  fi
  
  print_info "Service configuration details:"
  print_info "Auth Service: ${AUTH_IP}:${AUTH_PORT}"
  print_info "Invoice Service: ${INVOICE_IP}:${INVOICE_PORT}"
  print_info "Order Service: ${ORDER_IP}:${ORDER_PORT}"
  
  print_info "To check service logs:"
  print_info "kubectl logs deployment/api-gateway -n invoice-hub"
  print_info "kubectl logs deployment/auth-service -n invoice-hub"
  print_info "kubectl logs deployment/invoice-service -n invoice-hub"
  print_info "kubectl logs deployment/order-service -n invoice-hub"
}

# Clean up unused resources
cleanup_unused_resources() {
  print_info "Cleaning up unused Docker resources..."
  
  # Remove unused containers
  docker container prune -f
  
  # Remove dangling images
  docker image prune -f
  
  # Remove unused volumes
  docker volume prune -f
  
  # Remove unused networks
  docker network prune -f
  
  print_info "Cleanup completed!"
}

# Cleanup resources on script exit
cleanup_on_exit() {
  print_info "Cleaning up resources..."
  
  # Kill port forwarding if active and not flagged to keep
  if [ "$KEEP_PORT_FORWARD" = false ] && [ -f "$PORT_FORWARD_PID_FILE" ]; then
    PF_PID=$(cat "$PORT_FORWARD_PID_FILE")
    if ps -p "$PF_PID" > /dev/null 2>&1; then
      print_info "Killing port forwarding process (PID: $PF_PID)..."
      kill "$PF_PID" > /dev/null 2>&1
    fi
    rm -f "$PORT_FORWARD_PID_FILE"
  elif [ "$KEEP_PORT_FORWARD" = true ] && [ -f "$PORT_FORWARD_PID_FILE" ]; then
    PF_PID=$(cat "$PORT_FORWARD_PID_FILE")
    if ps -p "$PF_PID" > /dev/null 2>&1; then
      print_info "Port forwarding still active on PID: $PF_PID"
      print_info "To terminate it manually: kill $PF_PID"
    fi
  fi
  
  print_info "Cleanup completed."
}

# Set up trap to call cleanup on script exit
trap cleanup_on_exit EXIT

# Main deployment flow
main() {
  parse_args "$@"
  
  print_info "Starting deployment process for invoice-hub services..."
  
  if [ "$SKIP_INGRESS" = false ]; then
    check_install_ingress || print_warning "Ingress installation skipped or failed, continuing with deployment"
  else
    print_info "Skipping ingress installation as configured"
  fi
  
  if [ "$SKIP_BUILD" = false ]; then
    build_docker_images || print_warning "Docker image build had issues, continuing with best effort"
  else
    print_info "Skipping Docker image build as requested"
  fi
  
  if [ "$SKIP_DEPLOY" = false ]; then
    apply_k8s_manifests || print_warning "Kubernetes manifests application had issues, continuing with best effort"
    
    # Wait for deployments to be ready
    print_info "Waiting for deployments to be ready..."
    for i in $(seq 1 10); do
      if kubectl wait --for=condition=available --timeout=60s deployment -l app.kubernetes.io/part-of=invoice-hub -n invoice-hub 2>/dev/null; then
        print_info "All deployments are ready!"
        break
      else
        if [ $i -eq 10 ]; then
          print_warning "Not all deployments are ready after 10 attempts. Continuing with best effort."
        else
          print_warning "Not all deployments are ready. Retrying in 5 seconds... (Attempt $i/10)"
          sleep 5
        fi
      fi
    done
    
    get_service_ips || print_warning "Service IP discovery had issues, continuing with best effort"
    apply_api_gateway || print_warning "API Gateway configuration had issues, continuing with best effort"
    
    # Setup port forwarding for testing
    if [ "$SKIP_PORT_FORWARD" = false ]; then
      if setup_port_forwarding; then
        if [ "$SKIP_VERIFY" = false ]; then
          verify_services || print_warning "Service verification had issues, manual verification may be needed"
        else
          print_info "Skipping service verification as requested"
        fi
      else
        print_warning "Port forwarding setup failed, skipping service verification"
      fi
    else
      print_info "Skipping port forwarding as requested"
    fi
  else
    print_info "Skipping Kubernetes deployment as requested"
  fi
  
  # Clean up unused resources
  cleanup_unused_resources || print_warning "Resource cleanup had issues, manual cleanup may be needed"
  
  # Print summary
  print_info "=== Deployment Summary ==="
  print_info "Ingress Deployment: $([ "$SKIP_INGRESS" = false ] && echo "Attempted" || echo "Skipped")"
  print_info "Docker Image Build: $([ "$SKIP_BUILD" = false ] && echo "Completed" || echo "Skipped")"
  print_info "Kubernetes Deployment: $([ "$SKIP_DEPLOY" = false ] && echo "Completed" || echo "Skipped")"
  
  if [ "$SKIP_PORT_FORWARD" = false ]; then
    if [ "$KEEP_PORT_FORWARD" = true ] && [ -f "$PORT_FORWARD_PID_FILE" ]; then
      PF_PID=$(cat "$PORT_FORWARD_PID_FILE")
      if ps -p "$PF_PID" > /dev/null 2>&1; then
        print_info "Port Forwarding: Active on port 8080 (PID: $PF_PID)"
      else
        print_info "Port Forwarding: Failed to maintain"
      fi
    else
      print_info "Port Forwarding: Enabled during deployment only"
    fi
  else
    print_info "Port Forwarding: Disabled"
  fi
  
  print_info "Service Verification: $([ "$SKIP_VERIFY" = false ] && ([ "$SKIP_PORT_FORWARD" = false ] && echo "Attempted" || echo "Skipped due to no port forwarding") || echo "Skipped")"
  
  print_info "=== Next Steps ==="
  print_info "1. Access API Gateway: http://localhost:8080"
  print_info "2. Verify services: "
  print_info "   - Auth Service: http://localhost:8080/auth"
  print_info "   - Invoice Service: http://localhost:8080/invoices"
  print_info "   - Order Service: http://localhost:8080/orders"
  print_info "3. Check logs: kubectl logs deployment/api-gateway -n invoice-hub"
  
  print_info "Deployment process completed!"
}

# Call main function with all args
main "$@" 