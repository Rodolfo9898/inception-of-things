# Part 3: K3d and Argo CD

GitOps-based continuous deployment using K3d and Argo CD.

---

## What You're Building

```
┌────────────────────────────────────────────────────────────────┐
│                     Your Machine (no VMs!)                     │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                 K3d Cluster (Docker)                     │  │
│  │                                                          │  │
│  │  ┌──────────────────────┐    ┌───────────────────────┐   │  │
│  │  │   argocd namespace   │    │    dev namespace      │   │  │
│  │  │                      │    │                       │   │  │
│  │  │  Argo CD server      │    │  Your app (v1 or v2)  │   │  │
│  │  │  Argo CD repo-server │    │  Deployed by Argo CD  │   │  │
│  │  │  Argo CD controller  │    │                       │   │  │
│  │  └──────────┬───────────┘    └───────────────────────┘   │  │
│  │             │                          ▲                 │  │
│  │             │  watches & deploys       │                 │  │
│  │             └──────────────────────────┘                 │  │
│  └──────────────────────────────────────────────────────────┘  │
│                          │                                     │
│                          │ watches (polls every ~3 min)        │
│                          ▼                                     │
│                 ┌─────────────────┐                            │
│                 │ GitHub Repo.    │                            │
│                 │ (K8s manifests) │                            │
│                 └─────────────────┘                            │
└────────────────────────────────────────────────────────────────┘
```

---

## Key Differences from Part 1 and Part 2

| Aspect | Part 1/2 | Part 3 |
|--------|----------|--------|
| Virtualization | Vagrant + VirtualBox (VMs) | Docker + K3d (containers acting as nodes) |
| Cluster | K3s on VMs (minutes to start) | K3s in Docker containers (seconds to start) |
| Deployment | Manual `kubectl apply -f` | Automatic via Argo CD (GitOps) |
| Config management | Files on VM via synced folder | Git repository (source of truth) |

---

## Key Files

- `scripts/install.sh` — Installs Docker, kubectl, and K3d on the host
- `scripts/setup-cluster.sh` — Creates the K3d cluster
- `scripts/setup-argocd.sh` — Installs Argo CD into the cluster
- `scripts/setup-dev.sh` — Creates the `dev` namespace
- `confs/deployment.yaml` — App Deployment (image: v1 or v2)
- `confs/service.yaml` — App Service
- `confs/ingress.yaml` — App Ingress

---

## Core Concepts

### K3d vs K3s

| | K3s (Part 1/2) | K3d (Part 3) |
|---|---|---|
| Runs inside | VMs (VirtualBox) | Docker containers |
| Needs | Vagrant + VirtualBox | Docker only |
| Startup time | Minutes | Seconds |
| Use case | Production-like, edge | Development, testing, CI/CD |

K3d creates Docker containers that each pretend to be a K3s node. From
Kubernetes' perspective, it looks exactly like a normal cluster. But under
the hood, each "node" is just a Docker container, not a full VM.

```
# Part 1/2:
Your Mac → VirtualBox → VM → K3s

# Part 3:
Your Mac → Docker → Container → K3s
```

### Namespace

A namespace is a way to partition a single cluster into virtual sub-clusters.
Like folders on a filesystem — resources in different namespaces are isolated
from each other by default.

Part 3 uses two namespaces:
- **`argocd`**: Contains Argo CD itself (the GitOps controller)
- **`dev`**: Contains your application (deployed BY Argo CD)

This separation keeps the tooling (Argo CD) and the application (your app)
in different "rooms" so they don't interfere. You can have resources with
the same name in different namespaces.

```bash
kubectl get pods -n argocd    # Argo CD pods
kubectl get pods -n dev       # Your app pods
kubectl get ns                # List all namespaces
```

### GitOps

A deployment approach where **Git is the single source of truth**:

1. All your Kubernetes manifests (YAML files) live in a Git repository
2. A tool (Argo CD) watches that repository
3. When you push a change (e.g., update image from `v1` to `v2`), Argo CD
   detects it and automatically updates the running application
4. The cluster state always matches what's in Git

**Why is this useful?**
- Audit trail: every change is a Git commit (who changed what, when, why)
- Rollback: just `git revert` to undo a deployment
- No manual `kubectl apply`: everything is automated
- Multiple environments: just point Argo CD at different branches

**Traditional** deployment: developer runs `kubectl apply` manually.
**GitOps** deployment: developer pushes to Git, Argo CD applies automatically.

### Argo CD

A GitOps tool for Kubernetes. It has three main components:

1. **API Server**: Provides the web UI and REST API
2. **Repo Server**: Clones and reads Git repositories
3. **Application Controller**: Watches the cluster state and compares it to Git

**How it works:**
1. You tell Argo CD: "Watch this Git repo, deploy into this namespace"
2. Argo CD clones the repo and reads the Kubernetes manifests
3. It applies them to the cluster (creates Deployments, Services, etc.)
4. It polls the repo every ~3 minutes for changes
5. When a change is detected, it re-applies the updated manifests

**Argo CD Web UI**: Accessible via port-forward. Shows the application status,
sync state, and resource tree visually. Username: `admin`, password: retrieved
from a Kubernetes secret.

### Continuous Deployment (CD)

The "CD" in CI/CD. Means changes that pass tests are automatically deployed
to production (or staging). In Part 3:

- You push a change to the Git repo (e.g., update `image: v1` to `image: v2`)
- Argo CD detects the change
- Argo CD applies the new manifest
- The Deployment updates: Kubernetes rolls out new pods with the v2 image
- Old v1 pods are terminated

This happens without anyone running any manual commands.

---

## How Part 3 Works Step by Step

### Step 1: install.sh

