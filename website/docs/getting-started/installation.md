---
title: "Installation & Prerequisites"
sidebar_label: "Installation"
sidebar_position: 1
description: "Install Git-Ape and verify prerequisites"
---

# Installation & Prerequisites

## Prerequisites

- **Bash shell** (Git Bash on Windows)
- **Azure CLI** (`az`) — signed in with `az login`
- **GitHub CLI** (`gh`) — authenticated
- **jq** and **git**

Run `/prereq-check` in Copilot Chat to verify all tools and auth sessions automatically.

## Install the Plugin

### Option 1: Marketplace (Recommended)

```bash
copilot plugin marketplace add Azure/git-ape
copilot plugin install Azure/git-ape
```

### Option 2: Manual

1. Clone this repository
2. Open it in VS Code with GitHub Copilot enabled
3. Confirm the agents appear in Copilot Chat

## Verify Installation

In Copilot Chat, try:

```
@git-ape hello
```

You should see the Git-Ape orchestrator respond.

## Next Steps

- [Configure Azure access](./azure-setup)
- [Set up OIDC, RBAC, and GitHub environments](./onboarding)
