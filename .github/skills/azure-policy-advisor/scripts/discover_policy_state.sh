#!/bin/bash
# Azure Policy Advisor — Policy State Discovery
#
# Inventories the current Azure Policy state for a subscription:
#   1. Active policy assignments (subscription scope, including those inherited
#      from any parent management group)
#   2. Initiative (policy-set) assignments
#   3. Unassigned CUSTOM policy definitions at subscription scope
#   4. Unassigned CUSTOM initiative definitions at subscription scope
#   5. Optionally: custom definitions at management-group scope
#
# Replaces the prose `az policy ...` query blocks in azure-policy-advisor
# SKILL.md Steps 2 + 3 so the model loads a deterministic script instead of
# generating those queries from natural language each run.
#
# Usage:
#   bash scripts/discover_policy_state.sh \
#     --subscription <sub-id> \
#     [--management-group <mg-name>] \
#     [--output <path>]      # default: stdout
#
# Output: JSON document with the schema documented in --help.
# Exit codes:
#   0 = success (state discovered; may include non-fatal errors in .errors[])
#   1 = az CLI missing, not authenticated, or required argument missing
#   2 = subscription query failed entirely

set -euo pipefail

SUBSCRIPTION=""
MANAGEMENT_GROUP=""
OUTPUT=""

usage() {
    cat <<EOF
Usage: $0 --subscription <sub-id> [--management-group <mg-name>] [--output <path>]

Required:
  --subscription      Azure subscription ID to query

Optional:
  --management-group  Management group name to also scan for custom definitions
  --output            File to write JSON to (default: stdout)
  -h, --help          Show this help

Output schema (JSON):
  {
    "subscription_id":            "<id>",
    "management_group":           "<name|null>",
    "assigned_policies":          [ {assignment_name, display_name, policy_definition_id,
                                     enforcement_mode, scope, source}, ... ],
    "assigned_initiatives":       [ {assignment_name, display_name, policy_set_definition_id,
                                     enforcement_mode, scope}, ... ],
    "unassigned_custom_policies": [ {definition_id, display_name, category,
                                     target_resource_type, effect, source}, ... ],
    "unassigned_custom_initiatives": [ {definition_id, display_name, ...} ],
    "errors": [ "non-fatal error message", ... ]
  }
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --subscription)       SUBSCRIPTION="$2"; shift 2 ;;
        --management-group)   MANAGEMENT_GROUP="$2"; shift 2 ;;
        --output)             OUTPUT="$2"; shift 2 ;;
        -h|--help)            usage; exit 0 ;;
        *)                    echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
done

if [[ -z "$SUBSCRIPTION" ]]; then
    echo "ERROR: --subscription is required" >&2
    usage >&2
    exit 1
fi

# Tool availability checks
for tool in az jq; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERROR: required tool '$tool' is not installed" >&2
        exit 1
    fi
done

if ! az account show >/dev/null 2>&1; then
    echo "ERROR: not authenticated to Azure (run 'az login')" >&2
    exit 1
fi

ERRORS=()

# 1. Active policy assignments at subscription scope (includes MG-inherited)
ASSIGNMENTS_JSON=$(
    az policy assignment list \
        --subscription "$SUBSCRIPTION" \
        --query "[?!contains(policyDefinitionId, 'policySetDefinitions')].{assignment_name:name, display_name:displayName, policy_definition_id:policyDefinitionId, enforcement_mode:enforcementMode, scope:scope}" \
        -o json 2>/dev/null
) || {
    ERRORS+=("policy assignment list failed for subscription $SUBSCRIPTION")
    ASSIGNMENTS_JSON="[]"
}

