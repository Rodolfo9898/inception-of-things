# Part 2: K3s + 3 apps + Ingress (Traefik)
#
# NOTE: curl/kubectl commands must be run from a regular terminal (iTerm2,
# Terminal.app), NOT from Cursor's integrated terminal (sandbox blocks
# network access to VMs).

# Automatically set KUBECONFIG for all kubectl targets below.
# KUBECONFIG tells kubectl where the cluster is and how to authenticate.
# k3s.yaml is copied from the VM to this directory by bootstrap.sh.
# Without this, kubectl wouldn't know which cluster to talk to.
export KUBECONFIG := $(shell pwd)/k3s.yaml

up:
	vagrant up

halt:
	vagrant halt

destroy:
	vagrant destroy -f
	rm -rf .vagrant

ssh:
	vagrant ssh

re: destroy up

# Send HTTP requests to the VM's IP with different Host headers.
# Traefik reads the Host header and routes to the matching app.
# -s = silent (no progress bar), -H = set header.
test:
	@echo "=== app1.com -> app one ==="
	@curl -s -H "Host: app1.com" http://192.168.56.110
	@echo ""
	@echo "=== app2.com -> app two ==="
	@curl -s -H "Host: app2.com" http://192.168.56.110
	@echo ""
	@echo "=== default -> app three ==="
	@curl -s http://192.168.56.110

# ── kubectl commands ─────────────────────────────────────────────────────────
# These query the Kubernetes API server running inside the VM.
# KUBECONFIG (set above) handles authentication and connection.
# -o wide = show extra columns (IPs, nodes, etc.)

# Show Ingress routing rules.
# `describe` shows the full rule details (which host -> which service -> which pods).
ingress:
	kubectl get ingress -o wide
	kubectl describe ingress app-ingress

# Show Deployments: how many replicas are desired vs ready.
# app-two should show 3/3 ready.
deployments:
	kubectl get deployments -o wide

# Show individual running pods. app-two should have 3 pods listed.
# Each pod has a unique name like app-two-abc123.
pods:
	kubectl get pods -o wide

# Show Services: the stable network addresses for each app.
# Each Service has a ClusterIP (internal only) and maps port 80 -> 8080.
services:
	kubectl get services -o wide

# Show cluster nodes. Part 2 has only 1 node (server doing both roles).
nodes:
	kubectl get nodes -o wide

all: nodes deployments pods services ingress

.PHONY: up halt destroy ssh re test ingress deployments pods services nodes all
