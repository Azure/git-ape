# Lab 3: Explore Results

> 5 minutes | No Azure required

Understand what Git-Ape generated and where deployment artifacts live.

> **What this teaches you:** every Git-Ape deployment leaves a complete, reviewable audit trail. By the end of this lab you can read each artifact, prove a security finding from its exact ARM property path, and explain why the deployment directory is the unit of truth (not the chat output).

## Step 1: Find the deployment directory

Artifacts are saved under `.azure/deployments/<deployment-id>/`:

```bash
ls .azure/deployments/
# pick the most recent timestamped directory
ls .azure/deployments/deploy-*/
```## Step 2: Artifact contract

Every deployment directory contains these files:

| File | What it is |
|---|---|
| `template.json` | ARM template (unit of truth) |
| `parameters.json` | Parameter values |
| `metadata.json` | status, ID, timestamps |
| `architecture.md` | Mermaid diagram |
| `security-analysis.md` | Per-resource findings with ARM paths |
| `security-gate.json` | Verdict: PASSED, BLOCKED, OVERRIDDEN |
| `cost-estimate.json` | Per-resource cost from Azure Pricing API |
| `policy-assessment.md` | Azure Policy compliance |
| `preflight-report.md` | What-if create/modify/delete |
| `availability-report.md` | Region/SKU/runtime/quota checks |

After deploy you also get `state.json` (resource IDs + stack name, used by destroy) and `tests.json` (integration test results).

## Step 3: Read a security finding properly

A trustworthy finding cites the exact ARM property it verified. Look in `security-analysis.md` for entries like:

```
Storage account: shared key access
  status: PASSED
  ARM property: allowSharedKeyAccess = false
  severity: critical
```

The property is the evidence. If a finding lacks one, it is an assertion not a proof; flag it.## Step 4: Gate verdict

The gate verdict is in security-gate.json with values PASSED, BLOCKED, or OVERRIDDEN. Track 3 CI/CD reads this file.

## Step 5: Post-deploy

state.json has the stack name and resource IDs (required by git-ape-destroy).
tests.json has integration test results.

## Going further

Try Track 2 for a multi-resource deploy with a deliberately broken security gate.

Next: Track 2 -- Deploy Like a Pro.