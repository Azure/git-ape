#!/usr/bin/env bash

set -euo pipefail

REQUIRE_ISEE=false
if [[ "${1:-}" == "--require-isee" ]]; then
  REQUIRE_ISEE=true
elif [[ $# -gt 0 ]]; then
  echo "Usage: $0 [--require-isee]" >&2
  exit 2
fi

ROOT=$(git rev-parse --show-toplevel)
WORK="$ROOT/.test-work/git-ape-records-e2e"

cleanup() {
  rm -rf "$WORK"
}
trap cleanup EXIT

rm -rf "$WORK"
mkdir -p "$WORK/repository"
bash "$ROOT/.github/skills/git-ape-onboarding/scripts/scaffold-repo.sh" "$WORK/repository" >/dev/null

cd "$WORK/repository"
git init -q
mkdir -p .github/decisions .github/git-ape .azure/deployments/demo/evidence/bundles

cat > .github/git-ape/onboarding-intent.json <<'JSON'
{
  "deploymentId": "platform-onboarding",
  "environment": "repository",
  "user": "platform-owner",
  "intent": {
    "decision_id": "ADR-GIT-APE-PLATFORM",
    "title": "Adopt Git-Ape guardrails",
    "problem": "Establish guarded Azure delivery.",
    "outcome": "Git-Ape manages reviewable Azure deployments.",
    "alternatives": [
      {
        "id": "git-ape-managed-execution",
        "title": "Use Git-Ape",
        "description": "Use the guarded Git-Ape path."
      }
    ],
    "always_ask": ["Approve Azure deployment"],
    "never": ["Bypass security gates"]
  }
}
JSON

bash .github/git-ape/records/git-ape-records.sh intent \
  --source .github/git-ape/onboarding-intent.json \
  --output .github/decisions/ADR-GIT-APE-PLATFORM.v1.json \
  --status-output .github/git-ape/onboarding-intent-status.json >/dev/null

test "$(jq -r .status .github/git-ape/onboarding-intent-status.json)" = "draft"
test "$(jq -r .ratification .github/decisions/ADR-GIT-APE-PLATFORM.v1.json)" = "null"

cat > .azure/deployments/demo/requirements.json <<'JSON'
{
  "deploymentId": "demo",
  "environment": "test",
  "user": "platform-owner",
  "intent": {
    "decision_id": "ADR-GIT-APE-DEMO",
    "title": "Deploy demo",
    "problem": "Deploy a safe demonstration workload.",
    "outcome": "A reviewable test deployment.",
    "alternatives": [
      {
        "id": "git-ape-managed-execution",
        "title": "Use Git-Ape",
        "description": "Use guarded execution."
      }
    ]
  }
}
JSON

cat > .azure/deployments/demo/template.json <<'JSON'
{
  "$schema": "https://schema.management.azure.com/schemas/2018-05-01/subscriptionDeploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "resources": []
}
JSON

cat > .azure/deployments/demo/parameters.json <<'JSON'
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {}
}
JSON

printf '%s\n' '{"status":"succeeded","deploymentId":"demo"}' > .azure/deployments/demo/state.json
printf '%s\n' '{"status":"passed","resources":[]}' > .azure/deployments/demo/tests.json
printf '%s\n' '{"schemaVersion":"git-ape-deployment-authorization/v1","status":"verified","authorizationType":"merged-pull-request","repository":"Azure/git-ape","trigger":{"event":"push","actor":"test","commitSha":"abc123"},"pullRequest":{"number":1,"url":"https://github.com/Azure/git-ape/pull/1","baseBranch":"main","headBranch":"test","author":"test","mergedAt":"2026-10-05T11:59:00Z","mergedBy":"maintainer","mergeCommitSha":"abc123"},"review":{"decision":"approved","approvals":[{"login":"reviewer","submittedAt":"2026-10-05T11:58:00Z","commitId":"abc123"}]},"verifiedAt":"2026-10-05T12:00:00Z","verifier":"github-actions","reason":null}' > .azure/deployments/demo/authorization.json
mkdir -p .azure/deployments/demo/execution-graphs
cp .github/git-ape/records/graphs/git-ape-deploy-v1.json \
  .azure/deployments/demo/execution-graph.json
cp .github/git-ape/records/graphs/git-ape-deploy-v1.json \
  .azure/deployments/demo/execution-graphs/run-1.json

bash .github/git-ape/records/git-ape-records.sh intent \
  --source .azure/deployments/demo/requirements.json \
  --output .azure/deployments/demo/intent.json \
  --status-output .azure/deployments/demo/intent-status.json >/dev/null

mkdir -p .azure/deployments/demo/traces .azure/deployments/demo/trace-validations
cat > .azure/deployments/demo/events.json <<'JSON'
[
  {"id":"node-intent","type":"node","node":"intent_captured","status":"completed","recordedAt":"2026-10-05T12:00:00Z","evidence":["intent.json"],"result":"draft"},
  {"id":"edge-intent-governance","type":"transition","from":"intent_captured","to":"governance_preflight","recordedAt":"2026-10-05T12:00:01Z","evidence":["intent-record"]},
  {"id":"node-governance","type":"node","node":"governance_preflight","status":"completed","recordedAt":"2026-10-05T12:00:02Z","evidence":["governance-status.json"],"result":"standalone"},
  {"id":"edge-governance-login","type":"transition","from":"governance_preflight","to":"azure_login","recordedAt":"2026-10-05T12:00:03Z","evidence":["governance-status"]},
  {"id":"node-login","type":"node","node":"azure_login","status":"completed","recordedAt":"2026-10-05T12:00:04Z","evidence":["github-oidc"],"result":"authenticated"},
  {"id":"edge-login-validation","type":"transition","from":"azure_login","to":"template_validated","recordedAt":"2026-10-05T12:00:05Z","evidence":["azure-session"]},
  {"id":"node-validation","type":"node","node":"template_validated","status":"completed","recordedAt":"2026-10-05T12:00:06Z","evidence":["template.json"],"result":"passed"},
  {"id":"edge-validation-security","type":"transition","from":"template_validated","to":"security_gate","recordedAt":"2026-10-05T12:00:07Z","evidence":["template-validation"]},
  {"id":"node-security","type":"node","node":"security_gate","status":"completed","recordedAt":"2026-10-05T12:00:08Z","evidence":["security-analysis.md"],"result":"passed"},
  {"id":"edge-security-authorized","type":"transition","from":"security_gate","to":"deployment_authorized","recordedAt":"2026-10-05T12:00:09Z","evidence":["security-result"]},
  {"id":"node-authorized","type":"node","node":"deployment_authorized","status":"completed","recordedAt":"2026-10-05T12:00:10Z","evidence":["authorization.json"],"result":"verified-merged-pull-request"},
  {"id":"edge-authorized-deploy","type":"transition","from":"deployment_authorized","to":"deployment_executed","recordedAt":"2026-10-05T12:00:11Z","evidence":["authorization-receipt"]},
  {"id":"node-deploy","type":"node","node":"deployment_executed","status":"completed","recordedAt":"2026-10-05T12:00:12Z","evidence":["state.json"],"result":"succeeded"},
  {"id":"edge-deploy-tests","type":"transition","from":"deployment_executed","to":"integration_tests","recordedAt":"2026-10-05T12:00:13Z","evidence":["deployment-state"]},
  {"id":"node-tests","type":"node","node":"integration_tests","status":"completed","recordedAt":"2026-10-05T12:00:14Z","evidence":["tests.json"],"result":"passed"},
  {"id":"edge-tests-state","type":"transition","from":"integration_tests","to":"state_recorded","recordedAt":"2026-10-05T12:00:15Z","evidence":["test-results"]},
  {"id":"node-state","type":"node","node":"state_recorded","status":"completed","recordedAt":"2026-10-05T12:00:16Z","evidence":["state.json","tests.json"],"result":"succeeded"}
]
JSON

bash .github/git-ape/records/git-ape-records.sh trace \
  --graph .azure/deployments/demo/execution-graphs/run-1.json \
  --events .azure/deployments/demo/events.json \
  --output .azure/deployments/demo/traces/run-1.json \
  --validation-output .azure/deployments/demo/trace-validations/run-1.json \
  --invocation-id run-1 \
  --workflow git-ape-deploy \
  --identity git-ape:test \
  --outcome succeeded >/dev/null

test "$(jq -r .status .azure/deployments/demo/trace-validations/run-1.json)" = "passed"
test "$(jq -r .outcome .azure/deployments/demo/traces/run-1.json)" = "succeeded"

jq 'map(if .id == "edge-security-authorized" then .evidence = [] else . end)' \
  .azure/deployments/demo/events.json > .azure/deployments/demo/invalid-events.json
if bash .github/git-ape/records/git-ape-records.sh trace \
  --graph .azure/deployments/demo/execution-graphs/run-1.json \
  --events .azure/deployments/demo/invalid-events.json \
  --output .azure/deployments/demo/traces/invalid.json \
  --validation-output .azure/deployments/demo/trace-validations/invalid.json \
  --invocation-id invalid \
  --workflow git-ape-deploy \
  --identity git-ape:test \
  --outcome succeeded >/dev/null; then
  echo "Trace validation unexpectedly accepted missing transition evidence." >&2
  exit 1
fi
test "$(jq -r .status .azure/deployments/demo/trace-validations/invalid.json)" = "failed"

jq '.[0:15] | map(if .id == "node-tests" then .status = "failed" | .result = "failed" else . end)' \
  .azure/deployments/demo/events.json > .azure/deployments/demo/failed-events.json
bash .github/git-ape/records/git-ape-records.sh trace \
  --graph .azure/deployments/demo/execution-graphs/run-1.json \
  --events .azure/deployments/demo/failed-events.json \
  --output .azure/deployments/demo/traces/failed-run.json \
  --validation-output .azure/deployments/demo/trace-validations/failed-run.json \
  --invocation-id failed-run \
  --workflow git-ape-deploy \
  --identity git-ape:test \
  --outcome failed >/dev/null
test "$(jq -r .status .azure/deployments/demo/trace-validations/failed-run.json)" = "passed"
test "$(jq -r '.events[-1].node' .azure/deployments/demo/traces/failed-run.json)" = "integration_tests"
test "$(jq -r '.events[-1].status' .azure/deployments/demo/traces/failed-run.json)" = "failed"

jq '.[0:11] | map(if .id == "node-authorized" then
  .status = "failed" | .result = "rejected-no-associated-merged-pull-request"
  else . end)' \
  .azure/deployments/demo/events.json > .azure/deployments/demo/rejected-authorization-events.json
