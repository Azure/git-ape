# Git-Ape self-hosted runner image
#
# Extends the official GitHub Actions runner with tools required by Git-Ape
# workflows:
#   - az  (Azure CLI)
#   - gh  (GitHub CLI)
#   - jq  (JSON processor)
#   - git (already in base image)
#
# Base image: ghcr.io/actions/runner (GitHub's official runner image, Ubuntu-based)
# The official image includes the runner binary and basic OS tools but does NOT
# include az, gh, or jq. Without this custom image, workflows fail with
# "Unable to locate executable file: az".
#
# Build with ACR Tasks (no local Docker required):
#   az acr build --registry <acr-name> --image git-ape-runner:latest .
#
# Or locally:
#   docker build -t git-ape-runner:latest .

FROM ghcr.io/actions/runner:latest

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

# Install jq (git is already included in the base image)
RUN apt-get update \
    && apt-get install -y --no-install-recommends jq \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Switch back to the runner user
USER runner

# Verify all required tools are present
RUN az version --output table \
    && gh --version \
    && jq --version \
    && git --version
