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

ARGOCD_VERSION="v2.9.3"

echo ""
echo "=========================================="
echo " Argo CD Setup"
echo " Version: $ARGOCD_VERSION"
echo "=========================================="
echo ""

# Check if cluster exists
if ! kubectl cluster-info &> /dev/null; then
    echo_error "Kubernetes cluster not found. Run setup-cluster.sh first."
fi

# Step 1: Create argocd namespace
echo_info "[1/5] Creating argocd namespace..."
if kubectl get namespace argocd &> /dev/null; then
    echo_warning "Namespace 'argocd' already exists"
else
    kubectl create namespace argocd || echo_error "Failed to create argocd namespace"
    echo_success "Namespace 'argocd' created"
fi
echo ""

# Step 2: Install Argo CD
echo_info "[2/5] Installing Argo CD..."
if kubectl get deployment argocd-server -n argocd &> /dev/null 2>&1; then
    echo_warning "Argo CD already installed"
else
    kubectl apply -n argocd -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml" \
        || echo_error "Failed to install Argo CD"
    echo_success "Argo CD installed"
fi
echo ""

# Step 3: Wait for Argo CD to be ready
echo_info "[3/5] Waiting for Argo CD to be ready (this may take 1-2 minutes)..."
kubectl wait --for=condition=available --timeout=300s \
    deployment/argocd-server -n argocd \
    || echo_warning "Timeout waiting for Argo CD (it may still be starting)"
echo_success "Argo CD is ready"
echo ""

# Get VM IP
VM_IP=$(hostname -I | awk '{print $1}')

echo "=========================================="
echo " Argo CD Setup Complete!"
echo "=========================================="
echo ""
echo "  Argo CD UI: URL: https://${VM_IP}:8081/"
echo ""
echo "Username: admin"
echo -n "Password: "
kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" 2>/dev/null | base64 -d
echo ""
echo_info "kubectl port-forward -n argocd --address 0.0.0.0 svc/argocd-server 8081:443"
echo ""
