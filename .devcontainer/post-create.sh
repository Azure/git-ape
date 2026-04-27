#!/bin/bash
set -euo pipefail

# This script runs as `onCreateCommand` so its results are captured by
# Codespaces prebuilds. The three installs below are independent, so we
# run them in parallel and skip work that has already been done.

echo "==> Installing IaC security tools (parallel)..."

log_dir="$(mktemp -d)"
declare -A pids=()

# Checkov — IaC security scanner (ARM, Bicep, Terraform)
(
  if command -v checkov >/dev/null 2>&1; then
    echo "checkov already installed, skipping"
  else
    pip install --user --only-binary :all: --no-compile --disable-pip-version-check checkov
  fi
) >"$log_dir/checkov.log" 2>&1 &
pids[checkov]=$!

# PSRule for Azure — WAF-aligned rules for ARM/Bicep
(
  pwsh -NoProfile -Command "
    if (-not (Get-Module -ListAvailable -Name PSRule.Rules.Azure)) {
      Install-Module -Name PSRule.Rules.Azure -Scope CurrentUser -Force -AcceptLicense -SkipPublisherCheck
    } else {
      Write-Host 'PSRule.Rules.Azure already installed, skipping'
    }
  "
) >"$log_dir/psrule.log" 2>&1 &
pids[psrule]=$!

# ARM-TTK — Microsoft ARM template test toolkit
(
  if [ ! -f /home/vscode/.arm-ttk/arm-ttk/arm-ttk.psd1 ]; then
    rm -rf /home/vscode/.arm-ttk
    mkdir -p /home/vscode/.arm-ttk
    git clone --depth 1 --single-branch --filter=blob:none \
      https://github.com/Azure/arm-ttk.git /home/vscode/.arm-ttk
  else
    echo "arm-ttk already cloned, skipping"
  fi
  mkdir -p /home/vscode/.config/powershell
  profile=/home/vscode/.config/powershell/Microsoft.PowerShell_profile.ps1
  import_line='Import-Module /home/vscode/.arm-ttk/arm-ttk/arm-ttk.psd1'
  if ! grep -qxF "$import_line" "$profile" 2>/dev/null; then
    echo "$import_line" >> "$profile"
  fi
) >"$log_dir/armttk.log" 2>&1 &
pids[armttk]=$!

# Wait for all background jobs and surface logs/failures.
status=0
for name in "${!pids[@]}"; do
  if ! wait "${pids[$name]}"; then
    rc=$?
    echo "==> '$name' install failed with exit code $rc" >&2
    status=1
  fi
done

for f in "$log_dir"/*.log; do
  echo "----- $(basename "$f") -----"
  cat "$f"
done

rm -rf "$log_dir"

if [ "$status" -ne 0 ]; then
  echo "==> One or more install steps failed" >&2
  exit "$status"
fi

echo "==> Dev environment ready"
