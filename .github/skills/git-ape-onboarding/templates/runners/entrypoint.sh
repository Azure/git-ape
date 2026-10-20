#!/usr/bin/env bash
# Git-Ape self-hosted runner entrypoint.
#
# The official GitHub Actions runner image (ghcr.io/actions/actions-runner) ships
# the runner binary but NO registration entrypoint — on Kubernetes the Actions
# Runner Controller supplies one, but standalone container hosts (ACI, ACA Jobs)
# have nothing to register the runner. This script is that missing layer: it
# exchanges ACCESS_TOKEN (a fine-grained PAT with administration:write, or a
# GitHub App installation token) for a short-lived registration token, configures
# an ephemeral runner, starts it, and deregisters on shutdown.
#
# It honors the same environment-variable contract the ACI/ACA templates set:
#   ACCESS_TOKEN, RUNNER_SCOPE (repo|org), REPO_URL or ORG_NAME, LABELS,
#   RUNNER_NAME_PREFIX, EPHEMERAL, DISABLE_AUTO_UPDATE.
#
# On AKS, ARC overrides the container command (command: ["/home/runner/run.sh"]),
# so this entrypoint is bypassed there.
set -euo pipefail

RUNNER_HOME="${RUNNER_HOME:-/home/runner}"
cd "${RUNNER_HOME}"

: "${ACCESS_TOKEN:?ACCESS_TOKEN (GitHub PAT or App installation token) is required}"
RUNNER_SCOPE="${RUNNER_SCOPE:-repo}"
LABELS="${LABELS:-git-ape-runner}"
EPHEMERAL="${EPHEMERAL:-true}"
DISABLE_AUTO_UPDATE="${DISABLE_AUTO_UPDATE:-true}"
GITHUB_API="${GITHUB_API_URL:-https://api.github.com}"
API_VERSION="2022-11-28"

case "${RUNNER_SCOPE}" in
  org)
    : "${ORG_NAME:?ORG_NAME is required for org-scoped runners}"
    REG_URL="https://github.com/${ORG_NAME}"
    RUNNERS_API="${GITHUB_API}/orgs/${ORG_NAME}/actions/runners"
    ;;
  repo)
    : "${REPO_URL:?REPO_URL is required for repo-scoped runners}"
    REG_URL="${REPO_URL}"
    owner_repo="${REPO_URL#https://github.com/}"
    RUNNERS_API="${GITHUB_API}/repos/${owner_repo}/actions/runners"
    ;;
  *)
    echo "Unsupported RUNNER_SCOPE '${RUNNER_SCOPE}' (expected 'repo' or 'org')" >&2
    exit 1
    ;;
esac

# Exchange the PAT/App token for a short-lived registration or remove token.
# $1 = registration | remove
runner_token() {
  curl -fsSL -X POST \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: ${API_VERSION}" \
    "${RUNNERS_API}/$1-token" | jq -r '.token'
}

RUNNER_NAME="${RUNNER_NAME_PREFIX:-git-ape-runner}-$(hostname)-${RANDOM}"

echo "Requesting registration token (${RUNNER_SCOPE} scope) ..."
REG_TOKEN="$(runner_token registration)"
if [ -z "${REG_TOKEN}" ] || [ "${REG_TOKEN}" = "null" ]; then
  echo "Failed to obtain a registration token. Check that ACCESS_TOKEN has" >&2
  echo "administration:write (repo) or self-hosted runner admin (org) rights." >&2
  exit 1
fi

config_args=(
  --url "${REG_URL}"
  --token "${REG_TOKEN}"
  --name "${RUNNER_NAME}"
  --labels "${LABELS}"
  --work _work
  --unattended
  --replace
)
[ "${EPHEMERAL}" = "true" ] && config_args+=(--ephemeral)
[ "${DISABLE_AUTO_UPDATE}" = "true" ] && config_args+=(--disableupdate)

./config.sh "${config_args[@]}"

deregister() {
  echo "Removing runner registration ..."
  local rm_token
  rm_token="$(runner_token remove || true)"
  if [ -n "${rm_token}" ] && [ "${rm_token}" != "null" ]; then
    ./config.sh remove --token "${rm_token}" || true
  fi
}

./run.sh &
RUNNER_PID=$!
trap 'kill -TERM "${RUNNER_PID}" 2>/dev/null || true' INT TERM

set +e
wait "${RUNNER_PID}"
EXIT_CODE=$?
set -e

# Ephemeral runners deregister themselves after one job; this is a safety net for
# non-ephemeral runners and graceful-shutdown signals (idempotent on re-run).
deregister
exit "${EXIT_CODE}"
