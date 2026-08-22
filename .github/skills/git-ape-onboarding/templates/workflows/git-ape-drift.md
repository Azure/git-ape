---
description: |
  Continuous drift remediation workflow for Git-Ape deployments. Runs daily
  to detect configuration drift between Azure resources and stored deployment
  state, classifies changes by severity, and creates PRs for human review.

strict: false

on:
  schedule: daily around 06:00
  workflow_dispatch:

permissions:
  contents: read
  issues: read
  pull-requests: read
  id-token: write  # required for Azure OIDC federation

# Deterministic pre-steps run OUTSIDE the agent sandbox.
# They authenticate to Azure via OIDC and dump current resource state
# to workspace files. The agent then reads these files to reason about
# drift — no Azure credentials or `az` CLI reach the sandbox.
steps:
  - name: Azure Login (OIDC)
    uses: azure/login@v2
    with:
      client-id: ${{ secrets.AZURE_CLIENT_ID }}
      tenant-id: ${{ secrets.AZURE_TENANT_ID }}
      subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}

  - name: Snapshot current Azure state for all tracked deployments
    shell: bash
    run: |
      set -euo pipefail
      mkdir -p /tmp/drift-snapshots
      for dir in .azure/deployments/*/; do
        [ -f "$dir/state.json" ] || continue
        [ -f "$dir/metadata.json" ] || continue
        id=$(basename "$dir")
        meta_status=$(jq -r '.status // ""' "$dir/metadata.json")
        # Skip only explicitly destroyed / destroy-requested — everything
        # else (succeeded, failed, partial) may have live resources we must
        # track for drift. Deploy failures frequently leave partial infra
        # behind, and users legitimately modify those resources manually.
        if [ "$meta_status" = "destroyed" ] || [ "$meta_status" = "destroy-requested" ]; then
          echo "{\"status\":\"skipped\",\"reason\":\"metadata.status=$meta_status\"}" > "/tmp/drift-snapshots/${id}.status.json"
          continue
        fi
        # Resolve resource group: prefer state.json, fall back to metadata.json
        # (state.json .resourceGroup is empty for failed deploys and some
        # succeeded-but-buggy deploys like helloworld-containerapp-dev).
        rg=$(jq -r '.resourceGroup // empty' "$dir/state.json")
        if [ -z "$rg" ]; then
          rg=$(jq -r '.resourceGroup // empty' "$dir/metadata.json")
        fi
        if [ -z "$rg" ]; then
          echo "{\"status\":\"no-resource-group\",\"reason\":\"neither state.json nor metadata.json has a resourceGroup\"}" > "/tmp/drift-snapshots/${id}.status.json"
          continue
        fi
        snapshot="/tmp/drift-snapshots/${id}.json"
        details_file="/tmp/drift-snapshots/${id}.details.json"
        dns_file="/tmp/drift-snapshots/${id}.dns.json"
        status_file="/tmp/drift-snapshots/${id}.status.json"
        err_file="/tmp/drift-snapshots/${id}.err"
        echo "Snapshotting $id (rg=$rg, meta_status=$meta_status)"
        # Redirect stdout → snapshot, stderr → err_file, so we can
        # distinguish "RG missing in Azure" from "RG exists but is empty"
        # AND preserve the full az error message verbatim.
        if az resource list --resource-group "$rg" -o json > "$snapshot" 2> "$err_file"; then
          count=$(jq 'length' "$snapshot")
          echo "{\"status\":\"ok\",\"rg\":\"$rg\",\"resourceCount\":$count,\"metaStatus\":\"$meta_status\"}" > "$status_file"
          # Property-level snapshot: fetch full bodies for every resource so
          # the agent can detect drift inside properties (SKUs, tags,
          # firewall rules, TLS versions, etc.), not just existence.
          echo "[]" > "$details_file"
          if [ "$count" -gt 0 ]; then
            jq -r '.[] | .id' "$snapshot" | while read -r rid; do
              [ -z "$rid" ] && continue
              az resource show --ids "$rid" -o json 2>/dev/null || true
            done | jq -s '.' > "$details_file.tmp" 2>/dev/null && mv "$details_file.tmp" "$details_file" || echo "[]" > "$details_file"
          fi
          # Private DNS zones: record sets are sub-resources not returned by
          # `az resource list`, so query them explicitly per zone.
          echo "{}" > "$dns_file"
          jq -r '.[] | select(.type=="Microsoft.Network/privateDnsZones") | .name' "$snapshot" | while read -r zone; do
            [ -z "$zone" ] && continue
            records=$(az network private-dns record-set list -g "$rg" -z "$zone" -o json 2>/dev/null || echo "[]")
            jq --arg z "$zone" --argjson r "$records" '. + {($z): $r}' "$dns_file" > "$dns_file.tmp" && mv "$dns_file.tmp" "$dns_file"
          done
        else
          err=$(cat "$err_file")
          err_escaped=$(printf '%s' "$err" | head -c 1000 | jq -Rs .)
          echo "[]" > "$snapshot"
          echo "[]" > "$details_file"
          echo "{}" > "$dns_file"
          if printf '%s' "$err" | grep -q 'ResourceGroupNotFound'; then
            code="rg-not-found"
          elif printf '%s' "$err" | grep -qi 'AuthenticationFailed\|AuthorizationFailed'; then
            code="auth-failed"
          else
            code="az-error"
          fi
          echo "{\"status\":\"$code\",\"rg\":\"$rg\",\"metaStatus\":\"$meta_status\",\"error\":$err_escaped}" > "$status_file"
        fi
        rm -f "$err_file"
      done
      # Move snapshots into workspace so the agent can read them
      mkdir -p .drift-snapshots
      cp /tmp/drift-snapshots/*.json .drift-snapshots/ 2>/dev/null || true
      ls -la .drift-snapshots/ || true

      # Build an inventory markdown the agent is guaranteed to read first,
      # so it cannot claim the snapshots are missing.
      {
        echo "# Drift Snapshot Inventory"
        echo ""
        echo "**Pre-step ran at:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "**Workspace:** $GITHUB_WORKSPACE"
        echo "**Snapshot directory:** .drift-snapshots/ (repo-root-relative)"
        echo ""
        echo "## Files produced"
        echo ""
        (cd .drift-snapshots && ls -la) | sed 's/^/    /'
        echo ""
        echo "## Per-deployment status"
        echo ""
        for f in .drift-snapshots/*.status.json; do
          [ -f "$f" ] || continue
          did=$(basename "$f" .status.json)
          st=$(jq -r '.status' "$f")
          rg=$(jq -r '.rg // .reason // ""' "$f")
          rc=$(jq -r '.resourceCount // "n/a"' "$f")
          err=$(jq -r '.error // ""' "$f" | head -c 300)
          echo "### \`$did\`"
          echo ""
          echo "- **Status:** \`$st\`"
          echo "- **Resource group / reason:** \`$rg\`"
          echo "- **Live resource count:** \`$rc\`"
          if [ -n "$err" ] && [ "$err" != "null" ]; then
            echo "- **Captured error:**"
            echo ""
            echo "\`\`\`"
            echo "$err"
            echo "\`\`\`"
          fi
          # Companion file sizes (helps agent know details.json and dns.json exist)
          for ext in json details.json dns.json; do
            fp=".drift-snapshots/${did}.${ext}"
            if [ -f "$fp" ]; then
              sz=$(wc -c < "$fp" | tr -d ' ')
              echo "- \`$fp\`: ${sz} bytes"
            fi
          done
          echo ""
        done
      } > .drift-snapshots/INVENTORY.md
      echo "---- INVENTORY.md ----"
      cat .drift-snapshots/INVENTORY.md

tools:
  edit:
  bash:
    - "jq *"
    - "cat *"
    - "ls *"
    - "find *"
    - "date *"
    - "echo *"
    - "diff *"
    - "sort *"
    - "grep *"
    - "head *"
    - "tail *"
    - "wc *"
  cache-memory:
    description: "Drift detection state — tracks last-seen drift per deployment to implement anti-flapping logic"

safe-outputs:
  mentions: false
  allowed-github-references: []
  # Allow Azure Portal deep links in issue bodies (default sanitizer
  # replaces any non-allowlisted URL with "(redacted)"). "defaults"
  # keeps the baseline GitHub/infrastructure allowlist.
  allowed-domains:
    - defaults
    - portal.azure.com
  create-issue:
    title-prefix: "[drift-status] "
    labels: [drift-status]
    close-older-issues: true
    max: 1
---

# Continuous Drift Remediation

Detect configuration drift across all active Git-Ape deployments and report
findings in a single rolling status issue for human review.

## Context

This workflow implements the agentic drift remediation vision from the
[Platform Engineering for the Agentic AI Era](https://devblogs.microsoft.com/all-things-azure/platform-engineering-for-the-agentic-ai-era/)
manifesto. Drift detection is continuous, contextual, and adaptive — agents
reason about drift, classify it, and propose fixes for human approval.

## Deployment Discovery

1. Scan `.azure/deployments/` for all directories containing a `state.json`
2. Skip deployments where `metadata.json` has `"status": "destroyed"` or `"status": "destroy-requested"` — those are intentionally gone.
3. For **every other** deployment (including `failed` — failed deploys often leave partial infrastructure behind that users then modify manually), attempt drift detection. Resolve the resource group from `state.json .resourceGroup`, falling back to `metadata.json .resourceGroup` when empty.

## Drift Detection Process

### STEP 0 — MANDATORY: Verify snapshots exist before doing anything else

The pre-step job (`Snapshot current Azure state for all tracked deployments`) runs **before** this agent step and writes snapshot files to the workspace at `.drift-snapshots/` (relative to repo root, i.e. `$GITHUB_WORKSPACE/.drift-snapshots/`). You MUST begin your analysis by running these shell commands **in order**:

```bash
ls -la .drift-snapshots/
cat .drift-snapshots/INVENTORY.md
```

The `INVENTORY.md` file is authoritative — it is generated by the pre-step and lists **every** snapshot file that was produced, the status of each, and any captured errors. If `INVENTORY.md` exists, **the pre-step ran successfully** — do NOT claim "no snapshots were produced" or "drift pre-step did not run". If a specific deployment's status is `az-error`, use the captured `.error` field from its `.status.json` to explain the failure — do not invent a cause.

Only if `ls .drift-snapshots/` returns a "No such file or directory" error is the pre-step genuinely missing. In that case — and only in that case — report it as an infrastructure failure. Any other interpretation is a hallucination and must be avoided.

The snapshot file paths you will read (all relative to repo root):
- `.drift-snapshots/INVENTORY.md` — human-readable summary (read this first)
- `.drift-snapshots/<deployment-id>.status.json` — status + error code + error text
- `.drift-snapshots/<deployment-id>.json` — flat `az resource list` output (existence diff)
- `.drift-snapshots/<deployment-id>.details.json` — full `az resource show` bodies (property diff)
- `.drift-snapshots/<deployment-id>.dns.json` — private DNS record sets (DNS diff)

### Per-deployment workflow

For each deployment:

1. **Load desired state** — Read `template.json`, `state.json`, and `metadata.json`.
2. **Load snapshot status** — Read `.drift-snapshots/<deployment-id>.status.json`. Its `status` field is one of:
   - `ok` — `.drift-snapshots/<id>.json` contains the live resource list. Proceed with drift comparison.
   - `rg-not-found` — resource group no longer exists in Azure. Report as **Critical** finding (stale IaC state: resources were deleted outside Git-Ape). Recommend running the destroy workflow to reconcile state.
   - `auth-failed` — the pre-step could not authenticate. Report as a snapshot failure; do not classify as drift.
   - `az-error` — some other `az` CLI error. Include the captured `.error` in the snapshot-failures section verbatim.
   - `no-resource-group` — neither `state.json` nor `metadata.json` has a resource group. Report as a data-quality issue in the snapshot-failures section.
   - `skipped` — deployment intentionally skipped (destroyed / destroy-requested). Omit from drift analysis.
   - File missing entirely — pre-step didn't run for this deployment; treat as `az-error` with message "no snapshot produced".
3. **Compare** (only when status is `ok`) — Perform **all three** passes and report every finding:
   - **Existence diff** — enumerate resources in `template.json` vs `.drift-snapshots/<id>.json` by type+name. Missing / extra resources are drift.
   - **Property diff — MANDATORY, every resource, every property** — `.drift-snapshots/<id>.details.json` is an array of full `az resource show` outputs. For **each** live resource, walk its `properties` object recursively and compare against the corresponding `properties` block in the IaC `template.json` resource entry. Report **every** value mismatch you find. Examples of properties that MUST be diffed (non-exhaustive):
     - **Network Interfaces** — `dnsSettings.dnsServers`, `dnsSettings.internalDnsNameLabel`, `enableAcceleratedNetworking`, `enableIPForwarding`, `ipConfigurations[].properties.{privateIPAddress,privateIPAllocationMethod,subnet.id,publicIPAddress.id,loadBalancerBackendAddressPools,applicationSecurityGroups}`, `networkSecurityGroup.id`
     - **Virtual Machines** — `hardwareProfile.vmSize`, `storageProfile.imageReference.*`, `storageProfile.osDisk.{createOption,caching,managedDisk.storageAccountType,diskSizeGB}`, `osProfile.{computerName,adminUsername,linuxConfiguration.disablePasswordAuthentication}`, `networkProfile.networkInterfaces[].id`, `diagnosticsProfile.bootDiagnostics.enabled`, `securityProfile.*`, `identity.*`
     - **Key Vaults** — `tenantId`, `sku.*`, `enableRbacAuthorization`, `enableSoftDelete`, `softDeleteRetentionInDays`, `enablePurgeProtection`, `publicNetworkAccess`, `networkAcls.{defaultAction,bypass,ipRules,virtualNetworkRules}`, `accessPolicies[]`
     - **Storage Accounts** — `sku.name`, `kind`, `accessTier`, `allowBlobPublicAccess`, `allowSharedKeyAccess`, `minimumTlsVersion`, `supportsHttpsTrafficOnly`, `networkAcls.*`, `encryption.*`, `publicNetworkAccess`, `allowCrossTenantReplication`
     - **App Services / Function Apps** — `httpsOnly`, `siteConfig.{minTlsVersion,ftpsState,http20Enabled,alwaysOn,linuxFxVersion,appSettings[],connectionStrings[],ipSecurityRestrictions[]}`, `identity.*`, `keyVaultReferenceIdentity`, `publicNetworkAccess`
     - **Container Apps / Container App Environments** — `configuration.{ingress.*,secrets[],registries[],activeRevisionsMode}`, `template.{containers[].{image,resources,env[]},scale.*}`, `managedEnvironmentId`, `workloadProfileName`
     - **NSGs** — `securityRules[].properties.{access,direction,priority,protocol,sourceAddressPrefix,sourcePortRange,destinationAddressPrefix,destinationPortRange,sourceAddressPrefixes,sourcePortRanges,destinationAddressPrefixes,destinationPortRanges}`
     - **VNets / Subnets** — `addressSpace.addressPrefixes`, `subnets[].properties.{addressPrefix,networkSecurityGroup.id,routeTable.id,serviceEndpoints[],privateEndpointNetworkPolicies,privateLinkServiceNetworkPolicies,delegations[]}`, `dhcpOptions.dnsServers`, `enableDdosProtection`
     - **Private Endpoints** — `privateLinkServiceConnections[].properties.{privateLinkServiceId,groupIds}`, `subnet.id`, `customDnsConfigs[]`, `privateDnsZoneGroup.*`
     - **Tags** (all resource types) — compare every tag key/value
     Ignore **only** these Azure-managed noise fields: `etag`, `provisioningState`, `resourceGuid`, top-level `id`, top-level `type`, `systemData.*`, auto-added tags matching `hidden-*` or `createdAt*`, and any `properties.*.id` sub-field that's just a self-reference.
     For every mismatch found, add a row to the per-deployment drift detail table. Use the JSON pointer as the `Property` column (e.g., `properties.dnsSettings.dnsServers`). Severity follows the classification below.
   - **DNS record-set diff** — for each `Microsoft.Network/privateDnsZones` in the template, compare record sets in `.drift-snapshots/<id>.dns.json` (map keyed by zone name) against the IaC-declared record sets. Flag any missing, extra, or value-changed records (A, AAAA, CNAME, TXT, SOA, etc.).
   An `ok` status with `resourceCount: 0` means the RG exists but is empty, which is itself a Critical finding for any non-empty IaC template.
4. **Classify** each detected difference into one of three severity levels:

### Severity Classification

- **Critical** (security-relevant drift):
  - HTTPS enforcement disabled (`httpsOnly` changed to false)
  - Firewall rules removed or weakened
  - Authentication/authorization settings changed
  - Managed identity removed
  - TLS version downgraded
  - Shared key access re-enabled on storage
  - FTP state changed from Disabled
  - Public network access enabled unexpectedly

- **Warning** (operational drift):
  - SKU or tier changes
  - Tag modifications
  - App settings changed (non-security)
  - Scale settings modified
  - Runtime version changes

- **Info** (cosmetic drift):
  - Description or metadata changes
  - Resource tags added by Azure Policy (e.g., `createdDate`)
  - Display name changes

## Anti-Flapping Logic

Before reporting drift in the status issue, check cache memory for recent drift history:

1. **Persistence threshold** — Applies ONLY to **existence** drift (resource missing / extra), which can flap during Azure transient API issues. On first detection, record in cache memory and place the finding in the **Suppressed findings** section of the status issue with a `(first-detect)` annotation. On second consecutive detection, surface it in the main **Drift Detail** table.
2. **Property-level and DNS-record drift are NOT subject to persistence threshold.** These are deterministic reads from the Azure control plane. Report them in the main drift table on the very first detection. Do NOT place them in "Suppressed findings" — they must appear in the per-deployment **Drift Detail** subsection with full Expected / Actual values.

The "Suppressed findings" table in the status issue is reserved exclusively for **existence** drift waiting on its second detection. Every property mutation the snapshot diff finds MUST appear in the main drift detail, never suppressed.

## Output: Single Status Issue

This workflow produces **exactly one** GitHub issue per run — a rolling drift status dashboard. It does NOT open pull requests, remediation branches, or per-drift issues. All drift findings, remediation guidance, and suggested next steps live inside the single status issue described in the next section.

For each deployment with Warning or Critical drift, include a **Drift Detail** subsection in the status issue with:
- An Expected-vs-Actual table of drifted properties/resources
- **Remediation guidance** written out in prose — for each drift item, describe both options the human reviewer has:
  - **Revert to IaC:** the `az` command(s) or redeploy steps needed to restore Azure to the IaC-defined state
  - **Adopt Azure state:** the exact file path and JSON patch fragment the reviewer would apply to `template.json` / `parameters.json` to codify the current Azure configuration
- Do NOT create branches, commits, or PRs. Do NOT call `create_pull_request`.

For **Critical** drift, mention `security` and `priority:critical` labels in the status issue body so triagers can apply them (the workflow itself only applies the `drift-status` label).

For **Info** drift, log to cache memory only — no separate issue; still surface in the main drift table if relevant.

## Drift Report Format

Include this block inside each **Drift Detail** subsection of the status issue:

```markdown
## Drift Detection Report

**Deployment:** <deployment-id>
**Resource Group:** <resource-group>
**Checked:** <timestamp>
**Resources Analyzed:** <count>

### Summary
- 🔴 Critical: <count> properties
- 🟡 Warning: <count> properties
- 🔵 Info: <count> properties

### Details

| Resource | Property | Expected (IaC) | Actual (Azure) | Severity |
|----------|----------|-----------------|----------------|----------|
| ... | ... | ... | ... | 🔴/🟡/🔵 |
```

## Drift History

After completing analysis, update cache memory with:
- Timestamp of this run
- List of all detected drift (deployment, resource, property, severity)
- Actions taken (reported, suppressed by persistence threshold)

This enables the anti-flapping logic on subsequent runs and provides an audit trail.

## Process Summary

1. Discover active deployments from `.azure/deployments/`
2. For each deployment, query Azure and compare against stored ARM templates
3. Classify drift by severity (Critical / Warning / Info)
4. Apply anti-flapping persistence threshold to existence drift
5. Emit exactly one rolling status issue summarizing every deployment and every drift with inline remediation guidance
6. Update cache memory with drift history

## Required Completion Behavior

You MUST **always** call `create-issue` exactly once before finishing. This is a
rolling status dashboard: `close-older-issues: true` ensures only the latest
status issue is open at any time. Never finish the run silently and never call
`noop` — always produce a status issue.

**Do NOT call `create_pull_request`.** This workflow does not create PRs,
branches, commits, or code-push safe outputs. Only `create_issue` is allowed.
If you think a code change is needed, describe it in the status issue body
instead — the human reviewer will open any PR manually.

> ### CRITICAL: Call `create_issue` yourself
>
> The safe-output tools (`create_issue`, `noop`, `missing_tool`,
> `missing_data`) are **only available in this top-level agent context**.
> They do NOT exist inside spawned subagents or skills.
>
> - Do **NOT** delegate issue creation to a `General-purpose` subagent,
>   a `skill(...)` invocation, or any other nested agent.
> - Do the analysis yourself, then directly invoke `create_issue` as a
>   top-level tool call in your final turn.
> - If a tool call returns `Tool '...' does not exist`, you are almost
>   certainly inside a subagent — pop back to the top-level agent and retry.

### Status issue — required format

Title: `[drift-status] Drift report — <YYYY-MM-DD> — <N> deployment(s), <M> drifted`

Labels: `drift-status` (already configured). If **any** Critical drift is found,
mention `security` and `priority:critical` in the body so triagers can add them.

The issue must include **one row per directory under `.azure/deployments/`**
(every tracked deployment — active, destroyed, failed, destroy-requested — not
just active ones). Resolve each row's values from that deployment's
`metadata.json`, `state.json`, and `.drift-snapshots/<id>.json`.

Link format — use repo-relative blob links on the `main` branch and Azure
portal deep links built from `state.json`:

- Architecture: `[diagram](../blob/main/.azure/deployments/<id>/architecture.md)`
- State: `[state](../blob/main/.azure/deployments/<id>/state.json)`
- Template: `[template](../blob/main/.azure/deployments/<id>/template.json)`
- Azure Portal (resource group):
  `https://portal.azure.com/#@/resource/subscriptions/<subscription>/resourceGroups/<rg>/overview`
  where `<subscription>` is `state.json .subscription` and `<rg>` is
  `state.json .resourceGroup`. Only include the portal link for deployments
  whose lifecycle is `active` or `destroy-requested` — omit for destroyed /
  failed rows (render `—` in that column).

Use the literal `main` branch in repo links; the deployment files live there
after every successful deploy.

Body template (fill in every section, even when empty):

```markdown
## Drift Status Dashboard

**Run:** <workflow-run-url>
**Checked at:** <ISO-8601 timestamp>
**Tracked deployments:** <total dirs under .azure/deployments>
**Active:** <n> · **Destroyed:** <n> · **Failed/Other:** <n>
**Deployments with drift:** <M>

### Summary

| Severity | Count |
|----------|-------|
| 🔴 Critical | <n> |
| 🟡 Warning | <n> |
| 🔵 Info | <n> |

### Deployments

One row for every directory in `.azure/deployments/`.

| Deployment | Resource Group | Lifecycle | Drift | Severity | Architecture | State | Azure Portal |
|------------|----------------|-----------|-------|----------|--------------|-------|--------------|
| `<id>` | `<rg>` | ✅ active / 💀 destroyed / ❌ failed / ⏳ destroy-requested | ✅ none / ⚠️ N drift(s) / ⏭️ skipped | 🔴/🟡/🔵/— | [diagram](../blob/main/.azure/deployments/<id>/architecture.md) | [state](../blob/main/.azure/deployments/<id>/state.json) | [open](https://portal.azure.com/#@/resource/subscriptions/<sub>/resourceGroups/<rg>/overview) or `—` |

Lifecycle emoji mapping:
- ✅ active — `metadata.status` is `succeeded` and not destroy-requested
- ⏳ destroy-requested — `metadata.status` is `destroy-requested`
- 💀 destroyed — `metadata.status` is `destroyed`
- ❌ failed — `metadata.status` is `failed` or state is missing
- Drift column is `⏭️ skipped` for anything that isn't active

### Drift Detail

For every drifted deployment, include one subsection:

#### `<deployment-id>` — [architecture](../blob/main/.azure/deployments/<id>/architecture.md) · [state](../blob/main/.azure/deployments/<id>/state.json) · [Azure Portal](https://portal.azure.com/#@/resource/subscriptions/<sub>/resourceGroups/<rg>/overview)

<details><summary>Architecture diagram</summary>

Embed the first ` ```mermaid ... ``` ` fenced block verbatim from
`.azure/deployments/<id>/architecture.md`. GitHub renders mermaid inline.
If no mermaid block exists, write `_No diagram available._`.

</details>

| Resource | Property | Expected (IaC) | Actual (Azure) | Severity |
|----------|----------|----------------|----------------|----------|
| ... | ... | ... | ... | 🔴/🟡/🔵 |

**Remediation options** (no PRs are created by this workflow — apply manually):

- **Revert to IaC:** describe the `az` command(s) or redeploy steps needed to restore Azure to the IaC-defined state for each drifted item.
- **Adopt Azure state:** describe the exact file path and JSON patch fragment to apply to `template.json` / `parameters.json` to codify the current Azure configuration.

### No-drift deployments

Bulleted list of active deployments with zero drift (or `_none_`).

### Suppressed findings

Drift suppressed by anti-flapping (debounce / cooldown / persistence-threshold).
Empty section if none.

### Snapshot failures

Deployments where the pre-step could not compare live Azure state to IaC.
Derive each row from `.drift-snapshots/<id>.status.json`:

| Deployment | Resource Group | Snapshot Status | Cause / Action |
|------------|----------------|-----------------|----------------|
| `<id>` | `<rg>` | `rg-not-found` / `auth-failed` / `az-error` / `no-resource-group` / `missing` | Human-readable explanation. For `rg-not-found`: "RG was deleted outside Git-Ape — run the destroy workflow to reconcile state." For `auth-failed`: "Pre-step federated identity could not authenticate to the subscription." For `no-resource-group`: "state.json and metadata.json both have empty `resourceGroup` — deploy workflow bug, fix forward." |

Also include here, as a **Critical** snapshot finding, any deployment whose
`status.json` is `ok` but `resourceCount: 0` while its `template.json` defines
one or more resources — that means every managed resource vanished from Azure.

Empty section if no snapshot failures.

### Edge cases

- If `.azure/deployments/` has no directories at all, state
  `_No deployments tracked in this repository._` and set all counts to 0.
- If every tracked deployment is destroyed/failed (no active ones), still post
  the full deployments table so users can see lifecycle at a glance.
```

The status issue is the only output of this workflow. No pull requests, no
remediation branches, no commits — inline remediation guidance in the status
issue body replaces the previous two-PR-per-deployment flow.
