# Install & PATH-Repair Commands

Platform-specific install recipes for the tools `prereq-check` validates: `az` (≥ 2.50), `gh` (≥ 2.0), `jq` (≥ 1.6), `git`.

Show only the commands matching the platform detected by Step 1 of `prereq-check`. For tools the user reported missing but this terminal can find, frame these as **reinstall / PATH repair** rather than contradicting the user.

## macOS (Homebrew)

```bash
brew install azure-cli gh jq git
```

## Ubuntu / Debian

```bash
# az
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# gh (full keyring setup)
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

## RHEL / Fedora

```bash
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo dnf install -y azure-cli gh jq
```

## Windows (PowerShell with winget)

```powershell
winget install Microsoft.AzureCLI
winget install GitHub.cli
winget install jqlang.jq
winget install Git.Git
winget install Microsoft.PowerShell   # PowerShell 7+ (pwsh) — required by check-tools.ps1
```

> Run `prereq-check` on Windows with `pwsh -File scripts/check-tools.ps1`. Git-Ape no longer requires git-bash; PowerShell 7+ is the supported Windows shell.

## Verification (macOS / Linux — bash)

```bash
command -v az && az --version
command -v gh && gh --version
command -v jq && jq --version
command -v git && git --version
```

## Verification (Windows — PowerShell)

```powershell
foreach ($t in 'az','gh','jq','git') {
  $c = Get-Command $t -ErrorAction SilentlyContinue
  if ($c) { Write-Output "$t -> $($c.Source)"; & $t --version } else { Write-Output "$t MISSING" }
}
```

## PATH repair

If a binary is installed but still not found in the user's shell:

1. Close and reopen the terminal.
2. Reload the shell profile: `source ~/.bashrc` or `source ~/.zshrc` (or shell equivalent).
3. Re-run the verification block above.
4. If still missing, check that the install location is on `$PATH`:

   ```bash
   echo "$PATH" | tr ':' '\n'
   which -a az gh jq git 2>/dev/null
   ```

   Common install paths to add if missing:
   - macOS Homebrew (Apple Silicon): `/opt/homebrew/bin`
   - macOS Homebrew (Intel): `/usr/local/bin`
   - Linux user install: `~/.local/bin`
   - Windows winget shims: `%LOCALAPPDATA%\Microsoft\WinGet\Packages\` and `%ProgramFiles%\` (e.g., `C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin`)

   On Windows, refresh `$env:Path` in the current session after install: `$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')`.
