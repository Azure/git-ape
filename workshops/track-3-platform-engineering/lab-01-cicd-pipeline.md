# Lab 1: CI/CD Pipeline

> 20 minutes | Azure required (OIDC onboarding from Track 2 Lab 1)

Deploy through a PR-based workflow: create a deployment, validate on PR, deploy on merge.

## What You Learn

- How `git-ape-plan.yml` validates templates on PR
- How `git-ape-deploy.yml` deploys on merge to main
- How PR comments show the full plan (validation, what-if, security, cost)

## Step 1: Create a Deployment on a Branch

Create a feature branch:

```bash
git checkout -b deploy/workshop-funcapp
```

In Copilot Chat, generate a deployment:

```text
@git-ape deploy a Python function app for the cicd-demo project in dev, region eastus
```

Walk through the conversation. When the template is generated, the artifacts are saved to `.azure/deployments/`.

Commit the generated files:

```bash
git add .azure/deployments/
git commit -m "feat: add Function App deployment for cicd-demo"
git push origin deploy/workshop-funcapp
```

## Step 2: Open a Pull Request

```bash
gh pr create --title "Deploy: Function App for cicd-demo" \
  --body "Deploys a Python Function App with Storage and App Insights." \
  --base main
```

## Step 3: Watch the Plan Workflow

The `git-ape-plan.yml` workflow triggers automatically on the PR. Watch it run:

```bash
gh run list --branch deploy/workshop-funcapp
```

After it completes, check the PR for a comment. The plan comment includes:

### Validation Result

```
✅ Template validation: PASSED
```

### Security Findings

```
🟢 No security issues found (0 errors, 0 warnings)
```

### Cost Estimate

```
Estimated monthly cost: $3.20
- Function App (Consumption): $0.00
- Storage Account: $0.50
- App Insights: $2.70
```

### Architecture Diagram

The Mermaid diagram from `architecture.md` rendered in the PR comment.

### What-If Analysis

```
Resources to CREATE:
  + Microsoft.Resources/resourceGroups — rg-cicddemo-dev-eastus
  + Microsoft.Storage/storageAccounts — stcicddemodev...
  + Microsoft.Web/sites — func-cicddemo-dev-eastus
  + Microsoft.Insights/components — appi-cicddemo-dev-eastus
```

## Step 4: Approve and Merge

Review the plan comment. If everything looks good:

```bash
gh pr review --approve
gh pr merge --squash
```

## Step 5: Watch the Deploy Workflow

The `git-ape-deploy.yml` workflow triggers on the merge to main:

```bash
gh run list --branch main --limit 1
gh run watch
```

After deployment:

- Integration tests run automatically
- `state.json` is committed to the repo with deployment results
- A deployment result comment is posted on the (now merged) PR

## Step 6: Verify the Deployment

Check the committed state:

**Bash / macOS / Linux:**

```bash
git pull
cat .azure/deployments/deploy-*/state.json | jq '.status'
```

**PowerShell / Windows:**

```powershell
git pull
Get-ChildItem .azure/deployments/deploy-*/state.json | ForEach-Object {
  (Get-Content $_ | ConvertFrom-Json).status
}
```

Should show `"deployed"`.

## What You Built

A complete CI/CD pipeline:

1. **PR opens** → template validated, security scanned, cost estimated, plan posted
2. **PR approved + merged** → deployment executed, tests run, state committed
3. **Zero manual steps** — everything triggered by git events
4. **Zero secrets** — OIDC token exchange at runtime

**Next:** [Lab 2 — Headless Mode](lab-02-headless-mode.md)

## Step 7: The PR-comment contract

Plan posts ONE canonical comment with four sections:

1. Validation result
2. What-if analysis
3. Architecture diagram (Mermaid)
4. Cost summary

Subsequent pushes update the same comment via HTML marker.

## Step 8: Two ways to deploy

Merge to main triggers deploy. Alternatively /deploy on an APPROVED PR runs the same workflow. Only approved PRs accept /deploy.

## Common failures

- Plan comment missing: workflow disabled; check Actions tab.
- AADSTS700213: OIDC mismatch; see Lab 1 (T2) Step 4.
- "is not permitted to create PRs": Repo Settings -> Actions -> Workflow permissions; enable.