bash .github/git-ape/records/git-ape-records.sh trace \
  --graph .azure/deployments/demo/execution-graphs/run-1.json \
  --events .azure/deployments/demo/rejected-authorization-events.json \
  --output .azure/deployments/demo/traces/rejected-authorization.json \
  --validation-output .azure/deployments/demo/trace-validations/rejected-authorization.json \
  --invocation-id rejected-authorization \
  --workflow git-ape-deploy \
  --identity git-ape:test \
  --outcome failed >/dev/null
test "$(jq -r .status .azure/deployments/demo/trace-validations/rejected-authorization.json)" = "passed"
test "$(jq -r '.events[-1].node' .azure/deployments/demo/traces/rejected-authorization.json)" = "deployment_authorized"
test "$(jq -r '.events[-1].status' .azure/deployments/demo/traces/rejected-authorization.json)" = "failed"

rm -f .azure/deployments/demo/traces/invalid.json \
  .azure/deployments/demo/trace-validations/invalid.json \
  .azure/deployments/demo/invalid-events.json \
  .azure/deployments/demo/traces/failed-run.json \
  .azure/deployments/demo/trace-validations/failed-run.json \
  .azure/deployments/demo/failed-events.json \
  .azure/deployments/demo/traces/rejected-authorization.json \
  .azure/deployments/demo/trace-validations/rejected-authorization.json \
  .azure/deployments/demo/rejected-authorization-events.json \
  .azure/deployments/demo/events.json

