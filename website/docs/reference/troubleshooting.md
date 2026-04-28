---
title: "Troubleshooting"
sidebar_label: "Troubleshooting"
sidebar_position: 8
description: "Failure modes and fixes for Git-Ape pipelines and onboarding"
---

# Troubleshooting

Hands-on debug reference. Each entry: symptom → cause → fix.

## Onboarding

### `AADSTS700213: No matching federated identity record found for presented assertion subject`

The OIDC token GitHub or ADO presents doesn't match any federated credential.

**GitHub — custom org subject template.** Some orgs (notably `Azure`) override the OIDC subject claim to ID-based format. The orchestrator auto-detects:

```bash
gh api orgs/$GITHUB_ORG/actions/oidc/customization/sub --jq '.use_default'
```

If `false`, subjects look like `repository_owner_id:6844498:repository_id:1184905165:pull_request`. Re-run `/git-ape-onboarding cicd:github` to recreate credentials in the right format.

**GitHub — environment subject missing.** Each environment used by the workflows needs a credential with subject `repo:<org>/<repo>:environment:<envname>`. Add new environments → add matching credentials.

**ADO — wrong issuer/subject convention.** Older docs say `sc://...` and `vstoken.dev.azure.com` — both wrong. Read the live values:

```bash
ADO_TOKEN=$(az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv)
SC_ID=$(az devops service-endpoint list --org "$ADO_ORG_URL" --project "$ADO_PROJECT" \
  --query "[?name=='$SERVICE_CONNECTION_NAME'].id" -o tsv)
curl -sS -H "Authorization: Bearer $ADO_TOKEN" \
  "https://dev.azure.com/$ORG/$PROJECT/_apis/serviceendpoint/endpoints/$SC_ID?api-version=7.1" \
  | jq '{issuer: .authorization.parameters.workloadIdentityFederationIssuer,
         subject: .authorization.parameters.workloadIdentityFederationSubject}'
```

Update the federated credential to match.

### `AuthorizationFailed` during deployment

Federated principal authenticated but lacks RBAC. Check:

```bash
SP_ID=$(az ad sp show --id $CLIENT_ID --query id -o tsv)
az role assignment list --assignee "$SP_ID" -o table
```

Expected: `Contributor` (and optionally `User Access Administrator`) on the subscription.

### "Resource group not found" in plan

Wrong subscription, or subscription is `Disabled`:

```bash
az account show --subscription <SUB_ID> --query "{name:name,state:state}" -o table
```

Disabled subscriptions are read-only.

## Azure DevOps pipelines

### `TF402455: Pushes to this branch are not permitted`

Build identity has `GenericContribute` (4) but is missing `PolicyExempt` (128) — required to push past the Branch Policy required check.

**Fix.** Re-run Step B of `git-ape-onboarding-azdo` with `allow=16516` (4 + 128 + 16384):

```bash
curl -sS -X POST \
  -H "Authorization: Bearer $ADO_TOKEN" \
  -H "Content-Type: application/json" \
  "https://dev.azure.com/${ADO_ORG_NAME}/_apis/accesscontrolentries/${GIT_NAMESPACE_ID}?api-version=7.1" \
  -d '{
    "token": "repoV2/'"${PROJECT_ID}"'/'"${REPO_ID}"'",
    "merge": true,
    "accessControlEntries": [{
      "descriptor": "'"${IDENTITY_DESCRIPTOR}"'",
      "allow": 16516, "deny": 0, "extendedInfo": {}
    }]
  }'
```

### Plan PR comment never appears

**Cause 1**: Build identity missing `PullRequestContribute` (16384). Threads API silently 403s. Same fix as TF402455 (`allow=16516` covers all three bits).

**Cause 2**: `$(System.AccessToken)` not mapped to env var. ADO macros in inline bash evaluate as shell command substitution — token comes through empty. **Always** map explicitly:

```yaml
- bash: |
    curl -H "Authorization: Bearer $SYSTEM_ACCESSTOKEN" ...
  env:
    SYSTEM_ACCESSTOKEN: $(System.AccessToken)
```

Never write `Bearer $(System.AccessToken)` directly in bash.

### Plan pipeline doesn't trigger when a PR is opened

**Azure Repos silently ignores YAML `pr:` triggers.** PR builds queue from Branch Policy → Build Validation. Verify:

```bash
az repos policy list --org "$ADO_ORG_URL" --project "$ADO_PROJECT" --branch main \
  --query "[?settings.displayName=='Git-Ape Plan']" -o table
```

If empty, re-run `/git-ape-onboarding-azdo` Step C.

### Multi-deployment PRs run sequentially

