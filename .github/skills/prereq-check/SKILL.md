---
name: prereq-check
description: "Check that all required CLI tools are installed, meet minimum versions, and have active auth sessions. Shows platform-specific install commands for anything missing. Enhanced with auto-installation capability."
argument-hint: "Run without arguments to check all prerequisites, or with 'install' to auto-install missing tools"
user-invocable: true
---

# Prerequisites Check

Validates the local environment has the CLI tools and auth sessions needed to run Git-Ape skills.

**Enhanced with auto-installation:** Can now automatically install missing prerequisites instead of just detecting them.

## When to Use

- Before first-time onboarding (`/git-ape-onboarding`)
- When any Git-Ape skill fails with a "command not found" error
- When switching machines or dev containers
- When a user asks "what do I need to install?"

## Execution Modes

### Detection Mode (Default)
```text
/prereq-check
```
Shows what's missing and provides install commands.

### Auto-Installation Mode
```text
/prereq-check install
```
Automatically installs missing prerequisites.

## Required Tools

| Tool | Binary | Minimum Version | Purpose |
|------|--------|-----------------|---------|
| Azure CLI | `az` | 2.50 | Azure resource management, RBAC, deployments |
| GitHub CLI | `gh` | 2.0 | Repo secrets, environments, PR operations |
| jq | `jq` | 1.6 | JSON parsing in scripts and workflows |
| git | `git` | any | Version control (usually pre-installed) |

## Execution Playbook

Run the steps below in order. Present results as a table. Stop at the first blocking failure.

### Step 1: Detect Platform

```bash
OS="$(uname -s)"
ARCH="$(uname -m)"
echo "Platform: $OS / $ARCH"
```

Map the result for install instructions:
- `Darwin` → macOS
- `Linux` → Linux (check for `apt-get` vs `yum`/`dnf` to narrow distro)
- `MINGW*` / `MSYS*` → Windows (git-bash)

### Step 2: Check Each Tool

```bash
# --- az (Azure CLI) — required, minimum 2.50 ---
if command -v az &>/dev/null; then
  AZ_VER=$(az version --query '"azure-cli"' -o tsv 2>/dev/null)
  echo "az: $AZ_VER"
else
  echo "az: NOT FOUND"
fi

# --- gh (GitHub CLI) — required, minimum 2.0 ---
if command -v gh &>/dev/null; then
  GH_VER=$(gh --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  echo "gh: $GH_VER"
else
  echo "gh: NOT FOUND"
fi

# --- jq — required, minimum 1.6 ---
if command -v jq &>/dev/null; then
  JQ_VER=$(jq --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+[a-z]*')
  echo "jq: $JQ_VER"
else
  echo "jq: NOT FOUND"
fi

# --- git — required (usually pre-installed) ---
if command -v git &>/dev/null; then
  GIT_VER=$(git --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  echo "git: $GIT_VER"
else
  echo "git: NOT FOUND"
fi
```

### Step 3: Present Results

Show a table with pass/fail status:

| Tool | Status | Found Version | Minimum Required |
|------|--------|---------------|------------------|
| az   | ✅ / ❌ | x.y.z        | 2.50             |
| gh   | ✅ / ❌ | x.y.z        | 2.0              |
| jq   | ✅ / ❌ | x.y          | 1.6              |
| git  | ✅ / ❌ | x.y.z        | any              |

Mark a tool ❌ if it is missing OR below the minimum version.

### Step 4: Show Install Commands (only if something is missing)

Show install commands only for missing or outdated tools, matching the detected platform.

**macOS (Homebrew):**
```bash
brew install azure-cli   # az
brew install gh           # GitHub CLI
brew install jq           # jq
brew install git          # git (if missing)
```

**Ubuntu / Debian:**
```bash
# az — Microsoft repository
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# gh — GitHub repository
(type -p wget >/dev/null || sudo apt-get install wget -y) \
  && sudo mkdir -p -m 755 /etc/apt/keyrings \
  && out=$(mktemp) && wget -nv -O"$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  && cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
  && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  && sudo apt-get update && sudo apt-get install gh -y

# jq
sudo apt-get install -y jq
```

