# GitOps Tracker — Local Demo Setup

A three-tier app (Go API + Flutter Web + Postgres) used to learn and demonstrate
Argo CD + Kargo on a local minikube cluster.

**What runs where:**

| Namespace | What |
|---|---|
| `gitops-dev` | API (1 replica) + Postgres + nginx frontend |
| `gitops-staging` | API (2 replicas) + Postgres + nginx frontend |
| `gitops-prod` | API (3 replicas) + Postgres + nginx frontend |
| `argocd` | Argo CD control plane |
| `kargo` | Kargo control plane |
| `cert-manager` | TLS certificates for Kargo |
| `gitops-tracker` | Kargo Project (Warehouse + Stages) |

---

## Prerequisites

Install once on your Mac:

```bash
# Package manager
brew install kubectl helm git go

# Local cluster
brew install minikube

# Start Docker Desktop manually (must be running before minikube start)
```

The Kargo CLI is already installed at `~/bin/kargo`. To make it permanent:
```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

---

## Fresh Start Runbook

Run these in order every time you start a new session.

---

### 1 — Start minikube

```bash
minikube start
kubectl get nodes   # wait for STATUS = Ready
```

---

### 2 — Build & load the API image

```bash
cd api && go mod tidy && cd ..
docker build -t gitops-tracker-api:dev ./api
minikube image load gitops-tracker-api:dev
```

Verify:
```bash
minikube image ls | grep gitops
```

---

### 3 — Install Argo CD

```bash
kubectl create namespace argocd

ARGOCD_VERSION=$(curl -s https://api.github.com/repos/argoproj/argo-cd/releases/latest \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])")

kubectl apply -n argocd \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

# Fix CRD annotation size limit (Argo CD v3+)
kubectl apply -n argocd --server-side --force-conflicts \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml" \
  2>&1 | grep -v "^$"

kubectl wait --for=condition=Ready pod --all -n argocd --timeout=180s
```

Get the admin password:
```bash
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath='{.data.password}' | base64 -d && echo
```

---

### 4 — Deploy all environments via ApplicationSet

```bash
kubectl apply -f argocd-appset.yaml
```

Wait for Argo CD to sync all three environments:
```bash
kubectl get applications -n argocd --watch
# Wait until all three show: Synced / Healthy
```

Check pods are running:
```bash
kubectl get pods -n gitops-dev
kubectl get pods -n gitops-staging
```

---

### 5 — Install cert-manager (required by Kargo)

```bash
kubectl apply -f \
  https://github.com/cert-manager/cert-manager/releases/download/v1.15.3/cert-manager.yaml

kubectl wait --for=condition=Ready pod --all -n cert-manager --timeout=120s
```

---

### 6 — Install Kargo

```bash
KARGO_PASS="admin1234"
PASS_HASH=$(htpasswd -bnBC 10 "" "$KARGO_PASS" 2>/dev/null | tr -d ':\n')
SIGNING_KEY=$(openssl rand -base64 29 | tr -d '\n')

helm upgrade --install kargo \
  oci://ghcr.io/akuity/kargo-charts/kargo \
  --namespace kargo \
  --create-namespace \
  --set api.adminAccount.passwordHash="${PASS_HASH}" \
  --set api.adminAccount.tokenSigningKey="${SIGNING_KEY}" \
  --wait
```

---

### 7 — Apply Kargo resources

```bash
# Project + Warehouse + Stages + auto-promotion policy
kubectl apply -f kargo/project.yaml
kubectl apply -f kargo/project-config.yaml
kubectl apply -f kargo/warehouse.yaml
kubectl apply -f kargo/stage-dev.yaml
kubectl apply -f kargo/stage-staging.yaml
kubectl apply -f kargo/stage-prod.yaml
```

Create the GitHub credentials secret (Kargo needs this to push image tag commits):
```bash
# Replace YOUR_GITHUB_PAT with a token that has repo write access for aftaab60
kubectl create secret generic github-creds \
  --namespace gitops-tracker \
  --from-literal=repoURL=https://github.com/aftaab60/gitops-playground.git \
  --from-literal=username=aftaab60 \
  --from-literal=password=YOUR_GITHUB_PAT

kubectl label secret github-creds -n gitops-tracker \
  kargo.akuity.io/cred-type=git
```

Wait for the Warehouse to discover the latest nginx tag:
```bash
kubectl get freight -n gitops-tracker --watch
# Wait until you see a freight entry appear (takes ~30s)
```

---

### 8 — Open the UIs

Run each port-forward in a **separate terminal tab**:

```bash
# Terminal 1 — Argo CD UI
kubectl port-forward svc/argocd-server -n argocd 8443:443

# Terminal 2 — Kargo UI
kubectl port-forward svc/kargo-api -n kargo 3000:443

# Terminal 3 — API (for curl tests)
kubectl port-forward svc/api-service 8080:8080 -n gitops-dev
```

| UI | URL | Username | Password |
|---|---|---|---|
| Argo CD | https://localhost:8443 | `admin` | *(from step 3)* |
| Kargo | https://localhost:3000 | `admin` | `admin1234` |

Accept the self-signed cert warning in both browsers.

---

## Verify Everything Is Up

```bash
# Cluster health
kubectl get nodes

# All three app environments
kubectl get pods -n gitops-dev
kubectl get pods -n gitops-staging

# Argo CD applications
kubectl get applications -n argocd

# Kargo pipeline
kubectl get stages -n gitops-tracker
kubectl get freight -n gitops-tracker
```

Expected:
- All pods `1/1 Running`
- All applications `Synced / Healthy`
- All stages `Healthy / Freight has been verified` (after first promotion)

---

## Demo Script — Kargo Promotion Pipeline

### Test the API
```bash
# Register a user
curl -s -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"demo@example.com","password":"password123"}' | python3 -m json.tool

