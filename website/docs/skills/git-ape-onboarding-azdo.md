<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/skills/git-ape-onboarding-azdo/SKILL.md -->

---
title: "Git Ape Onboarding Azdo"
sidebar_label: "Git Ape Onboarding Azdo"
description: "Azure DevOps-specific onboarding playbook for Git-Ape. Activates the four ADO pipelines (plan, deploy, destroy, verify), grants build identity Git permissions, creates the Branch Policy required check, and verifies parallelism quota. Called by the `git-ape-onboarding` orchestrator skill after the shared OIDC + RBAC setup is complete. Do not invoke directly — let the orchestrator dispatch to this skill."
---

# Git Ape Onboarding Azdo

> Azure DevOps-specific onboarding playbook for Git-Ape. Activates the four ADO pipelines (plan, deploy, destroy, verify), grants build identity Git permissions, creates the Branch Policy required check, and verifies parallelism quota. Called by the `git-ape-onboarding` orchestrator skill after the shared OIDC + RBAC setup is complete. Do not invoke directly — let the orchestrator dispatch to this skill.

## Details

| Property | Value |
|----------|-------|
| **Skill Directory** | `.github/skills/git-ape-onboarding-azdo/` |
| **Phase** | General |
| **User Invocable** | ✅ Yes |
| **Usage** | `/git-ape-onboarding-azdo` |


## Documentation

# Git-Ape ADO Onboarding (sub-skill)

This sub-skill contains the Azure DevOps-only steps of the Git-Ape onboarding playbook. It is intended to be **dispatched from `git-ape-onboarding`** after the shared steps (1–10) have already completed:

