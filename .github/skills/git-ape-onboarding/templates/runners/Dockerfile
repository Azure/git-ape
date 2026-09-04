# Git-Ape self-hosted runner image
#
# Extends the official GitHub Actions runner with the tools Git-Ape workflows need
# plus a registration entrypoint so the runner self-registers on standalone
# container hosts (ACI, ACA Jobs):
#   - az  (Azure CLI)
#   - gh  (GitHub CLI)
#   - jq  (JSON processor)
#   - git (already in base image)
#   - entrypoint.sh (PAT -> registration-token exchange + config.sh/run.sh)
#
# Base image: ghcr.io/actions/actions-runner (GitHub's official runner image,
# Ubuntu-based). It includes the runner binary but does NOT include az, gh, or jq,
# and ships no registration entrypoint. Without this custom image, container hosts
# never register a runner and workflows fail with
# "Unable to locate executable file: az".
#
# Build with ACR Tasks (no local Docker required):
#   az acr build --registry <acr-name> --image git-ape-runner:latest .
#
# Or locally:
#   docker build -t git-ape-runner:latest .

FROM ghcr.io/actions/actions-runner:latest

USER root

# Install Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | tee /etc/apt/sources.list.d/github-cli-stable.list > /dev/null \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install jq plus curl/ca-certificates used by the registration entrypoint
# (git is already included in the base image).
RUN apt-get update \
    && apt-get install -y --no-install-recommends jq curl ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Registration entrypoint (self-registers the runner on ACI/ACA; bypassed on
# AKS, where ARC overrides the container command).
COPY entrypoint.sh /home/runner/entrypoint.sh
# Strip Windows CRLF line endings if present. When the build context is
# uploaded from a Windows checkout (git autocrlf) or via `az acr build` from a
# Windows host, the shebang becomes "#!/usr/bin/env bash\r" and Linux returns
# "bash\r: No such file or directory". This sed is a no-op on clean LF files.
RUN sed -i 's/\r$//' /home/runner/entrypoint.sh && chmod +x /home/runner/entrypoint.sh

# Switch back to the runner user
USER runner
WORKDIR /home/runner

# Verify all required tools are present
RUN az version --output table \
    && gh --version \
    && jq --version \
    && git --version

ENTRYPOINT ["/home/runner/entrypoint.sh"]
