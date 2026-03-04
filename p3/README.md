# Part 3: K3d and Argo CD

K3d-based Kubernetes setup with Argo CD and a `dev` namespace application.

## Subject requirements covered by this folder

- K3d workflow (without Vagrant)
- Installation script for required tools (`scripts/install.sh`):
  - Docker
  - kubectl
  - k3d
- Argo CD namespace: `argocd`
- Application namespace: `dev`
- App manifests using versioned image tags (`v1` / `v2`)

## Layout

- `scripts/install.sh` - installs Docker, kubectl, k3d
- `scripts/setup-cluster.sh` - creates K3d cluster
- `scripts/setup-argocd.sh` - installs Argo CD in `argocd`
- `scripts/setup-dev.sh` - creates `dev` namespace
- `confs/deployment.yaml` - app deployment (`mvan-pee/iot-app:v1` by default)
- `confs/service.yaml` - ClusterIP service on port `8888`
- `confs/ingress.yaml` - ingress routing to the app service

## Usage

```bash
cd p3
sudo bash scripts/install.sh
bash scripts/setup-cluster.sh
bash scripts/setup-argocd.sh
bash scripts/setup-dev.sh
```

## Argo CD access

```bash
kubectl port-forward -n argocd --address 0.0.0.0 svc/argocd-server 8081:443
```

Then open `https://localhost:8081` (or VM IP if remote).

Get admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo
```

## Version update demo (v1 -> v2)

```bash
sed -i 's/mvan-pee\\/iot-app:v1/mvan-pee\\/iot-app:v2/g' confs/deployment.yaml
```

Commit and push to the Git repository watched by Argo CD, then confirm rollout:

```bash
kubectl get pods -n dev
kubectl describe deployment mvan-pee-app -n dev
```
