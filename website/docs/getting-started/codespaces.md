---
title: "GitHub Codespaces"
sidebar_label: "Codespaces"
sidebar_position: 4
description: "Dev container and Codespaces setup"
---

# GitHub Codespaces Dev Environment

Git-Ape includes a ready-to-use [dev container](https://containers.dev/) configuration so you can start contributing or using the project instantly in GitHub Codespaces (or any dev container-compatible tool like VS Code Dev Containers).

## Quick Start

### Option 1: GitHub Codespaces (recommended)

1. Navigate to the [Git-Ape repository](https://github.com/Azure/git-ape).
2. Click **Code** → **Codespaces** → **Create codespace on main**.
3. Wait for the container to build and the post-create setup to finish.
4. Sign in to Azure with `az login` when prompted.

### Option 2: VS Code Dev Containers (local)

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) and the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers).
2. Clone the repository and open it in VS Code.
3. When prompted, click **Reopen in Container** (or run the command `Dev Containers: Reopen in Container`).
4. Sign in to Azure with `az login`.

## What's Included

### Base Image

`mcr.microsoft.com/devcontainers/base:ubuntu` — a lightweight Ubuntu image maintained by Microsoft.

### Dev Container Features

| Feature | Version | Purpose |
|---------|---------|---------|
| Azure CLI | latest | Azure resource management and deployments |
| GitHub CLI | latest | PR creation, issue management, workflow dispatch |
| Python | 3.12 | Checkov IaC scanner and scripting |
| Node.js | 20 | Tooling and automation scripts |
| PowerShell | latest | PSRule, ARM-TTK, and Azure PowerShell modules |
| Common utilities | — | Zsh with Oh My Zsh as default shell |

### Post-Create Setup

The `post-create.sh` script runs automatically after the container is built and installs:

- **Checkov** — IaC security scanner supporting ARM, Bicep, and Terraform templates.
- **PSRule for Azure** — WAF-aligned validation rules for ARM and Bicep templates.
- **ARM-TTK** — Microsoft's ARM Template Test Toolkit for template validation.
- **Website dependencies** — `npm install` in the `website/` directory for Docusaurus docs.

### VS Code Tasks

Pre-configured tasks are available via **Terminal → Run Task** (or `⇧⌘B`):

| Task | What it does |
|------|-------------|
| **Docs: Dev Server** | Starts Docusaurus in hot-reload mode on port 3333 |
| **Docs: Build (local)** | Generates docs and builds with `baseUrl=/` for local preview |
| **Docs: Build (production)** | Generates docs and builds with `baseUrl=/git-ape/` for GitHub Pages |
| **Docs: Serve** | Builds locally and serves the static output on port 3333 |
| **Docs: Generate** | Runs `generate-docs.js` to regenerate auto-generated pages |
| **Docs: Install** | Installs website npm dependencies |

### VS Code Extensions

The following extensions are automatically installed in the container:

| Extension | Purpose |
|-----------|---------|
| GitHub Copilot | AI coding assistant |
| GitHub Copilot Chat | Chat-based AI assistance |
| Azure Resource Groups | Browse and manage Azure resource groups |
| Azure Functions | Develop and deploy Azure Functions |
| Azure MCP Server | Azure MCP integration for Copilot agents |
| PSRule | Run PSRule validation from VS Code |

### VS Code Settings

The Azure MCP server is preconfigured with:

- `azureMcp.serverMode`: `namespace` — organizes tools by Azure service.
- `azureMcp.readOnly`: `false` — allows read and write operations.

## After Setup

Once the environment is ready:

1. **Sign in to Azure**: Run `az login` to authenticate. For Codespaces, `az login --use-device-code` works best.
2. **Verify the setup**: Run `az account show` to confirm your subscription.
3. **Start using Git-Ape**: Open Copilot Chat and try `@git-ape deploy a Python function app`.

## Customization

To add features or tools to the dev container:

- **Dev container features**: Add entries to the `features` object in `.devcontainer/devcontainer.json`.
- **Post-create tools**: Add installation commands to `.devcontainer/post-create.sh`.
- **VS Code extensions**: Add extension IDs to `customizations.vscode.extensions` in `.devcontainer/devcontainer.json`.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Codespace build fails | Check the creation log for errors. Common cause: feature version conflicts. |
| `az login` fails in Codespaces | Use `az login --use-device-code` for browser-based auth. |
| ARM-TTK not found | Run `pwsh` and verify the profile loaded: `Get-Module arm-ttk -ListAvailable`. |
| Checkov not found | Run `pip install --user checkov` manually. |
| Extensions missing | Reload the window (`Ctrl+Shift+P` → `Developer: Reload Window`). |
| Docs site broken locally | Make sure you use the **Docs: Build (local)** task or set `DOCUSAURUS_BASE_URL=/` before building. The production build uses `/git-ape/` as the base path. |
| Port 3333 already in use | Run `lsof -ti:3333 \| xargs kill -9` to free the port. |
