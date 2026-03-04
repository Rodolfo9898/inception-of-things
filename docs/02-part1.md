# Part 1: K3s and Vagrant

Setting up a two-node Kubernetes cluster with Vagrant.

---

## What You're Building

```
Your Mac (host)
  │
  ├── VM 1: rperez-tS  (192.168.56.110)  ← K3s Server (control plane)
  │     └── API server, scheduler, etcd, controller manager
  │
  └── VM 2: rperez-tSW (192.168.56.111)  ← K3s Agent (worker)
        └── Joins the cluster, runs workloads (pods)
```

---

## Key Files

- `Vagrantfile` — Defines both VMs (box, IPs, provisioning scripts)
- `scripts/master.sh` — Installs K3s in **server** mode, exports join token
- `scripts/worker.sh` — Installs K3s in **agent** mode, joins cluster using token

---

## Concepts You Must Understand

### Synced Folder (`/vagrant`)

`config.vm.synced_folder ".", "/vagrant"` maps the host's `p1/` directory to
`/vagrant` inside both VMs. This is the bridge that lets the master export the
join token and the worker pick it up. Without this shared folder, you'd need
SSH or some network file transfer between VMs to pass the token — the synced
folder makes it trivial.

### Provisioning

`config.vm.provision :shell, path: "scripts/master.sh"` runs the script
inside the VM automatically on `vagrant up` (first boot only). To re-run
provisioning without destroying the VM: `vagrant provision`.

### Private Network vs NAT

Vagrant gives every VM a NAT network by default, but you can add more.

- **NAT** (Vagrant default): Each VM gets an isolated network. VMs can reach
  the internet (outbound), but **VMs cannot see each other**. Like two hotel
  rooms with WiFi but no intercom.
- **Private network** (`private_network`): Creates a shared host-only network.
  All VMs on `192.168.56.x` can talk to each other, and the host can reach them
  too. Essential because the worker must reach the server at `192.168.56.110:6443`.