# Login and fetch progress
TOKEN=$(curl -s -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"demo@example.com","password":"password123"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

curl -s http://localhost:8080/api/v1/progress \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

### Trigger a promotion (dev → staging → prod)

Login to Kargo CLI:
```bash
~/bin/kargo login https://localhost:3000 \
  --admin --password admin1234 --insecure-skip-tls-verify
```

Promote to dev (staging auto-promotes, prod is manual):
```bash
FREIGHT=$(kubectl get freight -n gitops-tracker \
  -o jsonpath='{.items[0].metadata.name}')

~/bin/kargo promote \
  --project gitops-tracker \
  --freight $FREIGHT \
  --stage dev
```

Watch the pipeline:
```bash
kubectl get stages -n gitops-tracker --watch
```

For prod, either:
- Click **Promote** in the Kargo UI at https://localhost:3000
- Or run: `~/bin/kargo promote --project gitops-tracker --freight $FREIGHT --stage prod`

### Show self-healing (Argo CD)
```bash
# Scale API manually — Argo CD will revert it within seconds
kubectl scale deployment api -n gitops-dev --replicas=5

# Watch it revert back to 1
kubectl get pods -n gitops-dev --watch
```

---

## What Each Component Does

```
GitHub repo (source of truth)
    │
    │  Kargo watches Docker Hub for new image tags
    │  Kargo edits kustomization.yaml, commits, pushes
    ▼
manifests/dev/        ◄── Argo CD watches this path
manifests/staging/    ◄── Argo CD watches this path
manifests/prod/       ◄── Argo CD watches this path
    │
    │  Argo CD continuously syncs Git → cluster
    ▼
gitops-dev namespace   (1 API replica)
gitops-staging namespace (2 API replicas)
gitops-prod namespace  (3 API replicas)
```

**Key rule:** nobody edits the cluster directly. All changes go through Git.

---

## Troubleshooting

**minikube won't start:**
```bash
minikube delete && minikube start
```

**Image pull errors (ImagePullBackOff):**
```bash
# Reload the image into minikube
minikube image load gitops-tracker-api:dev
```

**Argo CD shows OutOfSync:**
```bash
# Force a refresh
kubectl annotate application gitops-tracker-dev -n argocd \
  argocd.argoproj.io/refresh=normal --overwrite
```

**Kargo promotion fails:**
```bash
# Check what step failed
kubectl get promotion -n gitops-tracker
kubectl get promotion <name> -n gitops-tracker \
  -o jsonpath='{.status.message}'
```

**Kargo Warehouse not finding Freight:**
```bash
kubectl describe warehouse frontend-warehouse -n gitops-tracker | grep -A 10 Status
# Usually needs ~30s after applying the Warehouse
```