Installs the prerequisite tools on the host machine:
- **Docker**: Required to run K3d (since K3d runs K3s in Docker containers)
- **kubectl**: To interact with the cluster
- **K3d**: To create the cluster

### Step 2: setup-cluster.sh

Creates a K3d cluster:

```bash
k3d cluster create iot-cluster \
  --api-port 6550 \                          # K8s API at localhost:6550
  --port "8080:80@loadbalancer" \             # HTTP: localhost:8080 → cluster:80
  --port "8443:443@loadbalancer" \            # HTTPS: localhost:8443 → cluster:443
  --servers 1 \                               # 1 server node (in a container)
  --agents 0                                  # No separate worker (server does both)
```

The `--port` flags map your host ports to the cluster's internal ports via
K3d's built-in load balancer. So `http://localhost:8080` reaches apps in
the cluster.

### Step 3: setup-argocd.sh

1. Creates the `argocd` namespace
2. Installs Argo CD from the official manifest (a large YAML with many resources)
3. Waits for the Argo CD server to be ready
4. Prints the admin password and port-forward command

After this, you can access the Argo CD UI at `https://localhost:8081` (via
port-forward).

### Step 4: setup-dev.sh

Creates the `dev` namespace where your application will be deployed.

### Step 5: Configure Argo CD Application

You tell Argo CD to watch a GitHub repo and deploy into the `dev` namespace.
This can be done via the UI or CLI. Argo CD then:
1. Reads `deployment.yaml`, `service.yaml`, `ingress.yaml` from the repo
2. Applies them to the `dev` namespace
3. Starts polling for changes

### Step 6: Update and watch

Push a change to the Git repo (e.g., change `image: mvan-pee/iot-app:v1`
to `image: mvan-pee/iot-app:v2`). Argo CD detects the diff and rolls out
the new version automatically.

---

## The confs/ Files

### deployment.yaml

Same concept as Part 2 Deployments, but with extra features:

- **`namespace: dev`**: Deployed into the `dev` namespace (not `default`)
- **`imagePullPolicy: Always`**: Always pull the latest image (important for
  GitOps — ensures the right version is running)
- **`resources`**: CPU and memory limits (best practice for production)
- **`livenessProbe`**: Kubernetes checks `/health` every 10s. If it fails 3
  times, the container is restarted.
- **`readinessProbe`**: Similar check but controls whether the pod receives
  traffic. If not ready, the Service stops sending requests to it.

### service.yaml

Same as Part 2 — a ClusterIP Service that gives the pods a stable address.
Port 8888 on both sides (Service and pod use the same port here).

### ingress.yaml

Same concept as Part 2 — routes HTTP traffic to the Service. No host-based
routing here (just a catch-all path `/`), since there's only one app.

---

## Understanding Check (with answers)

### Q: What's the difference between K3s and K3d?
K3s runs in VMs (or bare metal). K3d runs K3s inside Docker containers.
Same Kubernetes API, different runtime environment. K3d is lighter and
faster to start (seconds vs minutes).

### Q: What is a namespace and why do we have two?
A namespace partitions the cluster. `argocd` holds the GitOps tool itself,
`dev` holds the application. Separation keeps tooling and application
isolated — they can have resources with the same name without conflicts.

### Q: What is GitOps? Why is it useful?
Git is the single source of truth. All changes go through Git, giving you
audit trail, rollback capability, and automated deployment. No more manual
`kubectl apply`.

### Q: If I push a change to GitHub, what happens automatically?
Argo CD polls the repo (~3 min interval), detects the change in the manifest,
computes the diff between desired state (Git) and actual state (cluster),
and applies the update. Kubernetes then rolls out new pods.

### Q: What's the difference between v1 and v2 of the application?
They're different Docker image tags. The actual difference depends on what
the image author changed. In the deployment manifest, you change
`image: mvan-pee/iot-app:v1` to `image: mvan-pee/iot-app:v2`. Argo CD
detects this change and triggers a rolling update.

### Q: What is a rolling update?
When a Deployment's image changes, Kubernetes doesn't kill all pods at once.
It creates new pods (v2), waits for them to be ready, then terminates old
pods (v1) one by one. This ensures zero downtime.

### Q: How do you access the Argo CD UI?
Port-forward the Argo CD server to your host:
```bash
kubectl port-forward -n argocd svc/argocd-server 8081:443
```
Then open `https://localhost:8081`. Username: `admin`. Password:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

---

## Commands You Should Know

```bash
# Cluster management (K3d)
k3d cluster list                    # List clusters
k3d cluster create <name>          # Create cluster
k3d cluster delete <name>          # Delete cluster

# Namespace operations
kubectl get ns                      # List namespaces
kubectl get pods -n argocd          # Argo CD pods
kubectl get pods -n dev             # App pods
kubectl get all -n dev              # All resources in dev

# Argo CD
kubectl port-forward -n argocd svc/argocd-server 8081:443  # Access UI
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d               # Get password

# Verify deployment
kubectl get deployments -n dev      # Check app deployment
kubectl describe deployment -n dev  # Detailed view
kubectl logs -n dev <pod-name>      # Check app logs
```

---

## What the Evaluator Will Check

1. **K3d is installed** and a cluster is running (not K3s on a VM)
2. **Two namespaces exist**: `argocd` and `dev` (`kubectl get ns`)
3. **Argo CD is running** in the `argocd` namespace (`kubectl get pods -n argocd`)
4. **An application is deployed** in the `dev` namespace (`kubectl get pods -n dev`)
5. **Argo CD UI** is accessible and shows the application
6. **Update demo**: Change the image version in the Git repo (v1 → v2),
   show that Argo CD detects it and updates the running application
7. You can **explain**: What is GitOps? What is Argo CD? What is K3d?
   What is continuous integration/deployment?