cat > .azure/deployments/demo/node-only-events.json <<'JSON'
[
  {"id":"node-intent","type":"node","node":"intent_captured","status":"completed","recordedAt":"2026-10-05T12:00:00Z","evidence":[]},
  {"id":"node-governance","type":"node","node":"governance_preflight","status":"completed","recordedAt":"2026-10-05T12:00:01Z","evidence":[]},
  {"id":"node-login","type":"node","node":"azure_login","status":"completed","recordedAt":"2026-10-05T12:00:02Z","evidence":[]},
  {"id":"node-validation","type":"node","node":"template_validated","status":"completed","recordedAt":"2026-10-05T12:00:03Z","evidence":[]},
  {"id":"node-security","type":"node","node":"security_gate","status":"completed","recordedAt":"2026-10-05T12:00:04Z","evidence":[]},
  {"id":"node-authorized","type":"node","node":"deployment_authorized","status":"completed","recordedAt":"2026-10-05T12:00:05Z","evidence":[]},
  {"id":"node-deploy","type":"node","node":"deployment_executed","status":"completed","recordedAt":"2026-10-05T12:00:06Z","evidence":[]},
  {"id":"node-tests","type":"node","node":"integration_tests","status":"completed","recordedAt":"2026-10-05T12:00:07Z","evidence":[]},
  {"id":"node-state","type":"node","node":"state_recorded","status":"completed","recordedAt":"2026-10-05T12:00:08Z","evidence":[]}
]
JSON
if bash .github/git-ape/records/git-ape-records.sh trace \
  --graph .azure/deployments/demo/execution-graphs/run-1.json \
  --events .azure/deployments/demo/node-only-events.json \
  --output .azure/deployments/demo/traces/node-only.json \
  --validation-output .azure/deployments/demo/trace-validations/node-only.json \
  --invocation-id node-only \
  --workflow git-ape-deploy \
  --identity git-ape:test \
  --outcome succeeded >/dev/null; then
  echo "Trace validation unexpectedly accepted node-only ordered events." >&2
  exit 1
