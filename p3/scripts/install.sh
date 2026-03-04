#!/bin/bash

set -euo pipefail

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Helper functions
echo_success() { echo -e "${GREEN}✓ $1${NC}"; }
echo_error() { echo -e "${RED}✗ $1${NC}"; exit 1; }
echo_info() { echo -e "${BLUE}ℹ $1${NC}"; }
echo_warn() { echo -e "${YELLOW}⚠ $1${NC}"; }

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo_error "Please run as root (sudo ./install.sh)"
    fi
}

# Get the actual user (not root when using sudo)
get_actual_user() {
    ACTUAL_USER=${SUDO_USER:-$USER}
    echo_info "Installing for user: $ACTUAL_USER"
}

# Step 1: Update system packages
update_system() {
    echo ""
    echo "[1/6] Updating system packages..."
    apt-get update -qq || echo_error "Failed to update package list"
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq || echo_warn "Some packages failed to upgrade"
    echo_success "System updated"
}

# Step 2: Install Docker
install_docker() {
    echo ""
    echo "[2/6] Installing Docker..."

    # Remove old versions
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    # Install dependencies
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        git \
        jq \
        2>/dev/null || echo_error "Failed to install dependencies"

    # Add Docker GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null || \
        echo_error "Failed to add Docker GPG key"
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Add Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker Engine
    apt-get update -qq
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
        2>/dev/null || echo_error "Failed to install Docker"

    # Configure Docker permissions
    usermod -aG docker "$ACTUAL_USER" || echo_warn "Failed to add user to docker group"
    systemctl enable docker 2>/dev/null || true
    systemctl start docker || echo_error "Failed to start Docker"

    echo_success "Docker installed"
}

# Step 3: Install kubectl
install_kubectl() {
    echo ""
    echo "[3/6] Installing kubectl..."

    KUBECTL_VERSION="v1.28.0"

    # Download kubectl
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
        2>/dev/null || echo_error "Failed to download kubectl"

    # Install kubectl
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl

    # Setup bash completion
    kubectl completion bash > /etc/bash_completion.d/kubectl 2>/dev/null || true

    echo_success "kubectl installed (${KUBECTL_VERSION})"
}

# Step 4: Install k3d
install_k3d() {
    echo ""
    echo "[4/6] Installing k3d..."

    # Download and install k3d
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash \
        || echo_error "Failed to install k3d"

    # Setup bash completion
    k3d completion bash > /etc/bash_completion.d/k3d 2>/dev/null || true

    echo_success "k3d installed"
}

# Step 5: Verify installations
verify_installations() {
    echo ""
    echo "[5/6] Verifying installations..."

    echo_info "Docker version:"
    docker --version || echo_error "Docker verification failed"

    echo_info "kubectl version:"
    kubectl version --client --short 2>/dev/null || kubectl version --client || echo_error "kubectl verification failed"

    echo_info "k3d version:"
    k3d version || echo_error "k3d verification failed"

    echo_success "All tools verified"
}

# Print completion message
print_completion() {
    echo ""
    echo "=========================================="
    echo " Installation completed successfully!"
    echo "=========================================="
    echo ""
    echo_info "Next steps:"
    echo "  1. Run: newgrp docker"
    echo "  2. Run: ./setup-cluster.sh"
    echo ""
}

# Main execution
main() {
    check_root
    get_actual_user
    update_system
    install_docker
    install_kubectl
    install_k3d
    verify_installations
    print_completion
}

# Run main function
main "$@"
