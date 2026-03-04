# Defense Q&A

Common questions evaluators ask, and how to answer them. Organized by topic.

---

## General Questions

### "Explain the basic operation of Vagrant"

Vagrant automates VM creation. You write a `Vagrantfile` (a recipe in Ruby)
that describes the VM: which OS image (box), how much RAM, which IP, and
what scripts to run on first boot (provisioning). `vagrant up` creates the VM,
`vagrant ssh` connects to it, `vagrant destroy` deletes it. The key benefit is
reproducibility — every team member gets an identical environment from the same
Vagrantfile.

### "Explain the basic operation of K3s"

K3s is a lightweight Kubernetes distribution. It's a single binary that includes
everything: API server, scheduler, controller manager, etcd, kubelet, and even
kubectl. You install it with one command (`curl -sfL https://get.k3s.io | sh`).
It can run as a **server** (control plane — the brain) or **agent** (worker —
the muscle). In Part 1 we have both; in Part 2, one node does both roles.

### "Explain the basic operation of K3d"

K3d runs K3s inside Docker containers instead of VMs. Each "node" is a Docker
container pretending to be a server. Same Kubernetes API, much faster to start
(seconds vs minutes). Used in Part 3 for local development with Argo CD.

### "What is Kubernetes?"

A system for running and managing containers across machines. You declare what
you want (e.g., "run 3 copies of this app") and Kubernetes handles scheduling,
restarting crashed containers, load balancing, and networking. K3s is a
lightweight implementation of Kubernetes.

### "What is continuous integration and Argo CD?"

**Continuous Integration (CI)**: Automatically building and testing code when
changes are pushed (e.g., run tests on every pull request).

**Continuous Deployment (CD)**: Automatically deploying code after it passes CI.

**Argo CD**: A GitOps CD tool for Kubernetes. It watches a Git repository
containing Kubernetes manifests. When you push a change (e.g., update an image
tag), Argo CD detects it and automatically updates the running application.
Git becomes the single source of truth.

---

## Part 1 Questions

### "Show me the two virtual machines"

```bash
vagrant status
# Output shows two VMs: rperez-tS (running) and rperez-tSW (running)
```

### "Show me that both machines are in the same cluster"

SSH into the server VM and run:
```bash
vagrant ssh rperez-tS
kubectl get nodes -o wide
```

Expected output:
```
NAME         STATUS   ROLES                  AGE   VERSION         INTERNAL-IP
rperez-tS    Ready    control-plane,master   10m   v1.27.3+k3s1   192.168.56.110
rperez-tSW   Ready    <none>                 8m    v1.27.3+k3s1   192.168.56.111
```

### "Explain the output of `kubectl get nodes -o wide`"

- **NAME**: The hostname we set in the Vagrantfile
- **STATUS: Ready**: The node is healthy and communicating with the API server
- **ROLES: control-plane,master**: This is the server node (brain of the cluster)
- **ROLES: `<none>`**: This is the worker/agent node (no special role label)
- **VERSION**: K3s version installed
- **INTERNAL-IP**: The private network IPs we configured (192.168.56.110/111)

### "How does the worker join the cluster?"

1. The server generates a join token at `/var/lib/rancher/k3s/server/node-token`
2. `master.sh` copies it to `/vagrant/token` (synced folder = shared with host)
3. `worker.sh` reads `/vagrant/token` and passes it to the K3s agent install
4. The agent connects to the server at `https://192.168.56.110:6443` with the
   token as authentication
5. The server accepts the agent into the cluster
6. `worker.sh` deletes the token file (security)

### "Why are there two IPs configured?"

The VMs have two network interfaces:
- **NAT** (default): For internet access. VMs are isolated from each other.
- **Private network** (192.168.56.x): For VM-to-VM and host-to-VM communication.
  Required because the worker must reach the server's API at port 6443.

---

## Part 2 Questions

### "Show me the Ingress"

```bash
kubectl get ingress -o wide
kubectl describe ingress app-ingress
# or from Makefile: make ingress
```

The output shows the routing rules: `app1.com` → `app-one`, `app2.com` → `app-two`,
default → `app-three`.

### "Explain how the routing works"

