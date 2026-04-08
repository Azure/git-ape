#!/bin/bash
set -euo pipefail

echo "==> Installing IaC security tools..."

# Checkov — IaC security scanner (ARM, Bicep, Terraform)
pip install --user --only-binary :all: checkov

# PSRule for Azure — WAF-aligned rules for ARM/Bicep
pwsh -Command "Install-Module -Name PSRule.Rules.Azure -Scope CurrentUser -Force"

# ARM-TTK — Microsoft ARM template test toolkit
mkdir -p /home/vscode/.arm-ttk
git clone --depth 1 https://github.com/Azure/arm-ttk.git /home/vscode/.arm-ttk
mkdir -p /home/vscode/.config/powershell
echo 'Import-Module /home/vscode/.arm-ttk/arm-ttk/arm-ttk.psd1' >> /home/vscode/.config/powershell/Microsoft.PowerShell_profile.ps1

echo "==> Dev environment ready"
