# Part 1: K3s and Vagrant

Two VMs managed by Vagrant, with K3s server on the first node and K3s agent on the second node.

## Subject requirements covered

- 2 machines launched with Vagrant
- Hostnames: `rperez-tS` and `rperez-tSW` (login + `S` / `SW`)
- Dedicated private IPs:
  - `192.168.56.110` (server)
  - `192.168.56.111` (worker)
- SSH access without password through `vagrant ssh`
- K3s installed:
  - server mode on `rperez-tS`
  - agent mode on `rperez-tSW`
- Kubernetes CLI available through `k3s kubectl`

## Layout

- `Vagrantfile` - defines both VMs, hostnames, IPs, and provisioning
- `scripts/master.sh` - installs K3s server and exports node token
- `scripts/worker.sh` - installs K3s agent and joins using exported token
- `Makefile` - helper targets (`up`, `down`, `destroy`, `ssh-s`, `ssh-sw`, etc.)

## Usage

```bash
cd p1
make up
make status
```

SSH access:

```bash
make ssh-s
make ssh-sw
```

## Validation for defense

From server VM:

```bash
sudo k3s kubectl get nodes -o wide
```

Expected result:

- 2 nodes visible in the same cluster
- `rperez-tS` as control-plane/server
- `rperez-tSW` as worker/agent

Check hostnames and IPs:

```bash
hostname
ip a
```

You should see:

- server node: hostname `rperez-tS`, IP `192.168.56.110`
- worker node: hostname `rperez-tSW`, IP `192.168.56.111`

## Notes

- The worker reads the join token from `/vagrant/token` (shared folder) and removes it after joining.
- If provisioning needs to be re-run:

```bash
make provision
```
