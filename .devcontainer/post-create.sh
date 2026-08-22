#!/bin/bash
set -euo pipefail

# This script runs as `onCreateCommand` so its results are captured by
# Codespaces prebuilds. The installs below are independent, so we run them
# in parallel and skip work that has already been done.

echo "==> Ensuring sandbox + lint dependencies are installed..."
if command -v bwrap >/dev/null 2>&1 && command -v socat >/dev/null 2>&1 && command -v shellcheck >/dev/null 2>&1; then
  echo "bubblewrap, socat and shellcheck already installed, skipping"
else
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends bubblewrap socat shellcheck
fi

# Replace the default Codespaces "Welcome to Codespaces!" banner with a Git-Ape
# one. The common-utils feature prints this file (which takes precedence over the
# Codespaces default) on the first interactive terminal of each session.
notice_src=".devcontainer/first-run-notice.txt"
if [ -f "$notice_src" ]; then
  echo "==> Installing Git-Ape first-run notice..."
  sudo mkdir -p /usr/local/etc/vscode-dev-containers
  sudo cp "$notice_src" /usr/local/etc/vscode-dev-containers/first-run-notice.txt
fi

echo "==> Installing agent engineering tools (parallel)..."

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

# PSRule for Azure — WAF-aligned rules for ARM/Bicep (optional when pwsh is available)
(
  if command -v pwsh >/dev/null 2>&1; then
    pwsh -NoProfile -Command "
      if (-not (Get-Module -ListAvailable -Name PSRule.Rules.Azure)) {
        Install-Module -Name PSRule.Rules.Azure -Scope CurrentUser -Force -AcceptLicense -SkipPublisherCheck
      } else {
        Write-Host 'PSRule.Rules.Azure already installed, skipping'
      }
    "
  else
    echo "pwsh not found, skipping PSRule.Rules.Azure install"
  fi
) >"$log_dir/psrule.log" 2>&1 &
pids[psrule]=$!

# ARM-TTK — Microsoft ARM template test toolkit
(
  if [ ! -f /home/vscode/.arm-ttk/arm-ttk/arm-ttk.psd1 ]; then
    rm -rf /home/vscode/.arm-ttk
    mkdir -p /home/vscode/.arm-ttk
    git clone --depth 1 --single-branch --no-tags \
      https://github.com/Azure/arm-ttk.git /home/vscode/.arm-ttk
  else
    echo "arm-ttk already cloned, skipping"
  fi
) >"$log_dir/armttk.log" 2>&1 &
pids[armttk]=$!

# waza — Microsoft CLI for evaluating AI agent skills
# https://github.com/microsoft/waza
(
  if command -v waza >/dev/null 2>&1; then
    echo "waza already installed: $(waza --version 2>/dev/null || echo unknown)"
  else
    # The official install.sh auto-detects OS/arch, verifies the checksum,
    # and installs to /usr/local/bin (or ~/bin if not writable).
    # Use sudo so the binary lands in /usr/local/bin which is already on PATH.
    curl -fsSL https://raw.githubusercontent.com/microsoft/waza/main/install.sh | sudo bash
  fi
) >"$log_dir/waza.log" 2>&1 &
pids[waza]=$!

# Website (Docusaurus) npm dependencies — lets this container build/serve the docs
# site. Node 24 is provided by the `node` dev container feature.
(
  if [ -f website/package-lock.json ]; then
    (cd website && npm ci --no-audit --no-fund)
  elif [ -f website/package.json ]; then
    (cd website && npm install --no-audit --no-fund)
  else
    echo "website/package.json not found, skipping website deps"
  fi
) >"$log_dir/website.log" 2>&1 &
pids[website]=$!

# actionlint — GitHub Actions workflow linter (matches git-ape-actionlint.yml CI)
(
  if command -v actionlint >/dev/null 2>&1; then
    echo "actionlint already installed: $(actionlint --version 2>/dev/null | head -1)"
  else
    tmp_dir="$(mktemp -d)"
    (cd "$tmp_dir" && curl -fsSL https://raw.githubusercontent.com/rhysd/actionlint/main/scripts/download-actionlint.bash | bash)
    sudo install -m 0755 "$tmp_dir/actionlint" /usr/local/bin/actionlint
    rm -rf "$tmp_dir"
  fi
) >"$log_dir/actionlint.log" 2>&1 &
pids[actionlint]=$!

# markdownlint-cli — Markdown linter (pinned to match pr-validation.yml)
(
  if command -v markdownlint >/dev/null 2>&1; then
    echo "markdownlint already installed: $(markdownlint --version 2>/dev/null || echo unknown)"
  else
    npm install -g markdownlint-cli@0.41.0
  fi
) >"$log_dir/markdownlint.log" 2>&1 &
pids[markdownlint]=$!

# yamllint + check-jsonschema — YAML linting and JSON/schema validation
# (validate devcontainer.json, dependabot.yml, and workflow YAML locally)
(
  if command -v yamllint >/dev/null 2>&1 && command -v check-jsonschema >/dev/null 2>&1; then
    echo "yamllint and check-jsonschema already installed, skipping"
  else
    pip install --user --disable-pip-version-check yamllint check-jsonschema
  fi
) >"$log_dir/pylint-tools.log" 2>&1 &
pids[pylint-tools]=$!

# PSScriptAnalyzer — PowerShell linter (matches git-ape-script-lint.yml CI)
(
  if command -v pwsh >/dev/null 2>&1; then
    pwsh -NoProfile -Command "
      if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
        Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force -AcceptLicense -SkipPublisherCheck
      } else {
        Write-Host 'PSScriptAnalyzer already installed, skipping'
      }
    "
  else
    echo "pwsh not found, skipping PSScriptAnalyzer install"
  fi
) >"$log_dir/psscriptanalyzer.log" 2>&1 &
pids[psscriptanalyzer]=$!

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

echo "==> Agent engineering dev environment ready"