# Tag each assignment by source: subscription-scope vs management-group-inherited
ASSIGNED_POLICIES=$(echo "$ASSIGNMENTS_JSON" | jq '
    map(. + {source: (if (.scope // "") | contains("/managementGroups/") then "management-group-inherited" else "subscription" end)})
')

# 2. Initiative (policy-set) assignments
INITIATIVES_JSON=$(
    az policy assignment list \
        --subscription "$SUBSCRIPTION" \
        --query "[?contains(policyDefinitionId, 'policySetDefinitions')].{assignment_name:name, display_name:displayName, policy_set_definition_id:policyDefinitionId, enforcement_mode:enforcementMode, scope:scope}" \
        -o json 2>/dev/null
) || {
    ERRORS+=("policy initiative assignment list failed")
    INITIATIVES_JSON="[]"
}

# Build a set of assigned definition IDs so we can filter out already-assigned customs
ASSIGNED_IDS=$(echo "$ASSIGNED_POLICIES" | jq '[.[].policy_definition_id]')

# 3. Custom policy definitions at subscription scope (unassigned only)
SUB_CUSTOM_JSON=$(
    az policy definition list \
        --subscription "$SUBSCRIPTION" \
        --query "[?policyType=='Custom'].{definition_id:id, display_name:displayName, category:metadata.category, policy_rule:policyRule, effect:policyRule.then.effect}" \
        -o json 2>/dev/null
) || {
    ERRORS+=("policy definition list failed at subscription scope")
    SUB_CUSTOM_JSON="[]"
}

# 4. Custom policy definitions at MG scope (optional)
MG_CUSTOM_JSON="[]"
if [[ -n "$MANAGEMENT_GROUP" ]]; then
    MG_CUSTOM_JSON=$(
        az policy definition list \
            --management-group "$MANAGEMENT_GROUP" \
            --query "[?policyType=='Custom'].{definition_id:id, display_name:displayName, category:metadata.category, policy_rule:policyRule, effect:policyRule.then.effect}" \
            -o json 2>/dev/null
    ) || {
        ERRORS+=("policy definition list failed at management-group scope ($MANAGEMENT_GROUP)")
        MG_CUSTOM_JSON="[]"
    }
fi

# Normalize: extract target resource type from policyRule.if, tag source, filter out assigned
UNASSIGNED_CUSTOM_POLICIES=$(
    jq -n \
        --argjson sub "$SUB_CUSTOM_JSON" \
        --argjson mg  "$MG_CUSTOM_JSON" \
        --argjson assigned "$ASSIGNED_IDS" '
        def extract_target_type(rule):
            if rule == null then null
            elif (rule | type) == "object" and rule.field == "type" then rule.equals
            else
                (rule | objects | to_entries | map(
                    if (.value | type) == "array" then
                        (.value | map(extract_target_type(.)) | map(select(. != null)) | first // null)
                    elif (.value | type) == "object" then extract_target_type(.value)
                    else null end
                ) | map(select(. != null)) | first // null)
            end;

        ($sub | map(. + {source: "subscription"})) +
        ($mg  | map(. + {source: "management-group"}))
        | map({
            definition_id,
            display_name,
            category,
            target_resource_type: extract_target_type(.policy_rule.if // null),
            effect,
            source
          })
        | map(select(.definition_id as $id | $assigned | index($id) | not))
    '
)

# 5. Custom initiatives at subscription scope (unassigned only)
ASSIGNED_INITIATIVE_IDS=$(echo "$INITIATIVES_JSON" | jq '[.[].policy_set_definition_id]')
SUB_CUSTOM_INIT_JSON=$(
    az policy set-definition list \
        --subscription "$SUBSCRIPTION" \
        --query "[?policyType=='Custom'].{definition_id:id, display_name:displayName, description:description, policy_definitions:policyDefinitions}" \
        -o json 2>/dev/null
) || {
    ERRORS+=("policy set-definition list failed at subscription scope")
    SUB_CUSTOM_INIT_JSON="[]"
}

UNASSIGNED_CUSTOM_INITIATIVES=$(
    echo "$SUB_CUSTOM_INIT_JSON" \
    | jq --argjson assigned "$ASSIGNED_INITIATIVE_IDS" \
        'map(select(.definition_id as $id | $assigned | index($id) | not))'
)

ERRORS_JSON=$(printf '%s\n' "${ERRORS[@]+"${ERRORS[@]}"}" | jq -R . | jq -s 'map(select(. != ""))')

RESULT=$(jq -n \
    --arg sub "$SUBSCRIPTION" \
    --arg mg "$MANAGEMENT_GROUP" \
    --argjson assigned "$ASSIGNED_POLICIES" \
    --argjson assigned_init "$INITIATIVES_JSON" \
    --argjson unassigned "$UNASSIGNED_CUSTOM_POLICIES" \
    --argjson unassigned_init "$UNASSIGNED_CUSTOM_INITIATIVES" \
    --argjson errors "$ERRORS_JSON" \
    '{
        subscription_id: $sub,
        management_group: (if $mg == "" then null else $mg end),
        assigned_policies: $assigned,
        assigned_initiatives: $assigned_init,
        unassigned_custom_policies: $unassigned,
        unassigned_custom_initiatives: $unassigned_init,
        errors: $errors
    }')

if [[ -n "$OUTPUT" ]]; then
    echo "$RESULT" > "$OUTPUT"
    echo "Wrote policy state to $OUTPUT" >&2
else
    echo "$RESULT"
fi