fi
test "$(jq -r .status .azure/deployments/demo/trace-validations/node-only.json)" = "failed"
test "$(jq '[.errors[] | select(.code == "INVALID_EVENT_SEQUENCE")] | length > 0' \
  .azure/deployments/demo/trace-validations/node-only.json)" = "true"
rm -f .azure/deployments/demo/traces/node-only.json \
  .azure/deployments/demo/trace-validations/node-only.json \
  .azure/deployments/demo/node-only-events.json

bash .github/git-ape/records/git-ape-records.sh evidence \
  --deployment-dir .azure/deployments/demo \
  --output .azure/deployments/demo/evidence/bundles/run-1.json \
  --status-output .azure/deployments/demo/evidence-status.json \
  --identity git-ape:test \
  --target git-ape:test-target \
  --producer-version test \
  --invocation-id run-1 \
  --environment test \
  --decision .azure/deployments/demo/intent.json >/dev/null

test "$(jq -r .status .azure/deployments/demo/evidence-status.json)" = "generated"
test "$(jq -r .independentlyVerified .azure/deployments/demo/evidence-status.json)" = "false"
test "$(jq '[.records[].artifacts[].path | select(. == "traces/run-1.json")] | length' .azure/deployments/demo/evidence/bundles/run-1.json)" = "1"
test "$(jq '[.records[].artifacts[].path | select(. == "trace-validations/run-1.json")] | length' .azure/deployments/demo/evidence/bundles/run-1.json)" = "1"
test "$(jq '[.records[].artifacts[].path | select(. == "execution-graphs/run-1.json")] | length' .azure/deployments/demo/evidence/bundles/run-1.json)" = "1"
test "$(jq '[.records[].artifacts[].path | select(. == "authorization.json")] | length' .azure/deployments/demo/evidence/bundles/run-1.json)" = "1"
bash .github/git-ape/isee/verify-bindings.sh --deployment-id demo >/dev/null
test "$(jq -r .mode .azure/deployments/demo/governance-status.json)" = "standalone"

