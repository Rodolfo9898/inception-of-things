#!/bin/bash

set -euo pipefail

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo_success() { echo -e "${GREEN}✓ $1${NC}"; }
echo_error() { echo -e "${RED}✗ $1${NC}"; exit 1; }
echo_info() { echo -e "${BLUE}ℹ $1${NC}"; }
echo_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }

echo ""
echo "=========================================="
echo " Dev Namespace Setup"
echo "=========================================="
echo ""

# Check if cluster exists
if ! kubectl cluster-info &> /dev/null; then
    echo_error "Kubernetes cluster not found. Run setup-cluster.sh first."
fi

# Create dev namespace
echo_info "Creating dev namespace..."
if kubectl get namespace dev &> /dev/null; then
    echo_warning "Namespace 'dev' already exists"
else
    kubectl create namespace dev || echo_error "Failed to create dev namespace"
    echo_success "Namespace 'dev' created"
fi
echo ""

# Get VM IP
VM_IP=$(hostname -I | awk '{print $1}')

echo "=========================================="
echo " Dev Namespace Setup Complete!"
echo "=========================================="
