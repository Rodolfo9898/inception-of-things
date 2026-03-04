#!/bin/bash

set -euo pipefail

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo_success() { echo -e "${GREEN}✓ $1${NC}"; }
echo_error() { echo -e "${RED}✗ $1${NC}"; exit 1; }
echo_info() { echo -e "${BLUE}ℹ $1${NC}"; }

# Configuration
CLUSTER_NAME="iot-cluster"
API_PORT="6550"
HTTP_PORT="8080"
HTTPS_PORT="8443"

echo ""
echo "=========================================="
echo " K3d Cluster Setup"
echo " Cluster: $CLUSTER_NAME"
echo "=========================================="
echo ""

# Check if cluster already exists
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo_info "Cluster '$CLUSTER_NAME' already exists."
    read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo_info "Deleting existing cluster..."
        k3d cluster delete "$CLUSTER_NAME" || echo_error "Failed to delete cluster"
        echo_success "Cluster deleted"
    else
        echo_info "Using existing cluster"
        exit 0
    fi
fi

echo_info "Creating K3d cluster '$CLUSTER_NAME'..."
echo ""

# Create the cluster
k3d cluster create "$CLUSTER_NAME" \
  --api-port "$API_PORT" \
  --port "${HTTP_PORT}:80@loadbalancer" \
  --port "${HTTPS_PORT}:443@loadbalancer" \
  --servers 1 \
  --agents 0 \
  --wait \
  || echo_error "Failed to create cluster"

echo ""
echo_success "Cluster '$CLUSTER_NAME' created successfully!"
echo ""

# Verify cluster
echo_info "Verifying cluster..."
echo ""

echo "Cluster information:"
kubectl cluster-info

echo ""
echo "Nodes:"
kubectl get nodes

echo ""
echo "System pods:"
kubectl get pods -A

echo ""
echo "=========================================="
echo " Cluster Setup Complete!"
echo "=========================================="
echo ""
echo_info "Cluster details:"
echo "  - Name: $CLUSTER_NAME"
echo "  - API Port: $API_PORT"
echo "  - HTTP Port: $HTTP_PORT (host) → 80 (cluster)"
echo "  - HTTPS Port: $HTTPS_PORT (host) → 443 (cluster)"
echo "  - Servers: 1"
echo "  - Agents: 0"
echo ""
echo_info "Next steps:"
echo "  1. Run: ./setup-argocd.sh"
echo "  2. Run: ./setup-dev.sh"
echo ""