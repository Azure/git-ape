---
title: "Installation & Prerequisites"
sidebar_label: "Installation"
sidebar_position: 1
description: "Install Git-Ape and verify prerequisites"
---

# Installation & Prerequisites

## Prerequisites

- A Bash-compatible shell (use `git-bash` on Windows). Other shells are untested.
- Azure CLI (`az`), GitHub CLI (`gh`), `jq`, and `git` installed and authenticated.
- Run `/prereq-check` in Copilot Chat to verify everything is in place.

## Install the Plugin

Git-Ape ships as a [VS Code agent plugin](https://code.visualstudio.com/docs/copilot/customization/agent-plugins) and as a GitHub Copilot CLI plugin. Pick the path that matches how you use Copilot.

### Option A: VS Code agent plugin (recommended for VS Code users)

Prerequisites: VS Code with GitHub Copilot enabled and the `chat.plugins.enabled` setting set to `true` (managed at the organization level).

1. Add the marketplace in your VS Code `settings.json`:

   ```jsonc
   "chat.plugins.marketplaces": [
       "Azure/git-ape"
   ]
   ```

2. Open the Extensions view (`⇧⌘X` on macOS, `Ctrl+Shift+X` on Windows/Linux), search for `@agentPlugins`, find **git-ape**, and select **Install**.
3. Alternatively, open the Command Palette (`⇧⌘P` on macOS, `Ctrl+Shift+P` on Windows/Linux), run **Chat: Install Plugin From Source**, and enter `https://github.com/Azure/git-ape`.
4. Verify the agents and skills appear in Copilot Chat (for example, type `@git-ape` or `/prereq-check`).

### Option B: Copilot CLI plugin

```bash
copilot plugin marketplace add Azure/git-ape
copilot plugin install git-ape@git-ape
copilot plugin list   # Should show: git-ape@git-ape
```

### Option C: Local development install

Clone this repository and register the local checkout as a VS Code plugin in `settings.json`:

```jsonc
"chat.pluginLocations": {
    "/absolute/path/to/git-ape": true
}
```

Reload VS Code; the `@git-ape` agent and Git-Ape skills will appear in Copilot Chat.

## Verify Installation

In Copilot Chat, try:

```
@git-ape hello
```

You should see the Git-Ape orchestrator respond.

## Next Steps

- [Configure Azure access](./azure-setup)
- [Set up OIDC, RBAC, and GitHub environments](./onboarding)
