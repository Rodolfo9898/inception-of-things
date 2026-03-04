# Part 2: K3s and three simple applications

One VM running K3s in server mode with 3 web apps and host-based Ingress routing.

## Requirements

- Vagrant + VirtualBox
- Hostname: your 42 login + `S` (default: `msousaS` — change in Vagrantfile)
- VM IP: `192.168.56.110`
- Box: `cloudicio/ubuntu-server` (works on both Intel and Apple Silicon)

## Layout

- `Vagrantfile` — single VM definition
- `scripts/bootstrap.sh` — installs K3s (with Traefik), deploys apps
- `confs/apps.yaml` — 3 Deployments + 3 Services (app-two has 3 replicas)
- `confs/ingress.yaml` — host-based routing: app1.com -> app1, app2.com -> app2, default -> app3

## Usage

```bash
cd p2
make up          # start VM and provision
make test        # test routing from host
make all         # check all K8s resources
make ssh         # SSH into VM
```

## Test routing manually

```bash
curl -H "Host: app1.com" http://192.168.56.110   # app one
curl -H "Host: app2.com" http://192.168.56.110   # app two (3 replicas)
curl http://192.168.56.110                       # app three (default)
```

## kubectl from host

The Makefile sets `KUBECONFIG` automatically, so `make pods`, `make ingress`, etc. just work.

To run kubectl directly:
```bash
export KUBECONFIG=$(pwd)/k3s.yaml
kubectl get ingress
kubectl describe ingress app-ingress
```

## Defense: show Ingress

```bash
make ingress          # from host
# or from inside VM:
vagrant ssh
kubectl get ingress
kubectl describe ingress app-ingress
```
