# Environment Setup

> Choose one of three options to set up your development environment.

Git-Ape works in any VS Code-compatible environment. Pick the option that fits your setup and follow the steps.

## Option A: GitHub Codespaces (Browser)

The fastest way to start — everything runs in the cloud.

1. Navigate to the Git-Ape repository on GitHub.
2. Click **Code** > **Codespaces** > **Create codespace on main**.
3. Wait for the container to build (2-3 minutes on first launch, ~30 seconds on subsequent launches).
4. The post-create script installs additional tools automatically.

> **Already have a Codespace?** Click on your existing one to resume.

**Tools:** All pre-installed — no action needed.

**Sign in to Azure (Tracks 2-4):**

```bash
az login --use-device-code
```

```powershell
az login --use-device-code
```

**Sign in to GitHub CLI:**

The GitHub CLI is usually pre-authenticated in Codespaces. Verify with `gh auth status`.

---

## Option B: VS Code + Dev Containers (Local Docker)

Run the same pre-configured environment on your machine.

**Prerequisites:**

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or Podman)
- [VS Code](https://code.visualstudio.com/)
- [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

**Steps:**

1. Clone the repository:

   **Bash / macOS / Linux:**

   ```bash
   git clone https://github.com/Azure/git-ape.git
   cd git-ape
   code .
   ```

   **PowerShell / Windows:**

   ```powershell
   git clone https://github.com/Azure/git-ape.git
   Set-Location git-ape
   code .
   ```

2. When prompted, click **Reopen in Container** (or run `Dev Containers: Reopen in Container` from the Command Palette).
3. Wait for the container to build and post-create scripts to finish.

**Tools:** All pre-installed — same as Codespaces.

**Sign in to Azure (Tracks 2-4):**

```bash
az login
```

```powershell
az login
```

**Sign in to GitHub CLI:**

```bash
gh auth login
```

```powershell
gh auth login
```

---

## Option C: VS Code Local (No Container)

Run directly on your machine without Docker.

**Prerequisites:**

Install the required CLI tools for your OS:

**macOS (Homebrew):**

```bash
brew install azure-cli gh jq
```

**Ubuntu / Debian:**

```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
sudo apt-get install -y gh jq
```

**Windows (winget):**

```powershell
winget install Microsoft.AzureCLI
winget install GitHub.cli
winget install jqlang.jq
```

**VS Code extensions — install manually:**

| Extension | Extension ID |
|-----------|-------------|
| GitHub Copilot | `github.copilot` |
| GitHub Copilot Chat | `github.copilot-chat` |
| Azure Resource Groups | `ms-azuretools.vscode-azureresourcegroups` |
| Azure Functions | `ms-azuretools.vscode-azurefunctions` |
| Azure MCP Server | `ms-azuretools.vscode-azure-mcp-server` |

**Configure Azure MCP Server:**

Add these settings to your VS Code `settings.json`:

```json
{
  "azureMcp.serverMode": "namespace",
  "azureMcp.readOnly": false
}
```

**Clone and open the repository:**

**Bash / macOS / Linux:**

```bash
git clone https://github.com/Azure/git-ape.git
cd git-ape
code .
```

**PowerShell / Windows:**

```powershell
git clone https://github.com/Azure/git-ape.git
Set-Location git-ape
code .
```

**Sign in to Azure (Tracks 2-4):**

```bash
az login
```

```powershell
az login
```

**Sign in to GitHub CLI:**

```bash
gh auth login
```

```powershell
gh auth login
```

---

## What's Included (Options A and B)

The dev container comes with everything pre-installed:

| Tool | Purpose |
|------|---------|
| Azure CLI | Azure resource management and deployments |
| GitHub CLI | PR creation, issue management, workflow dispatch |
| GitHub Copilot + Chat | AI-powered coding assistant with Git-Ape agents |
| Python 3.12 | Scripting and IaC scanning (Checkov) |
| Node.js 24 | Tooling, automation scripts, and Docusaurus docs |
| PowerShell | PSRule, ARM-TTK validation |
| jq | JSON parsing |
| Checkov | IaC security scanner |
| PSRule for Azure | WAF-aligned template validation |
| ARM-TTK | ARM Template Test Toolkit |

> **Option C users:** You only need Azure CLI, GitHub CLI, and jq for the workshop labs. The other tools are used by automated checks and are optional for local setups.

## Azure MCP Server

The Azure MCP server is preconfigured in container-based environments (Options A and B):

- **Server mode:** `namespace` (tools organized by Azure service)
- **Read-only:** `false` (allows deployments)

Option C users must add these settings manually (see Option C instructions above).

## Verify Your Setup

Run the built-in prerequisite check in Copilot Chat:

```text
/prereq-check
```

You should see all tools passing with green checkmarks:

```
✅ Azure CLI (az) — installed
✅ GitHub CLI (gh) — installed
✅ jq — installed
✅ git — installed
```

> **Track 1 participants:** You can skip Azure sign-in. Track 1 works entirely within Copilot Chat without deploying real resources.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Dev container build fails (Options A/B) | Check the creation log for errors. Try rebuilding the container. For Codespaces, try creating a new Codespace. |
| Docker not running (Option B) | Start Docker Desktop (or Podman) before opening the project. |
| Tool not found (Option C) | Install missing tools using the commands in Option C above. Run `/prereq-check` to identify what's missing. |
| `az login` fails | In Codespaces, use `az login --use-device-code`. Locally, use `az login` (opens a browser). |
| `gh auth login` hangs | Try `gh auth login --web` for browser-based flow. |
| Copilot Chat not available | Verify your Copilot subscription at [github.com/settings/copilot](https://github.com/settings/copilot). |
| Extensions missing (Options A/B) | Reload the window: `Ctrl+Shift+P` > `Developer: Reload Window`. |
| Slow performance (Option A) | Stop unused Codespaces at [github.com/codespaces](https://github.com/codespaces) to free resources. |
