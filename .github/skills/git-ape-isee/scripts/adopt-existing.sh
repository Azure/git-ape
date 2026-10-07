#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  adopt-existing.sh --deployment-id ID [options]

Options:
  --mode optional|required       Governance mode (default: optional)
  --intent PATH                 ADRP record to bind (default: deployment intent.json)
  --structure PATH              ASRP record to bind; repeatable
  --execution-manifest PATH     ASRP execution manifest to bind
  --force                       Replace an existing isee-bindings.json

The command never installs ISEE tooling, ratifies Intent, or regenerates
Evidence. Installed ADRP/ASRP/AERP CLIs validate the records Git-Ape already
created.
EOF
}

die() {
  echo "ISEE adoption failed: $*" >&2
  exit 1
}

sha256_file() {
  if command -v sha256sum >/dev/null; then
    sha256sum "$1" | awk '{print "sha256:" $1}'
  else
    shasum -a 256 "$1" | awk '{print "sha256:" $1}'
  fi
}

repo_relative() {
  local candidate="$1"
  local parent resolved
  [[ -e "$candidate" ]] || die "path not found: $candidate"
  [[ ! -L "$candidate" ]] || die "symbolic links are not allowed: $candidate"
  parent=$(cd "$(dirname "$candidate")" && pwd -P)
  resolved="$parent/$(basename "$candidate")"
  case "$resolved" in
    "$ROOT"/*) printf '%s\n' "${resolved#"$ROOT"/}" ;;
    *) die "path is outside the repository: $candidate" ;;
  esac
}

write_json() {
  local source="$1"
  local destination="$2"
  local temporary
  mkdir -p "$(dirname "$destination")"
  temporary="$(dirname "$destination")/.$(basename "$destination").$$.tmp"
  jq . "$source" > "$temporary"
  mv "$temporary" "$destination"
}

DEPLOYMENT_ID=""
MODE="optional"
INTENT=""
EXECUTION_MANIFEST=""
FORCE=false
STRUCTURES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --deployment-id) DEPLOYMENT_ID="${2:-}"; shift 2 ;;
    --mode) MODE="${2:-}"; shift 2 ;;
    --intent) INTENT="${2:-}"; shift 2 ;;
    --structure) STRUCTURES+=("${2:-}"); shift 2 ;;
    --execution-manifest) EXECUTION_MANIFEST="${2:-}"; shift 2 ;;
    --force) FORCE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ "$DEPLOYMENT_ID" =~ ^[A-Za-z0-9._-]+$ ]] || die "--deployment-id must use only A-Z, a-z, 0-9, dot, underscore, or hyphen"
[[ "$MODE" == "optional" || "$MODE" == "required" ]] || die "--mode must be optional or required"
command -v git >/dev/null || die "git is required"
command -v jq >/dev/null || die "jq is required"
if ! command -v sha256sum >/dev/null && ! command -v shasum >/dev/null; then
  die "sha256sum or shasum is required"
fi

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || die "run this command inside a Git repository"
DEPLOY_DIR="$ROOT/.azure/deployments/$DEPLOYMENT_ID"
[[ -d "$DEPLOY_DIR" ]] || die "deployment directory not found: .azure/deployments/$DEPLOYMENT_ID"
[[ -f "$DEPLOY_DIR/template.json" ]] || die "template.json is required for governance binding"

PRODUCER="$ROOT/.github/git-ape/records/git-ape-records.sh"
[[ -f "$PRODUCER" ]] || PRODUCER="$ROOT/.github/skills/git-ape-records/scripts/git-ape-records.sh"
[[ -f "$PRODUCER" ]] || die "native Git-Ape record producer not found"
VERIFY="$ROOT/.github/git-ape/isee/verify-bindings.sh"
[[ -f "$VERIFY" ]] || VERIFY="$ROOT/.github/skills/git-ape-isee/scripts/verify-bindings.sh"
[[ -f "$VERIFY" ]] || die "ISEE binding verifier not found"

INTENT="${INTENT:-$DEPLOY_DIR/intent.json}"
INTENT_REL=$(repo_relative "$INTENT")
INTENT="$ROOT/$INTENT_REL"
[[ "$(jq -r '.schema_version // empty' "$INTENT")" == "ape-decision-record/v1" ]] ||
  die "Intent is not an ADRP v1 record: $INTENT_REL"

if [[ "$MODE" == "required" ]]; then
  command -v adrp >/dev/null || die "required governance needs the ADRP CLI"
  command -v aerp >/dev/null || die "required governance needs the AERP CLI"
  adrp validate --target "$INTENT" --require-ratified >/dev/null ||
    die "required governance needs a valid ratified Intent record"
elif command -v adrp >/dev/null; then
  adrp validate --target "$INTENT" >/dev/null || die "ADRP validation failed: $INTENT_REL"
fi

INTENT_FP=$(bash "$PRODUCER" fingerprint --profile adrp "$INTENT")
INTENT_BINDINGS=$(jq -cn \
  --arg path "$INTENT_REL" \
  --arg fingerprint "$INTENT_FP" \
  --argjson requireRatified "$([[ "$MODE" == "required" ]] && echo true || echo false)" \
  '[{path:$path,fingerprint:$fingerprint,requireRatified:$requireRatified}]')

STRUCTURE_BINDINGS="[]"
set +u
for structure in "${STRUCTURES[@]}"; do
  structure_rel=$(repo_relative "$structure")
  structure="$ROOT/$structure_rel"
  [[ "$(jq -r '.schema_version // empty' "$structure")" == "ape-structure-record/v1" ]] ||
    die "Structure is not an ASRP v1 record: $structure_rel"
  if command -v asrp >/dev/null; then
    asrp validate "$structure" >/dev/null || die "ASRP validation failed: $structure_rel"
  elif [[ "$MODE" == "required" ]]; then
    die "required governance needs the ASRP CLI for bound Structure records"
  fi
  structure_fp=$(bash "$PRODUCER" fingerprint --profile asrp "$structure")
  STRUCTURE_BINDINGS=$(jq -c \
    --arg path "$structure_rel" \
    --arg fingerprint "$structure_fp" \
    '. + [{path:$path,fingerprint:$fingerprint}]' <<<"$STRUCTURE_BINDINGS")
done
set -u

MANIFEST_BINDING="null"
if [[ -n "$EXECUTION_MANIFEST" ]]; then
  manifest_rel=$(repo_relative "$EXECUTION_MANIFEST")
  EXECUTION_MANIFEST="$ROOT/$manifest_rel"
  if command -v asrp >/dev/null; then
    asrp validate "$EXECUTION_MANIFEST" >/dev/null || die "ASRP manifest validation failed: $manifest_rel"
  elif [[ "$MODE" == "required" ]]; then
    die "required governance needs the ASRP CLI for an execution manifest"
  fi
  MANIFEST_BINDING=$(jq -cn \
    --arg path "$manifest_rel" \
    --arg digest "$(sha256_file "$EXECUTION_MANIFEST")" \
    '{path:$path,digest:$digest}')
fi

TEMPLATE_REL=$(repo_relative "$DEPLOY_DIR/template.json")
TEMPLATE_BINDING=$(jq -cn \
  --arg path "$TEMPLATE_REL" \
  --arg digest "$(sha256_file "$DEPLOY_DIR/template.json")" \
  '{path:$path,digest:$digest}')

PARAMETERS_BINDING="null"
if [[ -f "$DEPLOY_DIR/parameters.json" ]]; then
  PARAMETERS_REL=$(repo_relative "$DEPLOY_DIR/parameters.json")
  PARAMETERS_BINDING=$(jq -cn \
    --arg path "$PARAMETERS_REL" \
    --arg digest "$(sha256_file "$DEPLOY_DIR/parameters.json")" \
    '{path:$path,digest:$digest}')
fi

BUNDLES=()
while IFS= read -r bundle; do
  [[ -n "$bundle" ]] && BUNDLES+=("$bundle")
done < <(find "$DEPLOY_DIR/evidence/bundles" -maxdepth 1 -type f -name '*.json' 2>/dev/null | sort)
set +u
BUNDLE_COUNT=${#BUNDLES[@]}
set -u
if [[ "$MODE" == "required" && "$BUNDLE_COUNT" -eq 0 ]]; then
  die "required governance needs at least one existing Evidence bundle"
fi

VERIFIED_BUNDLES="[]"
FAILED_BUNDLES="[]"
if command -v aerp >/dev/null; then
  set +u
  for bundle in "${BUNDLES[@]}"; do
    bundle_rel=$(repo_relative "$bundle")
    if aerp validate "$bundle" >/dev/null &&
       aerp verify "$bundle" --artifact-root "$DEPLOY_DIR" >/dev/null; then
      VERIFIED_BUNDLES=$(jq -c --arg path "$bundle_rel" '. + [$path]' <<<"$VERIFIED_BUNDLES")
    else
      FAILED_BUNDLES=$(jq -c --arg path "$bundle_rel" '. + [$path]' <<<"$FAILED_BUNDLES")
    fi
  done
  set -u
elif [[ "$MODE" == "required" ]]; then
  die "required governance needs the AERP CLI"
fi

[[ "$(jq 'length' <<<"$FAILED_BUNDLES")" == "0" ]] ||
  die "one or more existing Evidence bundles failed AERP validation or artifact verification"

BINDINGS="$DEPLOY_DIR/isee-bindings.json"
[[ "$FORCE" == "true" || ! -e "$BINDINGS" ]] ||
  die "isee-bindings.json already exists; use --force only after reviewing the replacement"
BINDINGS_TMP="$DEPLOY_DIR/.isee-bindings.$$.json"
jq -n \
  --arg deploymentId "$DEPLOYMENT_ID" \
  --arg mode "$MODE" \
  --argjson intents "$INTENT_BINDINGS" \
  --argjson structures "$STRUCTURE_BINDINGS" \
  --argjson manifest "$MANIFEST_BINDING" \
  --argjson template "$TEMPLATE_BINDING" \
  --argjson parameters "$PARAMETERS_BINDING" \
  '{
    schemaVersion:"git-ape-isee-bindings/v1",
    deploymentId:$deploymentId,
    governanceMode:$mode,
    intentRecords:$intents,
    structureRecords:$structures,
    executionManifest:$manifest,
    gates:["intent-fingerprint","approved-artifact-digests"],
    evidenceRequirements:["aerp-evidence-bundle/v1"],
    artifacts:{template:$template,parameters:$parameters,additional:[]}
  }' > "$BINDINGS_TMP"
write_json "$BINDINGS_TMP" "$BINDINGS"
rm -f "$BINDINGS_TMP"

bash "$VERIFY" --deployment-id "$DEPLOYMENT_ID" >/dev/null

CURRENT_BUNDLE=""
if [[ -f "$DEPLOY_DIR/evidence-status.json" ]]; then
  CURRENT_BUNDLE=$(jq -r '.bundle // empty' "$DEPLOY_DIR/evidence-status.json")
fi
if [[ -z "$CURRENT_BUNDLE" && "$BUNDLE_COUNT" -gt 0 ]]; then
  set +u
  for bundle in "${BUNDLES[@]}"; do
    CURRENT_BUNDLE="${bundle#"$DEPLOY_DIR"/}"
  done
  set -u
fi
if [[ -n "$CURRENT_BUNDLE" ]] &&
   jq -e --arg path ".azure/deployments/$DEPLOYMENT_ID/$CURRENT_BUNDLE" 'index($path) != null' <<<"$VERIFIED_BUNDLES" >/dev/null; then
  STATUS_TMP="$DEPLOY_DIR/.evidence-status.$$.json"
  if [[ -f "$DEPLOY_DIR/evidence-status.json" ]]; then
    jq '.status="verified" |
        .authoritative=true |
        .independentlyVerified=true |
        .reason="Validated and artifact-verified after ISEE adoption."' \
      "$DEPLOY_DIR/evidence-status.json" > "$STATUS_TMP"
  else
    jq -n --arg bundle "$CURRENT_BUNDLE" \
      '{schemaVersion:"git-ape-record-status/v1",recordType:"evidence",status:"verified",
        profile:"aerp-evidence-bundle/v1",bundle:$bundle,fingerprint:null,
        authoritative:true,independentlyVerified:true,
        reason:"Validated and artifact-verified after ISEE adoption."}' > "$STATUS_TMP"
  fi
  write_json "$STATUS_TMP" "$DEPLOY_DIR/evidence-status.json"
  rm -f "$STATUS_TMP"
fi

REPORT="$DEPLOY_DIR/isee-adoption.json"
REPORT_TMP="$DEPLOY_DIR/.isee-adoption.$$.json"
jq -n \
  --arg deploymentId "$DEPLOYMENT_ID" \
  --arg mode "$MODE" \
  --arg adoptedAt "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg intent "$INTENT_REL" \
  --arg bindings ".azure/deployments/$DEPLOYMENT_ID/isee-bindings.json" \
  --arg intentValidation "$(command -v adrp >/dev/null && echo authoritative || echo native-fingerprint-only)" \
  --arg evidenceValidation "$(command -v aerp >/dev/null && echo independent || echo not-run)" \
  --argjson structures "$STRUCTURE_BINDINGS" \
  --argjson verified "$VERIFIED_BUNDLES" '
  {
    schemaVersion:"git-ape-isee-adoption/v1",
    deploymentId:$deploymentId,
    governanceMode:$mode,
    adoptedAt:$adoptedAt,
    intent:{path:$intent,validation:$intentValidation},
    structures:$structures,
    evidence:{validation:$evidenceValidation,verifiedBundles:$verified},
    bindings:$bindings,
    notes:[
      "Existing Git-Ape records were adopted without regeneration.",
      "Intent authority remains governed by ADRP; adoption never ratifies a draft.",
      "Evidence is marked verified only after AERP validation and artifact verification."
    ]
  }' > "$REPORT_TMP"
write_json "$REPORT_TMP" "$REPORT"
rm -f "$REPORT_TMP"

echo "ISEE adoption completed for $DEPLOYMENT_ID ($MODE)."
echo "  Bindings: .azure/deployments/$DEPLOYMENT_ID/isee-bindings.json"
echo "  Report:   .azure/deployments/$DEPLOYMENT_ID/isee-adoption.json"