The name `:private_network` is a Vagrant keyword (you can't change it). Both VM
blocks use the same keyword, and Vagrant automatically puts them on the same
host-only network. The IP addresses you assign (`192.168.56.110`, `.111`) are
on the same subnet (`192.168.56.0/24`), which is how they know they're on the
same network.

### The Dummy Interface (in master.sh / worker.sh)

Lines like `ip link add eth1 type dummy` create a fake network interface with
the right IP. This is a timing workaround — Vagrant's private network interface
(`eth1`) might not be fully ready when K3s starts. The dummy ensures K3s always
has an interface to bind to. Think of it as: "if the real door isn't built yet,
put up a temporary one so K3s doesn't crash looking for it."

In Part 2's `bootstrap.sh`, we handle this differently — detecting the interface
dynamically with `ip -o -4 addr list | grep 192.168.56.110`.

### K3s Server Install Flags

| Flag | What it does |
|------|-------------|
| `--write-kubeconfig-mode 644` | Unix file permissions: owner read+write (6), group read (4), others read (4). Makes kubeconfig readable by all users, not just root. Without it, only root can run `kubectl`. |
| `--tls-san=rperez-tS` | Adds hostname to the server's TLS certificate (Subject Alternative Name). If someone connects via hostname (e.g. `kubectl` using `https://rperez-tS:6443`), the certificate will be valid. Note: this does NOT make hostname resolution work — you still need DNS or `/etc/hosts` for that. It just prepares the certificate. |
| `--node-ip=192.168.56.110` | Tells K3s which IP to use. The VM has multiple IPs (NAT + private) and K3s needs to know which one is the cluster network. |
| `--bind-address=192.168.56.110` | API server listens on this specific IP. Forces it to the private network, not the NAT interface. |
| `--advertise-address=192.168.56.110` | Server tells agents: "to reach me, use this IP." Without this, it might advertise the NAT IP which agents can't reach. |

### TLS-SAN vs DNS Resolution — Two Separate Things

1. **DNS resolution** ("can I translate the hostname to an IP?"): Happens BEFORE
   connecting. If there's no DNS entry or `/etc/hosts` mapping, the connection
   never starts.
2. **TLS certificate validation** ("does the cert match the name I used?"): Happens
   AFTER connecting. `--tls-san` makes the certificate accept the hostname.

So `--tls-san=rperez-tS` doesn't let the worker use the hostname to connect.
The worker would still need DNS to resolve the name. The flag just ensures the
cert is ready IF someone does connect via hostname (e.g., from the host after
adding a `/etc/hosts` entry).

### The Join Token

1. K3s server generates a token at `/var/lib/rancher/k3s/server/node-token`
2. `master.sh` copies it to `/vagrant/token` (= `p1/token` on host, via synced folder)
3. `worker.sh` reads `/vagrant/token` to join the cluster
4. `worker.sh` deletes the token after joining — security measure, since the
   token is like a password that lets any machine join your cluster. Leaving it
   in the shared folder (synced to host filesystem) is a risk.

### Server vs Agent

- `sh -s -` (or `sh -s - server`): Installs K3s **server** (control plane).
  Runs: API server, scheduler, controller manager, etcd.
- `sh -s - agent`: Installs K3s **agent** (worker). Lightweight — only runs
  kubelet and container runtime. Receives instructions from the server.

### Port 6443

The Kubernetes API server default port. Every `kubectl` command and every
agent-to-server communication goes through this port. Worker connects to
`https://192.168.56.110:6443`.

### Hostname vs IP

The worker uses the server's IP (`192.168.56.110`) rather than hostname
(`rperez-tS`) because there's no DNS entry mapping the hostname to the IP.
DNS resolution fails before any connection can start. Using IPs directly
is simpler and more reliable.

---

## Understanding Check (with answers)

### Q: What happens if you start the worker VM before the server VM?
The worker install fails. It tries to connect to `https://192.168.56.110:6443`
and read `/vagrant/token` — neither exists yet. The server must be running
and have generated the token first.

### Q: Why `--bind-address=192.168.56.110`?
The VM has multiple network interfaces (NAT + private). Without this flag,
the API server might bind to the NAT IP, which the worker can't reach.
Forces it to listen on the private network IP.

### Q: If you delete the token file after both VMs are running, does the cluster break?
No. The token is only needed during the join process. Once the agent has
joined, the connection is established and the token isn't used again.
(But if you restart the agent service, it might need the token again.)

### Q: What's the difference between `kubectl` and `k3s`?
- `kubectl`: Standard Kubernetes CLI. Sends commands to the API server.
  Works with any Kubernetes cluster.
- `k3s`: The K3s binary. Includes the server/agent runtime AND bundles kubectl.
  `k3s kubectl get pods` and `kubectl get pods` do the same thing.

### Q: What does `644` mean?
Unix file permissions. Three digits: owner / group / others.
6 = read+write, 4 = read-only, 0 = no access.
644 = owner can read/write, everyone else read-only.

### Q: Could the worker use hostname instead of IP?
No. There's no DNS entry mapping `rperez-tS` to `192.168.56.110`.
DNS resolution fails before the connection even starts.
(`--tls-san` on the server only makes the certificate accept the hostname —
it doesn't make DNS resolution work.)

---

## Commands You Should Know

```bash
kubectl get nodes -o wide      # Show all cluster nodes
vagrant ssh rperez-tS          # SSH into server VM
vagrant ssh rperez-tSW         # SSH into worker VM
ip a show eth1                 # Check network interface inside VM
systemctl status k3s           # Check K3s service status
cat /var/lib/rancher/k3s/server/node-token  # View join token (on server)
```

---

## What the Evaluator Will Check

1. Two VMs are running (`vagrant status`)
2. Both are in the same cluster (`kubectl get nodes -o wide` shows 2 nodes)
3. Hostnames match your 42 login + S / SW
4. IPs are `192.168.56.110` and `192.168.56.111`
5. You can explain what K3s is and how the cluster was formed