- App registration created
- Federated credentials added
- RBAC assigned
- ADO service connection (`azureServiceConnection`) created
- Variable group (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`) populated
- ADO environments (`azure-deploy`, `azure-destroy`) created with approval checks

Inputs expected from the orchestrator (env vars or substituted values):

| Variable | Example | Source |
|---|---|---|
| `ADO_ORG_NAME` | `contoso` | Step 1 (resolve metadata) |
| `ADO_ORG_URL` | `https://dev.azure.com/contoso` | Step 1 |
| `ADO_PROJECT` | `myapp-infra` | Step 1 |
| `ADO_REPO_NAME` | `myapp-infra` | Step 1 |
| `ADO_REPO_TYPE` | `tfsgit` (or `github` for Both mode) | Step 1 |
| `ADO_CONNECTION_NAME` | `git-ape-azure` | Step 7a (service connection create) |
| `ADO_VARIABLE_GROUP` | `git-ape-azure-secrets` | Step 7 (variable group create) |
| `ADO_TOKEN` | `az account get-access-token --resource 499b84ac-...` | one-line bash |

## Step A — Activate pipelines

The pipeline files in `.azure-pipelines/` ship as `*.examplepipeline.yml` with two placeholder tokens:

| Placeholder | Replaced with | Default if not customized |
|---|---|---|
| `{{SERVICE_CONNECTION_NAME}}` | `$ADO_CONNECTION_NAME` | `git-ape-azure` |
| `{{VARIABLE_GROUP_NAME}}` | `$ADO_VARIABLE_GROUP` | `git-ape-azure-secrets` |

Substitute both tokens, then rename to `*.yml`:

```bash
cd .azure-pipelines
for f in *.examplepipeline.yml; do
  target="${f%.examplepipeline.yml}.yml"
  sed -e "s|{{SERVICE_CONNECTION_NAME}}|$ADO_CONNECTION_NAME|g" \
      -e "s|{{VARIABLE_GROUP_NAME}}|$ADO_VARIABLE_GROUP|g" \
      "$f" > "$target"
  echo "Templated and renamed: $f -> $target"
done
cd -

# Verify no placeholders remain (should print nothing)
grep -rE '\{\{(SERVICE_CONNECTION_NAME|VARIABLE_GROUP_NAME)\}\}' .azure-pipelines/*.yml \
  && echo "##vso[task.logissue type=error]Placeholders not fully substituted"

# Register each pipeline
for name in git-ape-plan git-ape-deploy git-ape-destroy git-ape-verify; do
  az pipelines create \
    --name "$name" \
    --yaml-path ".azure-pipelines/${name}.yml" \
    --org "$ADO_ORG_URL" --project "$ADO_PROJECT" \
    --repository "$ADO_REPO_NAME" \
    --repository-type "$ADO_REPO_TYPE" \
    --branch main \
    --skip-first-run true
done
```

The shared `templates/` and `scripts/` directories under `.azure-pipelines/` contain no placeholders — they ship ready to use.

`$ADO_REPO_TYPE` is `tfsgit` for Azure Repos or `github` when the source repo is a GitHub-hosted repo (Both mode). For GitHub-backed repos, `--service-connection <github-service-connection>` is also required.

**Pipelines reference shared templates and scripts:** the YAML files include `templates/bootstrap-prereqs.yml`, `templates/commit-and-push-state.yml`, and call `scripts/render-destroy-plan.sh`, `scripts/render-pr-comment.sh`, `scripts/render-summary.sh`. These are committed alongside the pipeline files; the agent does not need to copy them separately.

## Step B — Grant build identity repo permissions

The deploy and destroy pipelines need three Git permissions on the build identity:

| Bit | Permission | What it enables | Failure mode without it |
|---|---|---|---|
| 4 | `GenericContribute` | Push commits (state.json, metadata.json) | `TF401027: You need the Git 'GenericContribute' permission` |
| 128 | `PolicyExempt` | Bypass branch policies when pushing state-only commits | `TF402455: Pushes to this branch are not permitted` (once Step C's branch policy is active) |
| 16384 | `PullRequestContribute` | Post and update PR thread comments (the plan PR comment) | Plan pipeline succeeds but no PR comment appears (silent 403 from threads API) |

**Combined ACL `allow` value:** `4 + 128 + 16384 = 16516`

Workload identity federation only covers Azure auth — these are Git permissions that must be granted separately.

**Important:** The build identity (`<project> Build Service (<org>)`) has type `Microsoft.TeamFoundation.ServiceIdentity`, NOT a regular user identity. The `az devops user show` and `az devops security permission update` commands do NOT work for this identity type. Use the VSSPS Graph API and Security ACL REST API instead:

```bash
# 1. Find the build service identity via VSSPS Graph API
GRAPH_USERS=$(curl -sS \
  -H "Authorization: Bearer $ADO_TOKEN" \
  "https://vssps.dev.azure.com/${ADO_ORG_NAME}/_apis/graph/users?api-version=7.1-preview.1")
BUILD_DESCRIPTOR=$(echo "$GRAPH_USERS" | jq -r \
  ".value[] | select(.displayName | test(\"${ADO_PROJECT} Build Service\")) | .descriptor")

# 2. Resolve the identity descriptor (needed for ACL)
IDENTITY_RESPONSE=$(curl -sS \
  -H "Authorization: Bearer $ADO_TOKEN" \
  "https://vssps.dev.azure.com/${ADO_ORG_NAME}/_apis/identities?subjectDescriptors=${BUILD_DESCRIPTOR}&api-version=7.1-preview.1")
IDENTITY_DESCRIPTOR=$(echo "$IDENTITY_RESPONSE" | jq -r '.value[0].descriptor')

# 3. Git Repositories security namespace ID (constant)
GIT_NAMESPACE_ID="2e9eb7ed-3c0a-47d4-87c1-0ffdd275fd87"

# 4. Resolve project + repo IDs and build the ACL token
PROJECT_ID=$(az devops project show --project "$ADO_PROJECT" --org "$ADO_ORG_URL" --query id -o tsv)
REPO_ID=$(az repos show --repository "$ADO_REPO_NAME" --org "$ADO_ORG_URL" --project "$ADO_PROJECT" --query id -o tsv)
TOKEN="repoV2/${PROJECT_ID}/${REPO_ID}"

# 5. Grant all 3 bits in ONE call (allow = 4 + 128 + 16384 = 16516)
curl -sS -X POST \
  -H "Authorization: Bearer $ADO_TOKEN" \
  -H "Content-Type: application/json" \
  "https://dev.azure.com/${ADO_ORG_NAME}/_apis/accesscontrolentries/${GIT_NAMESPACE_ID}?api-version=7.1" \
  -d "{
    \"token\": \"${TOKEN}\",
    \"merge\": true,
    \"accessControlEntries\": [{
      \"descriptor\": \"${IDENTITY_DESCRIPTOR}\",
      \"allow\": 16516,
      \"deny\": 0,
      \"extendedInfo\": {}
    }]
  }"
```

**Skip Step B when:** the source repo lives in a different ADO project than the pipeline. In that case the cross-project build identity grant cannot be issued from the project's own scope; document the manual portal grant instead and surface a `⚠️ MANUAL ACTION REQUIRED` line in the onboarding summary.

## Step C — Create the Branch Policy required check

**Critical:** Azure Repos **silently ignores** the `pr:` trigger block in YAML. PR builds are queued by **Branch Policy → Build Validation**, not by the YAML trigger. Without this policy, opening a PR will not run the plan pipeline.

```bash
# Get the plan pipeline ID from Step A output (or look it up)
PLAN_PIPELINE_ID=$(az pipelines show --name git-ape-plan --org "$ADO_ORG_URL" --project "$ADO_PROJECT" --query id -o tsv)
PROJECT_ID=$(az devops project show --project "$ADO_PROJECT" --org "$ADO_ORG_URL" --query id -o tsv)
REPO_ID=$(az repos show --repository "$ADO_REPO_NAME" --org "$ADO_ORG_URL" --project "$ADO_PROJECT" --query id -o tsv)

# Type ID 0609b952-... = "Build" policy (Build Validation)
# isBlocking=true makes it a required check before merge
# queueOnSourceUpdateOnly=true requires validDuration > 0
curl -sS -X POST \
  -H "Authorization: Bearer $ADO_TOKEN" \
  -H "Content-Type: application/json" \
  "https://dev.azure.com/${ADO_ORG_NAME}/${PROJECT_ID}/_apis/policy/configurations?api-version=7.1-preview" \
  -d "{
    \"isEnabled\": true,
    \"isBlocking\": true,
    \"type\": { \"id\": \"0609b952-1397-4640-95ec-e00a01b2c241\" },
    \"settings\": {
      \"buildDefinitionId\": ${PLAN_PIPELINE_ID},
      \"queueOnSourceUpdateOnly\": true,
      \"manualQueueOnly\": false,
      \"displayName\": \"Git-Ape Plan\",
      \"validDuration\": 720,
      \"scope\": [{
        \"refName\": \"refs/heads/main\",
        \"matchKind\": \"Exact\",
        \"repositoryId\": \"${REPO_ID}\"
      }]
    }
  }"
```

**If policy evaluations get stuck** with `buildId=0` after creation: delete and re-create the policy. There's no API to "kick" a stuck evaluation.

## Step D — Verify ADO parallelism quota

Free-tier ADO orgs have **only 1 self-hosted parallel job** org-wide. Even with N agents, only one runs at a time — your matrix strategy will serialize.

```bash
# Check current quota
curl -sS -H "Authorization: Bearer $ADO_TOKEN" \
  "https://dev.azure.com/${ADO_ORG_NAME}/_apis/distributedtask/resourcelimits?api-version=7.1-preview" \
  | jq '.value[] | select(.parallelismTag == "Private" and .isHosted == false) | {totalCount, free: .resourceLimitsData.FreeCount, purchased: .resourceLimitsData.PurchasedCount}'
```

If `totalCount == 1`, surface a `⚠️ PERFORMANCE NOTE` line in the onboarding summary explaining:
- Multi-deployment PRs will run plan jobs sequentially regardless of agent count
- Options: (a) buy "Self-hosted CI/CD" parallel jobs at $15/job/mo, or (b) make project public (unlimited self-hosted parallelism)
- This is an org-level setting, not something the skill can fix.

## Output for the orchestrator

Return to the orchestrator a status summary that the orchestrator merges into its Step 11 output:

```
Azure DevOps Pipelines:
  - git-ape-plan.yml         registered (id=$PLAN_PIPELINE_ID)
  - git-ape-deploy.yml       registered (id=$DEPLOY_PIPELINE_ID)
  - git-ape-destroy.yml      registered (id=$DESTROY_PIPELINE_ID)
  - git-ape-verify.yml       registered (id=$VERIFY_PIPELINE_ID)
  Build identity ACL grant:  ✅ applied (allow=16516) | ⚠️ manual (cross-project)
  Branch policy:             ✅ created (id=$POLICY_ID, isBlocking=true)
  Parallelism quota:         <totalCount> private self-hosted job(s)  [⚠️ if 1]
```

## Provider-specific gotchas (ADO)

- **No `issue_comment` trigger.** ADO pipelines cannot trigger from PR comments. The GitHub `/deploy` early-deploy comment trigger has no ADO equivalent — deploy gating relies entirely on the `azure-deploy` environment's pre-deployment approval check.
- **YAML `pr:` triggers are silently ignored** for Azure Repos. PR builds are queued by **Branch Policy → Build Validation** (Step C). Without the policy, opening a PR will not run the plan pipeline.
- **`$(macroName)` in inline bash is shell command substitution**, not ADO macro expansion. Use env var form `$ENV_VAR` via `env:` mapping. `$(System.AccessToken)` is the most common offender — always map it explicitly.
- **`$(stepName.OutputVar)` macros expand to literal text when the producing step was skipped** — bash then tries to execute that as a command (`command not found`). Use file-based status passing: write status to an artifact file, read with default in consumer step.
- **`$[ coalesce(variables['x'], 'default') ]` runtime expressions do NOT work in `env:` blocks** — only at task input parameter level.
- **`$(Build.Reason)` is lowercase `manual`/`pullrequest`/`individualci`**, not Title Case. Always use case-insensitive comparisons in bash.
- **Federated subject is NOT `sc://` format.** Despite Microsoft documentation suggesting `sc://<org>/<project>/<connection>` and issuer `https://vstoken.dev.azure.com/<org-guid>`, ADO service connections using workload identity federation actually present a **different** issuer (`https://login.microsoftonline.com/<tenant-id>/v2.0`) and an opaque subject (`/eid1/c/pub/t/<base64>/a/<base64>/sc/<org-guid>/<connection-id>`). Always read back the actual values from the service connection endpoint after creation — never hardcode the `sc://` convention.
- **Cross-stage output variables resolve to Null.** Using `stageDependencies.X.Y.outputs['step.VAR']` in multi-stage pipelines often fails silently — the variable resolves to empty/Null. Use **pipeline artifacts** (publish/download) for cross-stage data: write values to files, publish as artifact in the producing stage, download in consuming stages.
- **`PublishPipelineArtifact@1` snapshots its target dir at task time.** Any file written AFTER the publish task (in a later step of the same job) will NOT be included in the artifact. Order matters: render-then-publish, never publish-then-render.
- **No SARIF upload.** GitHub Code Scanning (SARIF) does not exist on ADO. The verify pipeline publishes a verification report as a pipeline artifact instead. Do not attempt to upload SARIF from ADO.
- **Build identity needs THREE permissions on the repo** (not just Contribute). See Step B — combined `allow=16516` (GenericContribute + PolicyExempt + PullRequestContribute). Without `PolicyExempt`, state-commit pushes fail once the branch policy from Step C is active. Without `PullRequestContribute`, plan PR comments silently 403.
- **Build identity is a ServiceIdentity type.** The build service (`<project> Build Service (<org>)`) has type `Microsoft.TeamFoundation.ServiceIdentity`, not `Microsoft.TeamFoundation.Identity`. To grant permissions via the Security ACL API, use the VSSPS Graph API (`_apis/graph/users`) to find it, resolve its descriptor via `_apis/identities?subjectDescriptors=`, then use the full `Microsoft.TeamFoundation.ServiceIdentity;...` descriptor in `_apis/accesscontrolentries/<namespace-id>`.
- **Free-tier orgs only get 1 self-hosted parallel job.** Even with N agents, matrix jobs serialize. Step D surfaces this. Buy `Self-hosted CI/CD` parallel jobs ($15/job/mo) or make the project public.
- **`UsePythonVersion@0` only works on Microsoft-hosted agents.** It downloads from a tool cache that's empty on self-hosted. For self-hosted, install via apt/brew/choco — see `templates/bootstrap-prereqs.yml` for the cross-host pattern.
- **Workload identity federation only.** Never create or store PATs, client secrets, or password credentials for the Git-Ape ADO service connection. If a step appears to require a PAT, surface a blocker rather than introducing one.
