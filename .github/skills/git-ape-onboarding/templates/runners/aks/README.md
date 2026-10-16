# Git-Ape self-hosted runners on AKS (Actions Runner Controller)

On AKS, private runners are provisioned with the **Actions Runner Controller
(ARC)** using the official `gha-runner-scale-set` Helm chart. ARC runs
**ephemeral runner pods** that scale on demand and scale to zero between jobs.

> There is no ARM-only path to install ARC — the controller and runner scale set
> are Kubernetes resources installed via Helm. The **AKS cluster itself** can be
> created with a standard Git-Ape ARM deployment (`/git-ape` →
> `Microsoft.ContainerService/managedClusters`); this folder covers the ARC layer
> that runs on top of it.

## The label is the scale set name

The runner scale set's name **is** the `runs-on` label. Set
`runnerScaleSetName: git-ape-runner` (below) and then set the repo variable
`GIT_APE_RUNNER_LABEL=git-ape-runner`. The two must match.

## Prerequisites

- An AKS cluster (self-hosted: any cluster; VNet-injected: a cluster on your
  VNet/subnet, e.g. Azure CNI).
- `kubectl` context pointing at the cluster and `helm` installed.
- A GitHub credential (GitHub App recommended, or a fine-grained PAT) stored in
  Key Vault. Do not commit it.
- A **custom runner image** (see below) pushed to a registry the cluster can pull.

## Custom runner image (required)

Like the ACI/ACA paths, AKS runner pods need `az`, `gh`, and `jq` — the stock
`ghcr.io/actions/actions-runner` image has none of them, so Git-Ape steps fail
with `Unable to locate executable file: az`. Build the custom image from the
shared [`Dockerfile`](../Dockerfile) and push it to your ACR:

```bash
az acr create --name <acr-name> --resource-group <rg> --location <region> --sku Basic --admin-enabled true
az acr build --registry <acr-name> --image git-ape-runner:latest \
  --file ../Dockerfile ..
```

Set `template.spec.containers[0].image` in `values.yaml` to
`<acr-name>.azurecr.io/git-ape-runner:latest`. ARC overrides the container
command with `run.sh`, so the image's self-register entrypoint is unused on AKS
(the controller registers pods) — but the tools are still required.

## Install

```bash
# 1. Install the ARC controller (once per cluster)
helm install arc \
  --namespace arc-systems --create-namespace \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller

# 2. Create the GitHub credential secret from Key Vault (never commit it)
GH_TOKEN=$(az keyvault secret show --vault-name <kv-name> \
  --name github-runner-token --query value -o tsv)

kubectl create namespace arc-runners
kubectl create secret generic git-ape-runner-secret \
  --namespace arc-runners \
  --from-literal=github_token="$GH_TOKEN"

# 3. Create the ACR pull secret so pods can pull the custom image
kubectl create secret docker-registry acr-pull \
  --namespace arc-runners \
  --docker-server=<acr-name>.azurecr.io \
  --docker-username=<acr-name> \
  --docker-password="$(az acr credential show -n <acr-name> --query passwords[0].value -o tsv)"

# 4. Install the runner scale set with the Git-Ape values
helm install git-ape-runner \
  --namespace arc-runners \
  -f values.yaml \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
```

Edit `values.yaml` first: set `githubConfigUrl` to your repo (or org) URL, set
`template.spec.containers[0].image` to your custom ACR image, and, for
VNet-injected clusters, schedule runner pods onto the VNet node pool via
`template.spec.nodeSelector`.

## Verify

Confirm the scale set is registered in
*GitHub → Settings → Actions → Runners → Runner scale sets* (or org-level), then
set the workflow variable:

```bash
gh variable set GIT_APE_RUNNER_LABEL --repo <org>/<repo> --body "git-ape-runner"
```

Run **Git-Ape: Verify Setup** — its *Runner Configuration* step reports the
active runner mode.

## Security notes

- Prefer a **GitHub App** over a PAT for org-scale (`githubConfigSecret` then
  carries the App id/installation id/private key instead of a token).
- Give runner pods Azure access with **AAD Workload Identity** (federated, no
  stored keys) rather than mounting credentials. Git-Ape workflows still use
  OIDC for `az` actions.
- Ephemeral runners are the ARC default — no state leaks between jobs.
