# Prerequisites

Base knowledge needed before starting this project.

---

## Virtual Machines vs Containers

**Virtual Machine**: Virtualizes everything - RAM, CPU, network card, disk. Has its
own complete OS. Heavy (GBs). Fully isolated. Created by a hypervisor (VirtualBox).

**Container**: Runs on top of the host OS kernel. Shares the kernel but isolates
filesystem, network, and processes. Lightweight (MBs). Uses OCI standard format.

```
VM approach:                     Container approach:
┌─────────┐ ┌─────────┐        ┌─────────┐ ┌─────────┐
│  App A  │ │  App B  │        │  App A  │ │  App B  │
├─────────┤ ├─────────┤        ├─────────┤ ├─────────┤
│ Guest OS│ │ Guest OS│        │ Bin/Lib │ │ Bin/Lib │
├─────────┤ ├─────────┤        └────┬────┘ └────┬────┘
│  Virtl. │ │  Virtl. │             │           │
│ Hardware│ │ Hardware│        ┌────┴───────────┴─────┐
└────┬────┘ └────┬────┘        │   Container Runtime  │
     │           │             ├──────────────────────┤
┌────┴───────────┴─────┐       │       Host OS        │
│     Hypervisor       │       ├──────────────────────┤
├──────────────────────┤       │      Hardware        │
│      Host OS         │       └──────────────────────┘
├──────────────────────┤
│      Hardware        │
└──────────────────────┘
```

**Why does Kubernetes only run containers?**
Kubernetes manages container images pulled from registries (like Docker Hub). You
can't just serve a static HTML file - you need to package it inside a container
image (e.g., an nginx image with your HTML). The image is then pushed to a
registry, and Kubernetes pulls it when creating pods.

**Are Docker containers the same as K8s containers?**
Yes - same OCI image format. Docker builds images, but Kubernetes uses `containerd`
(not Docker) to run them. The images are interchangeable.

**Architecture matters**: An image built for x86 (amd64) won't run on ARM64 - you
get "exec format error" (exit code 255). Use multi-arch images when possible.

---

## Why Kubernetes?

Imagine you have a web app:
- Without K8s: You SSH into a server, run your app manually, hope it doesn't crash.
  If traffic spikes, you're stuck. If the server dies, your app dies.
- With K8s: You tell it "run 3 copies" and it handles placement, restarts, load
  balancing. Need more? Change `replicas: 3` to `replicas: 10`.

---

## Networking Basics

- **IP address**: A machine's address on a network (e.g., `192.168.56.110`)
- **Port**: A "door" on that machine (e.g., `:80` for HTTP, `:443` for HTTPS)
- **HTTP**: The protocol browsers use to request web pages
- **Host header**: Tells the server which website you want (how one IP can serve
  multiple sites)

Example: `curl -H "Host: app1.com" http://192.168.56.110`
- `curl` - command-line HTTP client
- `-H "Host: app1.com"` - send this Host header (pretend we're visiting app1.com)
- `http://` - use HTTP protocol
- `192.168.56.110` - connect to this IP on port 80 (default for HTTP)

---

## Tools You Need

### On your Mac (host)
- **Vagrant** - creates VMs (`brew install --cask vagrant`)
- **VirtualBox** - hypervisor that runs VMs (`brew install --cask virtualbox`)
- **kubectl** - K8s CLI, to run commands from host (`brew install kubectl`)
  - Requires setting `export KUBECONFIG=path/to/k3s.yaml`
  - The `k3s.yaml` is copied from the VM during bootstrap
  - It contains the cluster address and credentials

### Inside the VM (installed by bootstrap scripts)
- **K3s** - lightweight Kubernetes (includes kubectl)
- **NGINX Ingress Controller** - routes HTTP traffic to apps
