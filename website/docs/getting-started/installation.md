---
title: "Installation & Prerequisites"
sidebar_label: "Installation"
sidebar_position: 1
description: "Install Git-Ape and verify prerequisites"
---

# Installation & Prerequisites

## Prerequisites

Before you start, make sure you have:

- **A Bash-compatible shell** — macOS and Linux work out of the box. On Windows, install [Git for Windows](https://gitforwindows.org/) and use Git Bash.
- **Azure CLI, GitHub CLI, jq, and git** — installed and authenticated.

:::tip[Quick check]
Run `/prereq-check` in Copilot Chat after installation. It validates every tool and auth session for you and shows platform-specific install commands for anything missing.
:::

## Which installation method should I use?

| Method | Best for | Requirements |
|--------|----------|--------------|
| **VS Code plugin** | Day-to-day Azure deployments from your editor | VS Code + Copilot + `chat.plugins.enabled` |
| **Copilot CLI plugin** | Terminal-first workflows or CI scripting | Copilot CLI |
| **Local dev install** | Contributing to Git-Ape itself | Git clone of the repo |
| **GitHub Codespaces** | Trying Git-Ape without any local setup | GitHub account |

Most users should start with the **VS Code plugin**. If you just want to try Git-Ape without installing anything, jump to [Codespaces](./codespaces).

## Option A: VS Code agent plugin (recommended) {#vscode-plugin}

Your organization must have the `chat.plugins.enabled` setting set to `true`. If you are unsure, ask your admin or try the steps below — VS Code will tell you if plugins are disabled.

1. Add the Git-Ape marketplace to your VS Code `settings.json`:

   [![Open Settings in VS Code](https://img.shields.io/badge/Open_Settings-VS_Code-007ACC?logo=visualstudiocode&logoColor=white)](pathname:///open-settings.html) [![Open Settings in VS Code Insiders](https://img.shields.io/badge/Open_Settings-VS_Code_Insiders-24bfa5?logo=visualstudiocode&logoColor=white)](pathname:///open-settings-insiders.html)

   ```jsonc
   "chat.plugins.marketplaces": [
       "Azure/git-ape"
   ]
   ```

2. Open the Extensions view (`⇧⌘X` on macOS, `Ctrl+Shift+X` on Windows/Linux), search for `@agentPlugins`, find **git-ape**, and select **Install**.

   Alternatively, open the Command Palette (`⇧⌘P` / `Ctrl+Shift+P`), run **Chat: Install Plugin From Source**, and enter `https://github.com/Azure/git-ape`.

3. Verify the agents and skills appear in Copilot Chat — type `@git-ape` or `/prereq-check`.

## Option B: Copilot CLI plugin {#cli-plugin}

```bash
copilot plugin marketplace add Azure/git-ape
copilot plugin install git-ape@git-ape
copilot plugin list   # Should show: git-ape@git-ape
```

## Option C: Local development install {#local-dev}

Use this if you are contributing to Git-Ape or want to test local changes.

```bash
git clone https://github.com/Azure/git-ape.git
```

Register the local checkout in your VS Code `settings.json`:

```jsonc
"chat.pluginLocations": {
    "/absolute/path/to/git-ape": true
}
```

Reload VS Code; the `@git-ape` agent and skills will appear in Copilot Chat.

## Verify installation

In Copilot Chat, type:

```text
@git-ape hello
```

You should see the Git-Ape orchestrator respond. If it does not, reload the VS Code window (`Cmd+Shift+P` → **Developer: Reload Window**).

## What's next?

You have Git-Ape installed. Here is the recommended path depending on what you want to do:

- [VS Code vs Copilot CLI](./vscode-vs-cli) — feature parity and when to pick which surface

```mermaid
flowchart TD
    A["Git-Ape installed<br/>(VS Code or CLI)"] --> B{"What do you want to do?"}
    B -->|"Try it in a sandbox"| C["<a href='./codespaces'>Codespaces</a><br/>Zero-setup dev environment"]
    B -->|"Deploy from VS Code"| D["<a href='./azure-setup'>Azure Setup</a><br/>Configure MCP + Azure CLI"]
    B -->|"Set up CI/CD pipelines"| E["<a href='./onboarding'>Onboarding</a><br/>OIDC, RBAC, GitHub environments"]
    D --> E

    classDef start fill:#e0e7ff,stroke:#4338ca,stroke-width:2px,color:#1e1b4b
    classDef gate fill:#fde68a,stroke:#b45309,stroke-width:1px,color:#7c2d12
    classDef next fill:#dbeafe,stroke:#1f6feb,stroke-width:1px,color:#0b3d91
    class A start
    class B gate
    class C,D,E next
```

- **[Azure Setup](./azure-setup)** — Connect Git-Ape to your Azure subscription so it can deploy resources.
- **[Onboarding](./onboarding)** — Configure OIDC, RBAC, and GitHub environments for CI/CD pipelines.
- **[Codespaces](./codespaces)** — Spin up a ready-to-use dev environment in your browser.
