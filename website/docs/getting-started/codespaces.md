---
title: "GitHub Codespaces"
sidebar_label: "Codespaces"
sidebar_position: 4
description: "Dev container and Codespaces setup"
---

# GitHub Codespaces Dev Environment

Git-Ape ships a single [dev container](https://containers.dev/) configuration that covers everything — authoring agents, skills, prompts, and ARM templates, running IaC scans, deploying to Azure, **and** editing the Docusaurus documentation site.

## What's Included

| Configuration | Use it when you want to… | Image |
|---------------|--------------------------|-------|
| **Agent Engineering** (`.devcontainer/`) | Author agents, skills, prompts, ARM templates, run IaC scans, deploy to Azure, and edit/build the docs site | `mcr.microsoft.com/devcontainers/python:3-3.12-bookworm` |

The config is detected automatically by Codespaces and the VS Code Dev Containers extension.

### Tooling

Full toolchain for agent authoring, ARM template work, IaC scanning, Azure deployments, and Docusaurus docs.

- **Base image**: `python:3-3.12-bookworm`
- **Features**: Azure CLI, GitHub CLI, Copilot CLI, PowerShell, Node.js 24, common-utils (Zsh + Oh My Zsh)
- **Post-create**: installs Checkov, ARM-TTK, PSRule for Azure, the [waza](https://github.com/microsoft/waza) skill-eval CLI, the website npm dependencies, and in-container linters (ShellCheck, actionlint, markdownlint, yamllint, check-jsonschema, PSScriptAnalyzer) — in parallel
- **Forwarded port**: 3333 (Docusaurus dev/serve)
- **Extensions**: GitHub Copilot, Copilot Chat, Azure Resource Groups, Azure Functions, Azure MCP Server, PSRule, [Chat Customizations Evaluations](https://github.com/microsoft/vscode-chat-customizations-evaluation), Mermaid Preview, MDX, ESLint, markdownlint, ShellCheck, YAML, GitHub Actions, PowerShell
- **Settings**: Azure MCP server preconfigured (`namespace` mode, read/write enabled); `chatCustomizationsEvaluations.waza.command` set to `waza`
- **Remote user**: `vscode`

## Quick Start

### Option 1: GitHub Codespaces (recommended)

1. Navigate to the [Git-Ape repository](https://github.com/Azure/git-ape).
2. Click **Code** → **Codespaces** → **Create codespace on main**.
3. Wait for the container to build and the post-create setup to finish.
4. Sign in to Azure with `az login --use-device-code` when prompted.

### Option 2: VS Code Dev Containers (local)

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) and the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers).
2. Clone the repository and open it in VS Code.
3. Run **Dev Containers: Reopen in Container** from the command palette.
4. Sign in to Azure with `az login`.

## VS Code Tasks

The Docusaurus tasks below live in `.vscode/tasks.json` and are available via **Terminal → Run Task** (or `⇧⌘B`):

| Task | What it does |
|------|--------------|
| **Docs: Dev Server** | Starts Docusaurus in hot-reload mode on port 3333 |
| **Docs: Build (local)** | Generates docs and builds with `baseUrl=/` for local preview |
| **Docs: Build (production)** | Generates docs and builds with `baseUrl=/git-ape/` for GitHub Pages |
| **Docs: Serve** | Builds locally and serves the static output on port 3333 |
| **Docs: Generate** | Runs `generate-docs.js` to regenerate auto-generated pages |
| **Docs: Install** | Installs website npm dependencies |

## After Setup

Once the environment is ready:

1. **Sign in to Azure**: Run `az login`. For Codespaces, `az login --use-device-code` works best.
2. **Verify the setup**: Run `az account show` to confirm your subscription.
3. **Start using Git-Ape**: Open Copilot Chat and try `@git-ape deploy a Python function app`.

## Customization

- **Dev container features**: Add entries to the `features` object in `.devcontainer/devcontainer.json`.
- **Post-create tools**: Add installation commands to `.devcontainer/post-create.sh`.
- **VS Code extensions**: Add extension IDs to `customizations.vscode.extensions` in the same `devcontainer.json`.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Codespace build fails | Check the creation log for errors. Common cause: feature version conflicts. |
| `az login` fails in Codespaces | Use `az login --use-device-code` for browser-based auth. |
| ARM-TTK not found | Run `pwsh` and verify the profile: `Get-Module arm-ttk -ListAvailable`. ARM-TTK and PSRule require PowerShell. |
| Checkov not found | Run `pip install --user checkov` manually. |
| Extensions missing | Reload the window (`Ctrl+Shift+P` → `Developer: Reload Window`). |
| Docs site broken locally | Use the **Docs: Build (local)** task or set `DOCUSAURUS_BASE_URL=/` before building. The production build uses `/git-ape/` as the base path. |
| Port 3333 already in use | Run `lsof -ti:3333 \| xargs kill -9` to free the port. |
