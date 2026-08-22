# Troubleshooting

> Common issues and solutions across all workshop tracks.

## Workshop pre-flight failures

These are the failure modes that bite attendees BEFORE the workshop content even starts. Each row maps to a specific gap the [prerequisites](prerequisites.md) checklist tries to catch.

| Symptom | Root cause | Fix |
|---|---|---|
| `AADSTS700213 No matching federated identity record` on first deploy | GitHub org uses customized OIDC subject template (e.g., the Azure org). Federated credential subjects must match. | Run `gh api orgs/<org>/actions/oidc/customization/sub --jq '.use_default'`. If `false`, re-run `/git-ape-onboarding` so it auto-detects and uses ID-based subjects. See [identity-model.md](identity-model.md). |
| `RoleAssignmentNotFound` immediately after Lab 1 onboarding | Azure RBAC propagation delay (60-90s) after creating a fresh role assignment | Wait 90 seconds and retry. If still failing after 5 min, check `az role assignment list --assignee-object-id <SP_OBJECT_ID> --all -o table`. |
| Onboarding fails at `az ad app create` with `Authorization_RequestDenied` | Tenant policy blocks "Users can register applications" | Ask tenant admin to enable it OR pre-create the app registration and grant you Owner. |
| Subscription RBAC writes silently fail | Subscription state is not `Enabled` | `az account show --query "{name:name,state:state}" -o table`. If state is `Disabled`/`PastDue`/`Warned`, switch subscription or contact billing admin. |
| First deploy fails with `MissingSubscriptionRegistration` | Resource provider not pre-registered for the subscription | `az provider register --namespace Microsoft.<X> --wait`. The prereqs file lists the providers each track needs. |
| GitHub Actions workflow fails: `GitHub Actions is not permitted to create or approve pull requests` | Repo setting "Allow GH Actions to create and approve PRs" is OFF (default for org repos) | Repo Settings → Actions → General → Workflow permissions → enable. |

## Authentication

| Issue | Solution |
|-------|----------|
| `az login` fails in Codespaces | Use `az login --use-device-code` for browser-based authentication. |
| `az login` fails locally | Use `az login` (opens a browser window). If on a headless server, use `az login --use-device-code`. |
| `AADSTS700213` error during OIDC setup | Your GitHub org uses a customized OIDC subject template. The onboarding skill detects this automatically. For manual setup, see the [Onboarding Guide](../../docs/ONBOARDING.md). |
| `gh auth login` hangs | Try `gh auth login --web` for browser-based flow. |
| "Not authorized" on Azure operations | Verify your role: `az role assignment list --assignee $(az ad signed-in-user show --query id -o tsv) --output table` |

## Copilot Chat

| Issue | Solution |
|-------|----------|
| `@git-ape` not recognized | Verify the Git-Ape plugin is installed. Check Copilot Chat extensions panel. |
| Agent responds but won't deploy | Confirm Azure MCP server is configured. Check VS Code settings for `azureMcp.serverMode`. |
| Copilot Chat not available | Verify your Copilot subscription at [github.com/settings/copilot](https://github.com/settings/copilot). |
| Slow responses | Large ARM templates take longer to generate. Wait 30-60 seconds for multi-resource deployments. |

## Deployment

| Issue | Solution |
|-------|----------|
| "Subscription not registered for resource type" | Register the provider: `az provider register --namespace Microsoft.Web` (or the relevant namespace). |
| Naming conflict (resource already exists) | Git-Ape uses `uniqueString()` for globally unique names. If you hit a conflict, re-run with a different project name. |
| Quota exceeded | Check your subscription quota: `az vm list-usage --location eastus --output table`. Use a different region if at capacity. |
| Security gate BLOCKED | This is expected behavior in Track 2 Lab 3. Review the security findings and fix the identified issues before retrying. |
| Deployment timeout | Large deployments (Container Apps, SQL) can take 5-10 minutes. Check progress: `az deployment sub show --name <deployment-name>`. |

## GitHub Actions (Track 3)

| Issue | Solution |
|-------|----------|
| `git-ape-plan.yml` fails on PR | Check that OIDC secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`) are set. Run `/git-ape-onboarding` to verify. |
| `/deploy` comment doesn't trigger | The PR must be approved first. Approve the PR, then comment `/deploy`. |
| Workflow not triggered on PR | Verify the PR modifies files under `.azure/deployments/**/template.json`. |
| Permission denied on `git push` in workflow | The workflow needs `contents: write` permission. Check the workflow YAML. |

## Drift Detection (Track 2 Lab 5)

| Issue | Solution |
|-------|----------|
| No drift detected after manual change | Wait 1-2 minutes for Azure to propagate the change, then re-run `/azure-drift-detector`. |
| Drift detector shows "no state.json" | Ensure you completed a deployment first. The drift detector compares against stored state. |

## Environment

| Issue | Solution |
|-------|----------|
| Dev container build fails (Codespaces) | Check the creation log for errors. Try creating a new Codespace. |
| Dev container build fails (local Docker) | Ensure Docker Desktop (or Podman) is running. Try `Dev Containers: Rebuild Container` from the Command Palette. |
| Docker not running (Option B) | Start Docker Desktop or Podman before opening the project in VS Code. |
| Tool not found (Option C — local, no container) | Install missing tools using the OS-specific commands in [environment-setup.md](environment-setup.md). Run `/prereq-check` to identify gaps. |
| Azure MCP not configured (Option C) | Add `"azureMcp.serverMode": "namespace"` and `"azureMcp.readOnly": false` to your VS Code `settings.json`. See [environment-setup.md](environment-setup.md). |
| Files not saving | VS Code and Codespaces auto-save by default. If files appear stale, reload the window: `Ctrl+Shift+P` > `Developer: Reload Window`. |
| Terminal unresponsive | Open a new terminal: `` Ctrl+` `` or `Terminal` > `New Terminal`. |