ADO **free-tier orgs have 1 self-hosted parallel job org-wide**. Even with N agents, matrix slots serialize. Verify:

```bash
curl -sS -H "Authorization: Bearer $ADO_TOKEN" \
  "https://dev.azure.com/${ADO_ORG_NAME}/_apis/distributedtask/resourcelimits?api-version=7.1-preview" \
  | jq '.value[] | select(.parallelismTag == "Private" and .isHosted == false)'
```

Options if `totalCount == 1`:
- Buy `Self-hosted CI/CD` parallel jobs ($15/job/mo)
- Make the project public (unlimited self-hosted parallelism)

### `Bash exited with code '127'` on `$(stepName.OutputVar)` reference

Producing step was skipped → macro expanded to literal text → bash ran it as command substitution → not found.

**Fix.** File-based status passing:

```yaml
# Producer
- inlineScript: |
    echo "passed" > "$STAGING/validation-$(deployment_id).txt"

# Consumer
- bash: |
    VALIDATION_STATUS="skipped"
    [[ -f "$STAGING/validation-$DEPLOYMENT_ID.txt" ]] && \
      VALIDATION_STATUS=$(cat "$STAGING/validation-$DEPLOYMENT_ID.txt")
```

### Destroy detects 0 destroys but metadata.json says destroy-requested

**Cause 1**: `Build.Reason` is lowercase. Use case-insensitive comparison:

```bash
REASON=$(echo "$(Build.Reason)" | tr '[:upper:]' '[:lower:]')
```

**Cause 2**: `fetchDepth: 2` too shallow when `[skip ci]` commits sit between destroy and HEAD. Use `fetchDepth: 0`.

### `PublishPipelineArtifact@1` doesn't include a file we just wrote

Snapshots target dir at task time. Reorder: render BEFORE publish.

### `UsePythonVersion@0` fails on self-hosted

Tool cache is empty on self-hosted. Use `bootstrap-prereqs.yml` instead (system Python + apt-installed pip).

## GitHub Actions

### `Process completed with exit code 403` posting PR comment

Missing `pull-requests: write`. Add to job/workflow `permissions:` block.

### `azure/login@v2` fails with "no credentials found"

Missing `permissions: id-token: write`. GitHub doesn't issue an OIDC token without it.

### `${{ secrets.AZURE_CLIENT_ID }}` is empty at runtime

Either workflow step's `environment:` field is wrong, or the secret is set at repo scope only — environment-scoped lookups won't find it. Use `gh secret set --env <env>`.

### `/deploy` PR comment doesn't trigger deploy

Check:
1. Workflow has `on: issue_comment: types: [created]`
2. Comment author is `MEMBER`/`OWNER`/`COLLABORATOR`
3. The `if:` matches the comment body
4. `github.event.issue.pull_request` is non-null (only PR comments, not issues)

## Deployment Stacks

### `VaultAlreadyExists` when redeploying after destroy

Soft-deleted KV with `enablePurgeProtection: true` is in retention (7-90 days, cannot force-purge). Vault name is unavailable until `scheduledPurgeDate` (recorded in `state.retainedSoftDeleted[]`).

Options: wait, pick a new name, or disable purge protection (NOT recommended).

### `Stack X does not exist` during destroy

Stack already deleted (or deploy never succeeded). Destroy treats as `already-destroyed` and exits cleanly.

### Stack create fails with `DeploymentDeniedByDenySettings`

Another stack has deny settings. List active:

```bash
az stack sub list --query "[].{name:name, denyMode:denySettings.mode}" -o table
```

Git-Ape uses `--deny-settings-mode none` to avoid creating new ones.

## Verify pipeline

### "0 required missing, 2 recommended missing"

Required tools present. Recommended (pwsh, checkov) missing → those scanners get skipped, surfaced in the PR comment. Onboarding still considered complete.

### "1 required missing"

Required tool missing. Verify FAILS, onboarding skill won't mark complete. Install on agent:

```bash
sudo apt-get install -y jq python3 python3-pip git curl
az extension add --name stack || true
```

## State / CI/CD coupling

### State.json was committed but the next deploy didn't see it

Race: deploy run #1 commits state.json; deploy run #2 starts before #1's commit lands. Mitigations:
- Environment exclusive lock (configure in Azure DevOps environment "Approvals and checks")
- `[skip ci]` on state commit prevents trigger loop

### State.json fields are missing (e.g. `managedResources` is `null`)

Pre-Deployment-Stacks state. Path B in destroy handles gracefully (`az group delete` for `state.resourceGroup`). No action needed unless you want to re-deploy as a stack.