1. HTTP request arrives at `192.168.56.110:80`
2. Traefik (K3s's built-in Ingress Controller, listening on port 80) receives it
3. Traefik reads the `Host` header from the request
4. Traefik checks the Ingress rules:
   - `Host: app1.com` → forward to Service `app-one:80`
   - `Host: app2.com` → forward to Service `app-two:80`
   - No host match → forward to Service `app-three:80` (catch-all)
5. The Service translates port 80 to the pod's port 8080
6. The pod's `http-echo` container returns the response

### "Why does app-two have 3 replicas?"

The subject requires it. Practically: it demonstrates Kubernetes' ability to
run multiple identical copies of an app. The Service load-balances across all 3
replicas. If one pod dies, the Deployment creates a replacement to maintain 3.

### "Show me the 3 applications responding differently"

```bash
curl -H "Host: app1.com" http://192.168.56.110
# → "Hello from app one"

curl -H "Host: app2.com" http://192.168.56.110
# → "Hello from app two"

curl http://192.168.56.110
# → "Hello from app three"

# or: make test
```

### "What is a Deployment?"

A Deployment tells Kubernetes: "Run N copies of this container and keep them
alive." If a pod crashes, the Deployment creates a replacement. You declare
the desired state (which image, how many replicas) and Kubernetes makes it
happen. You never create pods directly — you create Deployments.

### "What is a Service?"

A Service gives a stable network address to a group of pods. Pods are
ephemeral — they get new IPs when they restart. A Service provides a fixed
name and IP that always routes to healthy pods. Without it, the Ingress
wouldn't know where to send traffic.

### "What is the Ingress Controller?"

The software that implements Ingress rules. The Ingress resource is just data
(rules). The Ingress Controller (Traefik in our case) is the actual reverse
proxy that reads those rules and routes traffic accordingly. Like a recipe
(Ingress) vs the chef (Controller).

### "What is ClusterIP?"

A Service type that's only reachable from inside the cluster. External traffic
can't hit it directly. That's why we need the Ingress + Traefik to expose
apps to the outside world.

### "What does `port: 80` vs `targetPort: 8080` mean?"

- `port: 80`: What the Service listens on (what the Ingress connects to)
- `targetPort: 8080`: What the pod actually listens on (where http-echo runs)
- The Service translates between them: Ingress → Service:80 → Pod:8080

### "What is `ingressClassName: traefik`?"

Tells Kubernetes which Ingress Controller should handle these rules. Traefik
is K3s's built-in controller. If you had multiple controllers, this selects
which one processes the Ingress.

---

## Part 3 Questions

### "Show me the two namespaces"

```bash
kubectl get ns
# Shows: argocd, dev (among default ones like kube-system, default)
```

### "What's the difference between a namespace and a pod?"

A **namespace** is a virtual partition of the cluster — like a folder. It groups
related resources.

A **pod** is a running instance of a container — the smallest deployable unit.

They're at completely different levels: namespaces organize, pods execute.

### "Show me the Argo CD interface"

```bash
# Start port-forward (if not already running):
kubectl port-forward -n argocd svc/argocd-server 8081:443

# Get the admin password:
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

Open `https://localhost:8081` in browser. Login: `admin` / (password from above).
The UI shows the application, its sync status, and the resource tree (Deployment,
Service, pods, etc.).

### "Update the application from v1 to v2"

1. Open the deployment manifest in the Git repository
2. Change `image: mvan-pee/iot-app:v1` to `image: mvan-pee/iot-app:v2`
3. Commit and push to GitHub
4. Wait for Argo CD to detect the change (~3 minutes, or click "Refresh" in UI)
5. Argo CD shows "OutOfSync" → then syncs automatically (or click "Sync")
6. Kubernetes performs a rolling update: new v2 pods start, old v1 pods terminate

### "Explain how the automatic update works"

1. Argo CD polls the Git repository every ~3 minutes
2. It compares the manifests in Git (desired state) with what's running in the
   cluster (actual state)
3. If there's a difference (e.g., image tag changed), Argo CD marks the app
   as "OutOfSync"
4. Argo CD applies the updated manifests to the cluster
5. The Deployment detects the image change and triggers a **rolling update**:
   - Creates new pods with the v2 image
   - Waits for them to pass readiness checks
   - Terminates old v1 pods
6. Zero downtime throughout the process

### "What is GitOps?"

An approach where Git is the single source of truth for infrastructure. You
store Kubernetes manifests in Git, and a tool (Argo CD) ensures the cluster
matches what's in Git. Benefits: audit trail (every change is a commit),
easy rollback (`git revert`), automated deployment (no manual `kubectl`).

---

## Gotcha Questions

### "What happens if I delete a pod?"

The Deployment immediately creates a new one to replace it. Deployments maintain
the desired replica count. Try it:
```bash
kubectl delete pod <pod-name>
kubectl get pods  # A new pod appears immediately
```
This demonstrates Kubernetes' self-healing capability.

### "What's the difference between a Deployment and a Pod?"

A Pod is a single running container. If it dies, it's gone forever.

A Deployment manages pods: it creates them, monitors them, and replaces them
if they crash. Self-healing is the key difference. You always create Deployments,
never raw pods.

### "Why use Traefik instead of NGINX Ingress?"

K3s includes Traefik by default — no installation needed. The subject doesn't
mandate a specific Ingress Controller, just that routing works by Host header.
Traefik is simpler for K3s since it's already there. NGINX Ingress would also
work but requires separate installation and configuration.

### "What is Docker? What is a container?"

**Docker**: A tool for building and running containers. You write a Dockerfile,
build an image, and run it. (In Kubernetes, `containerd` actually runs the
containers, not Docker — but the image format is the same.)

**Container**: A lightweight, isolated process that shares the host OS kernel.
Unlike a VM, it doesn't virtualize hardware. Much lighter (MBs vs GBs).

### "What is the difference between a VM and a container?"

| | VM | Container |
|---|---|---|
| Isolation | Full OS + virtual hardware | Shared kernel, isolated filesystem/network |
| Size | GBs (full OS) | MBs (just the app + dependencies) |
| Startup | Minutes | Seconds |
| Use case | Strong isolation, different OS | Lightweight, fast, same kernel |

Part 1/2 use VMs (VirtualBox). Part 3 uses containers (Docker + K3d).

### "What is port 6443?"

The default port for the Kubernetes API server. All `kubectl` commands and
all agent-to-server communications go through this port.

### "What is a kubeconfig?"

A YAML file that tells `kubectl` where the cluster is and how to authenticate.
Contains: server address, TLS certificate, and user credentials. In Part 2,
K3s generates it at `/etc/rancher/k3s/k3s.yaml`. We copy it to the host and
rewrite `127.0.0.1` to `192.168.56.110` so `kubectl` can reach the VM's API
from your Mac.
