# git-ape-runners — Git-Ape deploying Git-Ape

This is a **Git-Ape deployment artifact** for the private GitHub Actions runners
that run Git-Ape's own workflows. Instead of provisioning runners with imperative
`az deployment group create`, this folder is scaffolded into your working copy at
`.azure/deployments/git-ape-runners/` and deployed through the normal Git-Ape
flow — so you get an **architecture diagram, cost estimate, managed deploy, and
single-command destroy** for the runner infrastructure itself.

| File | Purpose |
|------|---------|
| `template.json` | Subscription-scoped Deployment Stack: RG + nested inner deployment (UAMI, ACR, AcrPull, Key Vault, KV Secrets User, ACA managed env, ACA job) |
| `parameters.json` | Non-secret parameters. Set `githubOwnerRepo`. **Never** put the PAT here. |
| `architecture.md` | Mermaid topology + bootstrap sequence |
| `metadata.json` | Git-Ape deployment metadata (`deploymentId: git-ape-runners`) |

## Why this exists

The runner infra is the one part of onboarding that is pure Azure IaC, so it is
the natural thing to hand to Git-Ape. What stays imperative (and why):

- **Entra app + OIDC + subscription RBAC** for the deploy identity — this is the
  identity Git-Ape's own OIDC login uses, so it must exist *before* Git-Ape can
  deploy anything (circular dependency).
- **GitHub environments / secrets / variables** — GitHub API, not ARM.
- **`az acr build`** — a build action, not IaC. Runs *after* the stack creates
  the ACR.
- **AKS runners** — stay Helm / Actions Runner Controller managed.

## Deploy (Git-Ape flow)

> Prereq: onboarding has already created the Entra app, OIDC, RBAC, and GitHub
> environments/secrets. This deployment only provisions the runner compute.

1. **Set `githubOwnerRepo`** in `parameters.json` (e.g. `Azure/git-ape`). Adjust
   `runnerScope`, `location`, `maxRunners`, `minRunners` as needed. Defaults for
   `acrName` / `keyVaultName` are deterministic and globally unique.

2. **Deploy the stack.** The *first* deploy runs on a public runner or locally,
   because the private runner doesn't exist yet.

   Local:
   ```bash
   /azure-stack-deploy git-ape-runners
   ```
   CI: merge a PR that adds `.azure/deployments/git-ape-runners/` — the
   `git-ape-deploy.yml` workflow deploys it (keep `GIT_APE_RUNNER_LABEL` unset or
   on `ubuntu-latest` for this first run).

3. **Build & push the runner image** into the ACR the stack just created
   (the stock `actions-runner` image lacks `az`/`gh`/`jq` and a registration
   entrypoint — see `../../runners/Dockerfile`):
   ```bash
   ACR=$(jq -r '.acrLoginServer.value' .azure/deployments/git-ape-runners/state.json 2>/dev/null || echo '<acr-name>.azurecr.io')
   az acr build --registry "${ACR%%.*}" --image git-ape-runner:latest \
     --file ../../runners/Dockerfile ../../runners/ --no-logs
   ```

4. **Set the GitHub PAT into Key Vault** (never committed, never in ARM params).
   Use a fine-grained PAT with Actions + Administration (Read & Write), or a
   classic PAT with `repo` scope:
   ```bash
   KV=$(jq -r '.keyVaultName.value' .azure/deployments/git-ape-runners/state.json)
   az keyvault secret set --vault-name "$KV" --name github-pat --value "<PAT>" --output none
   ```

5. **Point Git-Ape workflows at the runner:**
   ```bash
   gh variable set GIT_APE_RUNNER_LABEL --repo <owner>/<repo> --body "git-ape-runner"
   ```
   From here, every Git-Ape deploy — including re-deploys of *this* stack — runs
   on the private runner. That is Git-Ape deploying Git-Ape.

## Destroy

```bash
/azure-stack-destroy git-ape-runners
```
Runs `az stack sub delete --action-on-unmanage deleteAll` (removes RG, ACA job,
environment, ACR, identity, role assignments, Key Vault in one call) and purges
the soft-deleted Key Vault. Then clear the variable to fall back to hosted
runners: `gh variable delete GIT_APE_RUNNER_LABEL`.

## Notes

- **Key Vault** uses RBAC authorization, soft-delete on, and purge protection
  **off** so the destroy flow can fully purge it between deploy/destroy cycles.
- **`minRunners: 1`** keeps one runner warm and visible in GitHub (no cold-start
  gap). Set `0` for true scale-to-zero.
- The template validates with `az deployment sub validate` and deploys with
  `az stack sub create` — identical to every other Git-Ape deployment.
- ACI remains available as a raw template under `../../runners/aci/` for users
  who don't want the managed-stack flow.
