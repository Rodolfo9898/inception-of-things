# Glossary

Quick definitions of all terms used in this project.

## Useful Links

- [Vagrant Box Registry](https://portal.cloud.hashicorp.com/vagrant/discover) — search for Vagrant boxes
- [Docker Hub](https://hub.docker.com/) — search for container images
- [K3s Documentation](https://docs.k3s.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
- [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [Argo CD Documentation](https://argo-cd.readthedocs.io/en/stable/)

---

## Infrastructure & Virtualization

### Vagrant

A tool that automates creating and configuring virtual machines. Instead of
manually clicking through VirtualBox to create a VM, install an OS, and configure
networking, you write a `Vagrantfile` (a recipe) and run `vagrant up`. One command
does everything. Key benefit: reproducible environments - every team member gets
an identical VM.

A Vagrantfile is written in the Ruby programming language.

### VirtualBox

A hypervisor - software that creates and runs virtual machines on your computer.
Think of it as the "engine" that Vagrant uses to actually create the VMs.
Other hypervisors exist (VMware, Parallels, QEMU).

### Virtual Machine (VM)

A complete virtualized computer with its own OS, virtual RAM, virtual CPU, virtual
network card, etc. It runs on top of a hypervisor. Heavy (GBs of RAM) but fully
isolated. In this project: Vagrant creates VMs in VirtualBox where we install K3s.

### Container

A lightweight, isolated process that shares the host OS kernel. Unlike a VM, it
doesn't virtualize hardware - it just isolates the filesystem, network, and process
space. Much lighter than a VM (MBs vs GBs). Uses the OCI standard format, meaning
Docker-built images work in Kubernetes and vice versa.

What is the OCI standard format?
<!-- TODO: Define -->

### Docker

A tool for building and running containers. You write a `Dockerfile`, build an
image, and push it to a registry (like Docker Hub). Kubernetes doesn't actually
use Docker to run containers - it uses `containerd` directly - but the image
format is the same. Think of Docker as the "kitchen" where images are built, and
`containerd` as the "microwave" that runs them.

### Container Image

Like a `.zip` of a filesystem plus a command to run. Built with `docker build`,
stored in a registry (Docker Hub, GitHub Container Registry, etc.), and pulled by
Kubernetes when it needs to run a pod. Images are architecture-specific - an
amd64 image won't run on ARM64 (you get "exec format error"). Multi-arch images
support both.

### Container Registry

A repository for container images (like GitHub for code, but for images). Docker
Hub is the most common public registry. When a Kubernetes manifest says
`image: nginx:alpine`, K8s pulls that image from Docker Hub.

---

## Kubernetes Core Concepts

### Kubernetes (K8s)

A system for running and managing containers across multiple machines. Instead of
manually starting/stopping containers, you tell Kubernetes "I want 3 copies of
this app running" and it handles the rest - scheduling, restarting crashed
containers, load balancing, etc. K8s is the abbreviation (K + 8 letters + s).

### K3s

A lightweight Kubernetes distribution by Rancher. Same API as full Kubernetes but
uses less memory/CPU. Ideal for VMs, edge computing, and learning. Single binary
that includes everything. In this project: K3s is what runs inside our VMs.

### K3d

K3s running inside Docker containers instead of VMs. Even lighter - starts in
seconds instead of minutes. Used in Part 3 of this project. K3d creates Docker
containers that each act as a K3s node.

### Cluster

A group of nodes (machines) working together as one system. Has one or more
control plane nodes (the brain) and zero or more worker nodes (the muscle).
In Part 1: 2-node cluster (1 server + 1 worker). In Part 2: single-node
cluster (server only, does both roles).

### OCI (Open Container Initiative)

An industry standard that defines the format for container images. Means
images built by Docker, Podman, Buildah, etc. are all compatible. Kubernetes
can run any OCI-compliant image.
- Spec: https://opencontainers.org/

### Node

A machine (VM or physical) in a Kubernetes cluster. Two types:
- **Control plane (master)**: Runs the API server, scheduler, etc.
- **Worker**: Runs your application pods.
In Part 1, we have one of each. In Part 2, one node does both.

### Pod

The smallest deployable unit in Kubernetes. A pod contains one or more containers.
Usually one container per pod. When you run an app, Kubernetes creates a pod for
it. Pods are ephemeral - they can be killed and recreated at any time.

---

## Kubernetes Workloads

### Deployment

A resource that tells Kubernetes: "Run N copies (replicas) of this container
image, and keep them running." If a pod crashes, the Deployment automatically
creates a new one. You don't create pods directly - you create a Deployment and
it manages the pods for you.

### ReplicaSet

Created automatically by a Deployment. Ensures the desired number of pod replicas
are running at all times. You rarely interact with ReplicaSets directly - the
Deployment manages them.

### Service

Gives a stable network name and IP to a set of pods. Pods can come and go (they
get new IPs when recreated), but a Service provides a fixed address that always
routes to healthy pods. Types:
- **ClusterIP** (default): Only reachable inside the cluster.
- **NodePort**: Exposes on a port on every node.

### Ingress

A set of HTTP routing rules: "If the Host header is `app1.com`, send traffic to
service `app-one`." Ingress is just the rules - it doesn't do the actual routing.
You need an Ingress Controller for that.

### Ingress Controller

The actual reverse proxy that reads Ingress rules and routes traffic. Examples:
NGINX Ingress Controller, Traefik. In this project we use NGINX Ingress (but Traefik, which K3s includes
by default, would also work — the subject doesn't mandate a specific one).

---

## Kubernetes Architecture

### Control Plane (Master)

The "brain" of the cluster. Runs:
- **API Server**: The front door - kubectl talks to this.
- **Scheduler**: Decides which node should run each pod.
- **Controller Manager**: Ensures desired state matches actual state.
- **etcd**: Key-value database storing all cluster state.

### Worker Node

The "muscle" of the cluster. Runs:
- **kubelet**: Agent that receives instructions from the control plane.
- **Container runtime** (`containerd`): Actually runs the containers.

### kubectl

The standard CLI for talking to any Kubernetes cluster. Not K3s-specific.
Commands like `kubectl get pods`, `kubectl apply -f file.yaml`, etc. K3s
includes kubectl, so inside the VM you can use it directly.

### kubeconfig

A YAML file that tells kubectl WHERE the cluster is and HOW to authenticate.
Default location: `~/.kube/config`. In this project, K3s generates one at
`/etc/rancher/k3s/k3s.yaml`. We copy it to the host so we can run kubectl
from our Mac (after setting `export KUBECONFIG=path/to/k3s.yaml`).

The bootstrap script copies it and rewrites `127.0.0.1` to `192.168.56.110`
because inside the VM the API is at localhost, but from the Mac we need to
reach it at the VM's IP.

### Namespace

A way to partition a cluster into virtual sub-clusters. Like folders for your
resources. Default namespace: `default`. In Part 3: `argocd` namespace for
Argo CD, `dev` namespace for the application.

---

## Networking

### ClusterIP

The default Service type. Only reachable from inside the cluster. Pods can talk
to a ClusterIP Service by name (e.g., `http://app-one:80`), but external clients
cannot. That's why we need an Ingress.

### Host Header

An HTTP header that tells the web server which website you're requesting. When
you visit `app1.com` in a browser, it sends `Host: app1.com` in the request.
Our Ingress uses this to decide which app to route to. You can fake it with
curl: `curl -H "Host: app1.com" http://192.168.56.110`.

### Port Forwarding

Mapping a port on the host to a port inside a VM or container. For example,
Vagrant forwards port 22 (SSH) on the VM to port 2222 on your Mac, so
`vagrant ssh` connects to `localhost:2222` which reaches the VM's port 22.

### hostPort

A Kubernetes concept where a container port is directly exposed on the node's
IP. Traefik (K3s' default ingress controller) uses hostPort 80/443 by default,
meaning traffic to `192.168.56.110:80` goes directly to Traefik, which then
routes it based on the Ingress rules.

---

## GitOps & CI/CD

### GitOps

An approach where Git is the single source of truth for your infrastructure.
You store your Kubernetes manifests in Git, and a tool (like Argo CD)
automatically applies changes when you push. "If it's in Git, it's deployed."

### Continuous Integration (CI)

Automatically building and testing code when changes are pushed. Example:
run tests on every pull request.

### Continuous Deployment (CD)

Automatically deploying code to production after it passes CI. In Part 3:
Argo CD watches GitHub and deploys changes automatically.

### Argo CD

A GitOps tool for Kubernetes. It watches a Git repository containing
Kubernetes manifests. When you push a change (e.g., update image tag from
`v1` to `v2`), Argo CD detects the change and updates the running application.
Has a web UI for visualization.

---

## Project-Specific

### Traefik

An ingress controller that K3s includes by default. In Part 2 we use Traefik
as our Ingress Controller — since K3s ships it out of the box, no extra
installation is needed. The subject only requires "access apps depending on
the HOST", so any controller works.

### NGINX Ingress Controller

An alternative ingress controller. Must be installed manually (K3s doesn't
include it). We chose Traefik for simplicity since K3s bundles it.

### hashicorp/http-echo

The container image used in Part 2 for our three apps. A minimal web server
that returns whatever text you pass via the `-text` flag. Multi-arch
(works on both amd64 and arm64). We use `-listen=:8080` to set the port.
- [Docker Hub page](https://hub.docker.com/r/hashicorp/http-echo)

### Flannel

The default network plugin (CNI) in K3s. It creates a virtual network so pods
on different nodes can talk to each other. The `--flannel-iface` flag tells it
which network interface to use for inter-node communication.