**RHEL / Fedora:**
```bash
# az
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo dnf install -y azure-cli

# gh
sudo dnf install -y gh

# jq
sudo dnf install -y jq
```

**Windows (PowerShell with winget):**
```powershell
winget install Microsoft.AzureCLI
winget install GitHub.cli
winget install jqlang.jq
```

> **Windows note:** AutoCloud skills require a BASH shell. Install [Git for Windows](https://gitforwindows.org/) and use git-bash.

### Step 5: Check Auth Sessions

Only run this step if all tools passed Step 3.

```bash
# Azure CLI session
az account show --query "{name:name,id:id,tenantId:tenantId}" -o table 2>/dev/null
if [[ $? -ne 0 ]]; then
  echo "❌ Not logged in to Azure. Run: az login"
fi

# GitHub CLI session
gh auth status 2>/dev/null
if [[ $? -ne 0 ]]; then
  echo "❌ Not logged in to GitHub. Run: gh auth login"
fi
```

### Step 5.5: If ADO selected — validate Azure DevOps toolchain

Run only when invoked from `/git-ape-onboarding` with `cicd ado` or `cicd both`. Skip otherwise.

```bash
# --- azure-devops extension — required for `az devops`, `az pipelines`, `az repos` ---
ADO_EXT_VER=$(az extension show --name azure-devops --query version -o tsv 2>/dev/null)
if [[ -z "$ADO_EXT_VER" ]]; then
  echo "azure-devops: NOT INSTALLED"
else
  echo "azure-devops: $ADO_EXT_VER"
fi

# --- Default org configured (or $ADO_ORG_URL provided) ---
ADO_DEFAULT_ORG=$(az devops configure --list 2>/dev/null | awk -F'= *' '/^organization/ {print $2}')
if [[ -z "$ADO_DEFAULT_ORG" && -z "$ADO_ORG_URL" ]]; then
  echo "az devops default organization: NOT CONFIGURED (warning — every command must use --org)"
else
  echo "az devops default organization: ${ADO_DEFAULT_ORG:-$ADO_ORG_URL}"
fi

# --- Optional: confirm credentials reach the org ---
if [[ -n "${ADO_ORG_URL:-$ADO_DEFAULT_ORG}" ]]; then
  az devops user show --org "${ADO_ORG_URL:-$ADO_DEFAULT_ORG}" --query "user.descriptor" -o tsv 2>/dev/null \
    && echo "az devops auth: OK" \
    || echo "az devops auth: FAILED — credentials cannot reach the org"
fi
```

Add an ADO row to the Step 3 results table when ADO mode is active:

| Tool | Status | Found Version | Minimum Required |
|------|--------|---------------|------------------|
| azure-devops extension | ✅ / ❌ | x.y.z | any |
| az devops org auth | ✅ / ❌ | reachable | reachable |

**Install commands when missing (all platforms — extension is delivered via `az`):**

```bash
az extension add --name azure-devops
az extension update --name azure-devops   # if installed but stale
```

**Configure default org (optional — can also pass `--org` on every command):**

```bash
az devops configure --defaults organization=https://dev.azure.com/<your-org> project=<your-project>
```

**Auth notes:** the `azure-devops` extension reuses the `az` login session for ADO. No PAT is required for Git-Ape onboarding. If `az devops user show` fails with `TF400813` or `403`, sign in again with `az login --allow-no-subscriptions` and ensure the signed-in identity is a member of the ADO organization.

### Step 6: Auto-Installation (Enhanced)

When invoked with `install` mode, automatically install missing or outdated tools:

**Windows (PowerShell):**
```powershell
# Auto-install missing tools
if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
  Write-Host "Installing jq..."
  winget install jqlang.jq
}

if (-not (az extension show --name azure-devops 2>$null)) {
  Write-Host "Installing azure-devops extension..."
  az extension add --name azure-devops
}

# Verify installations
jq --version
az extension show --name azure-devops --query version -o tsv
```

**macOS (Homebrew):**
```bash
# Auto-install missing tools
command -v jq >/dev/null 2>&1 || {
  echo "Installing jq..."
  brew install jq
}

az extension show --name azure-devops >/dev/null 2>&1 || {
  echo "Installing azure-devops extension..."
  az extension add --name azure-devops
}
```

**Ubuntu/Debian:**
```bash
# Auto-install missing tools
command -v jq >/dev/null 2>&1 || {
  echo "Installing jq..."
  sudo apt-get update && sudo apt-get install -y jq
}

az extension show --name azure-devops >/dev/null 2>&1 || {
  echo "Installing azure-devops extension..."
  az extension add --name azure-devops
}
```

Present a final verdict:

- **✅ READY** — All tools installed, versions OK, auth sessions active. Proceed with any AutoCloud skill.
- **⚠️ TOOLS MISSING** — List what to install. Do not proceed until resolved.
- **⚠️ AUTH MISSING** — Tools OK but user needs to run `az login` and/or `gh auth login`.

When ADO mode is active (provider `ado` or `both`), `✅ READY` also requires the ADO toolchain checks in Step 5.5 above to pass.

## Agent Behavior

1. Run Steps 1–5 by executing the commands in the terminal. Run Step 5.5 as well when ADO mode is active.
2. Present the results table and install commands (if needed).
3. Do NOT install anything automatically — show the commands and let the user run them.
4. If everything passes, tell the user they're ready and suggest next steps (e.g., `/git-ape-onboarding`).

Run only when invoked from `/git-ape-onboarding` with `cicd ado` or `cicd both`. Skip otherwise.

```bash
# --- azure-devops extension — required for `az devops`, `az pipelines`, `az repos` ---
ADO_EXT_VER=$(az extension show --name azure-devops --query version -o tsv 2>/dev/null)
if [[ -z "$ADO_EXT_VER" ]]; then
  echo "azure-devops: NOT INSTALLED"
else
  echo "azure-devops: $ADO_EXT_VER"
fi

# --- Default org configured (or $ADO_ORG_URL provided) ---
ADO_DEFAULT_ORG=$(az devops configure --list 2>/dev/null | awk -F'= *' '/^organization/ {print $2}')
if [[ -z "$ADO_DEFAULT_ORG" && -z "$ADO_ORG_URL" ]]; then
  echo "az devops default organization: NOT CONFIGURED (warning — every command must use --org)"
else
  echo "az devops default organization: ${ADO_DEFAULT_ORG:-$ADO_ORG_URL}"
fi

# --- Optional: confirm credentials reach the org ---
if [[ -n "${ADO_ORG_URL:-$ADO_DEFAULT_ORG}" ]]; then
  az devops user show --org "${ADO_ORG_URL:-$ADO_DEFAULT_ORG}" --query "user.descriptor" -o tsv 2>/dev/null \
    && echo "az devops auth: OK" \
    || echo "az devops auth: FAILED — credentials cannot reach the org"
fi
```

Add an ADO row to the Step 3 results table when ADO mode is active:

| Tool | Status | Found Version | Minimum Required |
|------|--------|---------------|------------------|
| azure-devops extension | ✅ / ❌ | x.y.z | any |
| az devops org auth | ✅ / ❌ | reachable | reachable |

**Install commands when missing (all platforms — extension is delivered via `az`):**

```bash
az extension add --name azure-devops
az extension update --name azure-devops   # if installed but stale
```

**Configure default org (optional — can also pass `--org` on every command):**

```bash
az devops configure --defaults organization=https://dev.azure.com/<your-org> project=<your-project>
```

**Auth notes:** the `azure-devops` extension reuses the `az` login session for ADO. No PAT is required for Git-Ape onboarding. If `az devops user show` fails with `TF400813` or `403`, sign in again with `az login --allow-no-subscriptions` and ensure the signed-in identity is a member of the ADO organization.

## Agent Behavior

1. Run Steps 1–5 by executing the commands in the terminal.
2. Present the results table and install commands (if needed).
3. Do NOT install anything automatically — show the commands and let the user run them.
4. If everything passes, tell the user they're ready and suggest next steps (e.g., `/autocloud-onboarding`).
