# Part 2: K3s and Three Applications

Deploying apps with host-based routing using Ingress.

---

## What You're Building

```
┌───────────────────────────────────────────────────────┐
│                    Single VM (msousaS)                │
│                    192.168.56.110                     │
│                                                       │
│  ┌─────────────────────────────────────────────────┐  │
│  │         Traefik Ingress Controller              │  │
│  │         (built into K3s, port 80)               │  │
│  │                                                 │  │
│  │  Host: app1.com  ──► Service ──► app-one (1x)   │  │
│  │  Host: app2.com  ──► Service ──► app-two (3x)   │  │
│  │  Default         ──► Service ──► app-three (1x) │  │
│  └─────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────┘
```

---

## Key Files

- `Vagrantfile` — Single VM definition (1 node does both server + worker roles)
- `scripts/bootstrap.sh` — Installs K3s, waits for Traefik, deploys apps
- `confs/apps.yaml` — 3 Deployments + 3 Services (app-two has 3 replicas)
- `confs/ingress.yaml` — Routing rules: Host header -> Service -> Pod

All files are heavily commented — read them for line-by-line explanations.

---

## What Part 2 Teaches (Beyond Part 1)

Part 1 taught: VMs, K3s installation, server/agent roles, cluster formation.

Part 2 introduces the **application layer** of Kubernetes:
- **Deployments**: Declaring what apps to run and how many copies
- **Services**: Giving pods a stable network address
- **Ingress**: HTTP routing based on Host headers
- **Ingress Controller** (Traefik): The reverse proxy that implements the rules

Part 2 also shows that a single node can be both control plane AND worker —
there's no separate agent VM.

---

## Core Concepts

### Why Only 1 VM?

In Part 1, the server and agent were separate VMs to demonstrate cluster
formation. In Part 2, one VM does both roles. A K3s server node can also run
pods — it's both the brain and the muscle. The subject requires only 1 machine.

### Deployment

Tells Kubernetes: "Run N copies of this container and keep them alive."

- You never create pods directly. You create a Deployment and it manages pods.
- If a pod crashes, the Deployment automatically creates a replacement.
- `replicas: 3` means 3 identical pods running simultaneously.
- The Deployment uses a **selector** (`matchLabels`) to track which pods it owns.

Why not create pods directly? Because raw pods don't self-heal. If a pod dies,
it stays dead. A Deployment watches and recreates them.

### Service

Gives a stable network address to a group of pods.

- Pods are ephemeral: when they restart, they get new IPs.
- A Service provides a fixed internal name/IP that always routes to healthy pods.
- The Service uses a **selector** to find matching pods (same label matching).
- `port: 80` = what the Service listens on (what Ingress connects to).
- `targetPort: 8080` = what the pod actually listens on (where http-echo runs).
- Traffic flow: Ingress -> Service:80 -> Pod:8080
- `ClusterIP` type = only reachable from inside the cluster.

Without a Service, the Ingress has no stable target. Pod IPs change; Service
names don't.

### Ingress

A set of HTTP routing rules. "If Host header is X, send to Service Y."

- Ingress is just data (rules). It doesn't route anything by itself.
- An **Ingress Controller** (Traefik) reads these rules and does the routing.
- `ingressClassName: traefik` tells K8s which controller handles these rules.

### Ingress Controller (Traefik)

The actual reverse proxy that implements Ingress rules.

- K3s includes Traefik by default (runs as a pod in `kube-system` namespace).
- Traefik listens on port 80/443 on the node's IP (via hostPort).
- When a request arrives, Traefik checks the Host header against Ingress rules.
- The subject says "access apps depending on the HOST" — Traefik makes this work.

### The Full Request Journey

When you run `curl -H "Host: app1.com" http://192.168.56.110`:

1. `curl` sends HTTP request to `192.168.56.110:80`
2. Request arrives at the VM's network interface
3. Traefik (listening on port 80 via hostPort) receives it
4. Traefik reads the `Host: app1.com` header
5. Traefik checks its Ingress rules, finds: app1.com -> Service `app-one`
6. Traefik forwards to Service `app-one` on port 80
7. Service translates port 80 -> pod's port 8080
8. Service picks a healthy pod (if multiple replicas, load-balances)
9. Pod's `http-echo` container returns "Hello from app one"
10. Response travels back the same path to `curl`

### The Default Rule (No Host)

The third Ingress rule has no `host:` field. This is the **catch-all**:
any request that doesn't match `app1.com` or `app2.com` goes to `app-three`.
That's why `curl http://192.168.56.110` (no Host header) returns app-three.

### Replicas and Load Balancing

app-two has `replicas: 3`. This means:
- 3 identical pods run simultaneously
- `kubectl get pods` shows 3 pods for app-two
- The Service load-balances across all 3 (round-robin or random)
- If one pod dies, the Deployment creates a replacement (maintaining 3)

---

## Understanding Check (with answers)

### Q: What's the difference between a Deployment and a Pod?
A Pod is a single running instance of a container. A Deployment manages pods:
it creates them, monitors them, and replaces them if they die. You create
Deployments, not pods.

### Q: Why do we need a Service if we already have a Deployment?
The Deployment manages the pods' lifecycle (creation, health). The Service
provides networking (a stable address to reach those pods). They solve
different problems. Without a Service, the Ingress can't route to the pods.

### Q: What's the difference between Ingress and Ingress Controller?
Ingress = the rules (data). Ingress Controller = the software that reads
the rules and does the routing. Like a recipe (Ingress) vs the chef (Controller).

### Q: How does routing work for app1.com?
The Ingress has a rule: `host: app1.com` -> Service `app-one`. Traefik reads
this rule. When a request with `Host: app1.com` arrives, Traefik forwards it
to the `app-one` Service, which forwards to the pod on port 8080.

### Q: If app-two has 3 replicas, which handles the request?
The Service load-balances. You can't predict which specific pod handles a
given request. All 3 return the same "Hello from app two" text.

### Q: What is `ingressClassName: traefik`?
Tells Kubernetes which Ingress Controller should handle these rules. If you
had multiple controllers installed, this selects Traefik. If omitted,
Traefik would likely still pick it up (it's the only one), but being explicit
is best practice.

### Q: What does `port: 80` vs `targetPort: 8080` mean in a Service?
`port: 80` = what the Service listens on (external-facing, from Ingress's
perspective). `targetPort: 8080` = the port on the actual pod container.
The Service translates between them: Ingress -> Service:80 -> Pod:8080.

### Q: What is ClusterIP?
A Service type that's only reachable from inside the cluster. External traffic
can't hit it directly. That's why we need the Ingress + Traefik to expose the
apps to the outside.

---

## Commands You Should Know

```bash
# Check deployments (shows replica counts)
kubectl get deployments -o wide
# or: make deployments

# Check pods (shows individual running containers)
kubectl get pods -o wide
# or: make pods

# Check services
kubectl get svc
# or: make services

# Check ingress (REQUIRED for defense!)
kubectl get ingress
kubectl describe ingress app-ingress
# or: make ingress

# Test routing from host
curl -H "Host: app1.com" http://192.168.56.110
curl -H "Host: app2.com" http://192.168.56.110
curl http://192.168.56.110
# or: make test
```

---

## What the Evaluator Will Check

1. One VM is running with the right hostname and IP
2. 3 different apps respond correctly based on Host header
3. `kubectl get ingress` shows the routing rules
4. app-two has 3 replicas (`kubectl get pods` shows 3 pods)
5. You can explain: what is an Ingress, what is a Deployment, how routing works
6. You can show the difference between `curl -H "Host: app1.com"` vs `curl -H "Host: app2.com"` vs plain `curl`