if command -v adrp >/dev/null && command -v aerp >/dev/null; then
  adrp validate --target .azure/deployments/demo/intent.json >/dev/null
  aerp validate .azure/deployments/demo/evidence/bundles/run-1.json >/dev/null
  aerp verify .azure/deployments/demo/evidence/bundles/run-1.json \
    --artifact-root .azure/deployments/demo >/dev/null

  bash .github/git-ape/isee/adopt-existing.sh \
    --deployment-id demo \
    --mode optional \
    --intent .github/decisions/ADR-GIT-APE-PLATFORM.v1.json \
    --intent .azure/deployments/demo/intent.json >/dev/null

  test "$(jq -r .status .azure/deployments/demo/evidence-status.json)" = "verified"
  test "$(jq -r .evidence.validation .azure/deployments/demo/isee-adoption.json)" = "independent"
  test "$(jq -r .governanceMode .azure/deployments/demo/isee-bindings.json)" = "optional"
  test "$(jq '.intentRecords | length' .azure/deployments/demo/isee-bindings.json)" = "2"
  test "$(jq '.intents | length' .azure/deployments/demo/isee-adoption.json)" = "2"
  test "$(jq -r '.intent.path' .azure/deployments/demo/isee-adoption.json)" = ".github/decisions/ADR-GIT-APE-PLATFORM.v1.json"
  cp .azure/deployments/demo/isee-bindings.json .azure/deployments/demo/isee-bindings.before-duplicate.json
  if bash .github/git-ape/isee/adopt-existing.sh \
    --deployment-id demo \
    --mode optional \
    --force \
    --intent .azure/deployments/demo/intent.json \
    --intent .azure/deployments/demo/intent.json >/dev/null 2>&1; then
    echo "ISEE adoption unexpectedly accepted a duplicate Intent path." >&2
    exit 1
  fi
  cmp .azure/deployments/demo/isee-bindings.before-duplicate.json \
    .azure/deployments/demo/isee-bindings.json
  rm .azure/deployments/demo/isee-bindings.before-duplicate.json

  cp .azure/deployments/demo/isee-bindings.json .azure/deployments/demo/isee-bindings.valid.json
  jq '.governanceMode = "required"' \
    .azure/deployments/demo/isee-bindings.valid.json \
    > .azure/deployments/demo/isee-bindings.json
  if bash .github/git-ape/isee/verify-bindings.sh --deployment-id demo >/dev/null 2>&1; then
    echo "ISEE preflight unexpectedly accepted required governance without ratified Intent requirements." >&2
    exit 1
  fi
  mv .azure/deployments/demo/isee-bindings.valid.json .azure/deployments/demo/isee-bindings.json
  bash .github/git-ape/isee/verify-bindings.sh --deployment-id demo >/dev/null
elif [[ "$REQUIRE_ISEE" == "true" ]]; then
  echo "ADRP and AERP CLIs are required for this test run." >&2
  exit 1
else
  echo "ISEE profile CLIs unavailable; authoritative conformance and adoption checks skipped."
fi

echo "Git-Ape record and delayed ISEE adoption tests passed."
