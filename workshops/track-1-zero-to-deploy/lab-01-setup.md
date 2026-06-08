# Lab 1: Setup

> 5 minutes | No Azure required

Open your development environment and verify all tools are ready.

> **What this teaches you:** how to confirm Git-Ape is installed, signed in, and ready before any deployment work. Most workshop failures are caught here.

## Step 1: Set Up Your Environment

Follow the [environment setup guide](../shared/environment-setup.md) to choose and configure one of three options:

- **Option A: GitHub Codespaces** — click **Code** > **Codespaces** > **Create codespace on main** (fastest, nothing to install)
- **Option B: VS Code + Dev Containers** — clone the repo and reopen in container (requires Docker)
- **Option C: VS Code Local** — clone the repo and install tools manually (no Docker needed)

> **Already set up?** Open your existing environment and skip to Step 2.

You should see VS Code with a terminal at the bottom.

## Step 2: Open Copilot Chat

1. Click the **Copilot Chat** icon in the left sidebar (chat bubble icon).
2. The chat panel opens on the right side of the screen.

> **Don't see Copilot Chat?** Verify your Copilot subscription at [github.com/settings/copilot](https://github.com/settings/copilot). Reload the window if the extension hasn't loaded: `Ctrl+Shift+P` > `Developer: Reload Window`.

## Step 3: Run the Prerequisite Check

In Copilot Chat, type:

```text
/prereq-check
```

You should see output confirming required tools AND auth sessions:

```
PASS Azure CLI (az) -- installed, version 2.55
PASS GitHub CLI (gh) -- installed, version 2.40
PASS jq -- installed, version 1.7
PASS git -- installed
PASS Azure CLI logged in   (T2/T3 only)
PASS GitHub CLI logged in  (T2/T3 only)
```

> The skill checks **versions and auth sessions**, not just whether the binary exists. An old `az` or a missing `gh auth login` will fail even if the binary is present.

### What if a check fails?

The skill prints platform-specific install commands for anything missing. Track 1 only needs `git` and the dev environment; if other tools fail, you can still complete the lab via the review-only path.

For deeper per-track validation:

```bash
bash workshops/shared/check-track-1-prereqs.sh
```

> **Don't worry about Azure authentication.** Track 1 works without `az login`. You'll review generated artifacts instead of deploying live resources.

## What you have now

- A development environment with all required tools available
- GitHub Copilot Chat ready to accept commands
- Git-Ape agents and skills available

For the full prereq picture (CLI versions, Azure sub state, identity model, repo settings) see [prerequisites.md](../shared/prerequisites.md).

**Next:** [Lab 2 — First Deploy](lab-02-first-deploy.md)
