# Invoice Hub Infrastructure

This directory contains all the infrastructure configurations and deployment scripts for the Invoice Hub application.

## Directory Structure

- **k8s/**: Kubernetes manifests for deploying services
- **scripts/**: Shell scripts for automation
  - **deploy.sh**: Deploy the entire application
  - **clean.sh**: Clean up all deployed resources

## Prerequisites

Before using these scripts, ensure you have the following installed:

- Docker Desktop with Kubernetes enabled
- kubectl (configured to use your Kubernetes cluster)
- bash shell environment

## Deployment Scripts

### deploy.sh

The `deploy.sh` script automates the deployment of the Invoice Hub microservices to Kubernetes.

#### Usage

```bash
./scripts/deploy.sh [OPTIONS]
```

#### Options

| Option | Description |
|--------|-------------|
| `--keep-port-forward` | Keep port forwarding active after the script exits |
| `--skip-build` | Skip building Docker images |
| `--skip-deploy` | Skip Kubernetes deployment |
| `--with-ingress` | Enable ingress deployment (disabled by default) |
| `--no-verify` | Skip service verification steps |
| `--skip-port-forward` | Skip port forwarding setup entirely |
| `--debug` | Enable debug mode for more verbose output |

#### Examples

```bash
# Basic deployment with default settings
./scripts/deploy.sh

# Deploy with persistent port forwarding
./scripts/deploy.sh --keep-port-forward

# Skip building images (use existing ones)
./scripts/deploy.sh --skip-build

# Deploy with ingress enabled
./scripts/deploy.sh --with-ingress
```

#### What the script does

1. Builds Docker images for all services
2. Creates the `invoice-hub` namespace in Kubernetes
3. Deploys all microservices to Kubernetes
4. Configures services with direct pod IPs to avoid DNS resolution issues
5. Sets up port forwarding to access the API Gateway
6. Verifies that all services are accessible
7. Cleans up unused Docker resources

### clean.sh

The `clean.sh` script removes all deployed resources from Kubernetes and cleans up Docker resources.

#### Usage

```bash
./scripts/clean.sh
```

#### What the script does

1. Terminates any active port forwarding
2. Deletes all Kubernetes resources in the `invoice-hub` namespace
3. Removes the Docker images created for the services
4. Cleans up unused Docker containers, images, volumes, and networks

## Accessing the Services

After successful deployment with port forwarding enabled:

- API Gateway: http://localhost:8080
- Auth Service: http://localhost:8080/auth
- Invoice Service: http://localhost:8080/invoices
- Order Service: http://localhost:8080/orders

## Troubleshooting

### Port Forwarding Issues

If port forwarding fails or you need to manually set it up:

```bash
kubectl port-forward svc/api-gateway 8080:80 -n invoice-hub
```

### Checking Service Logs

To check logs for any service:

```bash
# For API Gateway
kubectl logs -f deployment/api-gateway -n invoice-hub

# For Auth Service
kubectl logs -f deployment/auth-service -n invoice-hub

# For Invoice Service
kubectl logs -f deployment/invoice-service -n invoice-hub

# For Order Service
kubectl logs -f deployment/order-service -n invoice-hub
```

### Manually Stopping Port Forwarding

If you used the `--keep-port-forward` option and need to manually stop port forwarding:

```bash
# Find the PID from the output of deploy.sh
kill <PORT_FORWARDING_PID>
```

## Architecture Diagram

```
┌───────────────┐      ┌───────────────┐
│               │      │ Auth Service  │
│  API Gateway  │─────▶│ (gRPC)        │
│  (HTTP REST)  │      │ Port: 3001    │
│               │      └───────────────┘
│   Port: 80    │      
│               │      ┌───────────────┐
│               │      │Invoice Service│
│               │─────▶│ (gRPC)        │
│               │      │ Port: 3002    │
│               │      └───────────────┘
│               │      
│               │      ┌───────────────┐
│               │      │ Order Service │
│               │─────▶│ (gRPC)        │
│               │      │ Port: 3003    │
└───────────────┘      └───────────────┘
```

## Known Issues and Limitations

1. DNS resolution in Docker Desktop Kubernetes can be unreliable for gRPC services
   - The deploy.sh script addresses this by using direct pod IPs

2. Ingress deployment may fail in Docker Desktop Kubernetes
   - Ingress deployment is disabled by default
   - Use the `--with-ingress` flag to attempt ingress deployment 