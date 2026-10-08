#!/usr/bin/env bash

set -euo pipefail

ADRP_SCHEMA="ape-decision-record/v1"
AERP_RECORD_SCHEMA="aerp-evidence-record/v1"
AERP_BUNDLE_SCHEMA="aerp-evidence-bundle/v1"
STATUS_SCHEMA="git-ape-record-status/v1"
TRACE_GRAPH_SCHEMA="git-ape-execution-graph/v1"
TRACE_SCHEMA="git-ape-execution-trace/v1"
TRACE_VALIDATION_SCHEMA="git-ape-trace-validation/v1"
TOOL_VERSION="1"

die() {
  echo "error: $*" >&2
  exit 2
}

require_tools() {
  command -v jq >/dev/null || die "jq is required"
  if ! command -v sha256sum >/dev/null && ! command -v shasum >/dev/null; then
    die "sha256sum or shasum is required"
  fi
}

sha256_stream() {
  if command -v sha256sum >/dev/null; then
    sha256sum | awk '{print "sha256:" $1}'
  else
    shasum -a 256 | awk '{print "sha256:" $1}'
  fi
}

sha256_file() {
  [[ -f "$1" ]] || die "file not found: $1"
  if command -v sha256sum >/dev/null; then
    sha256sum "$1" | awk '{print "sha256:" $1}'
  else
    shasum -a 256 "$1" | awk '{print "sha256:" $1}'
  fi
}

fingerprint() {
  local profile="$1"
  local path="$2"
  [[ -f "$path" ]] || die "file not found: $path"
  case "$profile" in
    adrp)
      jq -cS 'del(.ratification)' "$path" | tr -d '\n' | sha256_stream
      ;;
    asrp|aerp)
      jq -cS '
        if (.integrity | type) == "object" then
          if .integrity.record_fingerprint? != null then .integrity.record_fingerprint = null else . end |
          if .integrity.bundle_fingerprint? != null then .integrity.bundle_fingerprint = null else . end |
          if .integrity.manifest_fingerprint? != null then .integrity.manifest_fingerprint = null else . end
        else .
        end
      ' "$path" | tr -d '\n' | sha256_stream
      ;;
    *) die "unsupported fingerprint profile: $profile" ;;
  esac
}

utc_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

new_uuid() {
  if [[ -r /proc/sys/kernel/random/uuid ]]; then
    tr '[:upper:]' '[:lower:]' < /proc/sys/kernel/random/uuid
  elif command -v uuidgen >/dev/null; then
    uuidgen | tr '[:upper:]' '[:lower:]'
  else
    die "uuidgen or /proc/sys/kernel/random/uuid is required"
  fi
}

write_json() {
  local source="$1"
  local destination="$2"
  local immutable="${3:-false}"
  [[ "$immutable" != "true" || ! -e "$destination" ]] ||
    die "refusing to overwrite immutable record: $destination"
  mkdir -p "$(dirname "$destination")"
  local temporary
  temporary="$(dirname "$destination")/.$(basename "$destination").$$.tmp"
  jq . "$source" > "$temporary"
  mv "$temporary" "$destination"
}

slug() {
  local value
  value=$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]' | sed -E 's/[^A-Z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-60)
  [[ "$value" =~ ^[A-Z] ]] || value="GIT-APE-${value:-INTENT}"
  printf '%s\n' "${value%-}"
}

media_type() {
  case "$1" in
    *.json) echo "application/json" ;;
    *.md) echo "text/markdown" ;;
    *.log|*.txt) echo "text/plain" ;;
    *) echo "application/octet-stream" ;;
  esac
}

infer_result() {
  local path="$1"
  local evidence_type="$2"
  local name
  name=$(basename "$path")
  [[ "$name" != "error.log" ]] || { echo "failed"; return; }
  if [[ "$path" == *.json ]] && jq empty "$path" >/dev/null 2>&1; then
    local normalized
    normalized=$(jq -r '[.result?, .status?, .overallStatus?, .overall_status?] | map(select(. != null) | tostring | ascii_downcase) | join(" ")' "$path")
    if [[ "$normalized" =~ fail|block|error|unhealthy ]]; then
      echo "failed"
      return
    fi
    if [[ "$normalized" =~ pass|succeed|healthy|complete ]]; then
      [[ "$evidence_type" == "assessment" ]] && echo "passed" || echo "succeeded"
      return
    fi
  fi
  echo "observed"
}

command_intent() {
  local source="" output="" status_output="" created_at="" force=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --source) source="${2:-}"; shift 2 ;;
      --output) output="${2:-}"; shift 2 ;;
      --status-output) status_output="${2:-}"; shift 2 ;;
      --created-at) created_at="${2:-}"; shift 2 ;;
      --force) force=true; shift ;;
      *) die "unknown intent argument: $1" ;;
    esac
  done
  [[ -n "$source" && -n "$output" && -n "$status_output" ]] ||
    die "intent requires --source, --output, and --status-output"
  jq -e 'type == "object"' "$source" >/dev/null || die "$source must contain a JSON object"
  [[ "$force" == "true" || ! -e "$output" ]] || die "refusing to overwrite immutable record: $output"

  created_at="${created_at:-$(utc_now)}"
  local source_digest deployment_id decision_id record_id existing_created inferred
  source_digest=$(sha256_file "$source")
  deployment_id=$(jq -r '
    (.intent // {}) as $i |
    [.deploymentId?, .deployment_id?, .project?, $i.project?]
    | map(select(type == "string" and length > 0))
    | .[0] // empty
  ' "$source")
  deployment_id="${deployment_id:-$(basename "$source" .json)}"
  decision_id=$(jq -r '(.intent.decision_id? // empty) | select(type == "string")' "$source")
  decision_id="${decision_id:-ADR-$(slug "$deployment_id")}"
  record_id=$(new_uuid)
  existing_created=""
  if [[ "$force" == "true" && -f "$output" ]]; then
    record_id=$(jq -r '.record_id // empty' "$output")
    existing_created=$(jq -r '.lifecycle.created_at // empty' "$output")
    [[ -n "$record_id" ]] || record_id=$(new_uuid)
    [[ -n "$existing_created" ]] && created_at="$existing_created"
  fi

  local record_tmp
  record_tmp="$(dirname "$output")/.intent-record.$$.json"
  mkdir -p "$(dirname "$output")"
  jq -n \
    --slurpfile source "$source" \
    --arg sourcePath "$source" \
    --arg sourceDigest "$source_digest" \
    --arg deploymentId "$deployment_id" \
    --arg decisionId "$decision_id" \
    --arg recordId "$record_id" \
    --arg createdAt "$created_at" '
    def strings:
      if type == "array" then
        [ .[] | select(type == "string") | gsub("^\\s+|\\s+$"; "") | select(length > 0) ] | unique
      else [] end;
    def text($value; $fallback):
      if ($value | type) == "string" and ($value | gsub("^\\s+|\\s+$"; "") | length) > 0
      then ($value | gsub("^\\s+|\\s+$"; "")) else $fallback end;
    def tradeoff($intent; $category):
      ($intent.tradeoffs[$category]? // {}) as $item |
      {
        impact: (if ["positive","negative","mixed","neutral","unknown"] | index($item.impact) then $item.impact else "unknown" end),
        summary: text($item.summary; (($category | ascii_upcase[0:1]) + $category[1:] + " trade-offs require review.")),
        evidence_refs: ($item.evidence_refs | strings),
        accepted_risks: ($item.accepted_risks | strings)
      };
    $source[0] as $s |
    ($s.intent // {}) as $i |
    ([($s.resources // [])[]? | select(type == "object") | text((.type // .name); "")]
      | map(select(length > 0)) | unique | join(", ")) as $resources |
    (text(($s.environment // $i.environment); "unspecified environment")) as $environment |
    (text($i.decision_statement; text($i.outcome; text($s.goal;
      ("Use Git-Ape to generate, review, and execute " + (if $resources == "" then "the requested Azure workload" else $resources end) + "."))))) as $statement |
    (if ($i.drivers | type) == "array" and ($i.drivers | length) > 0 then
       [$i.drivers | to_entries[] | select(.value | type == "object") |
         .value as $d | {
           name: text($d.name; ("Driver " + ((.key + 1) | tostring))),
           category: (if ["security","cost","compliance","operations","architecture","product","other"] | index($d.category) then $d.category else "other" end),
           criterion: text($d.criterion; text($d.description; "Requires author review.")),
           source_refs: (if ($d.source_refs | strings | length) > 0 then ($d.source_refs | strings) else ["git-ape-source"] end)
         }]
     else [{name:"Requested deployment outcome",category:"product",criterion:$statement,source_refs:["git-ape-source"]}] end) as $drivers |
    (if ($i.alternatives | type) == "array" and ($i.alternatives | length) > 0 then
       [$i.alternatives | to_entries[] | select(.value | type == "object") |
         .value as $a | (text(($a.id // $a.alternative_id); ("alternative-" + ((.key + 1) | tostring)))) as $id |
         {id:$id,title:text($a.title;$id),description:text($a.description;""),benefits:($a.benefits|strings),drawbacks:($a.drawbacks|strings),
          rejection_reason:(if ($a.rejection_reason|type) == "string" then $a.rejection_reason else null end)}]
     else [{id:"git-ape-managed-execution",title:"Git-Ape managed execution",description:$statement,
            benefits:["Preserves reviewable deployment artifacts and explicit execution gates"],
            drawbacks:["Alternatives and trade-offs still require author review"],rejection_reason:null}] end) as $alternatives |
    (text($i.selected_alternative; $alternatives[0].id)) as $requestedSelected |
    (if any($alternatives[]; .id == $requestedSelected) then $requestedSelected else $alternatives[0].id end) as $selected |
    (text(($s.user // $i.decision_owner); "unknown")) as $owner |
    ((($i.gaps | strings)
      + (if ($s | has("intent")) then [] else ["Intent was inferred from Git-Ape requirements and requires author review"] end)
      + (if ($i.alternatives | type) == "array" and ($i.alternatives | length) > 0 then [] else ["Alternative options have not been supplied"] end)
      + (if $owner == "unknown" then ["Decision owner has not been identified"] else [] end)) | unique) as $gaps |
    {
      schema_version:"ape-decision-record/v1",
      decision_id:$decisionId,
      record_id:$recordId,
      record_version:1,
      status:"draft",
      title:text($i.title;("Git-Ape intent for " + $deploymentId)),
      decision_statement:$statement,
      context:{
        problem:text($i.problem;text($s.problem;("Define how Git-Ape should deliver " + (if $resources == "" then "the requested Azure workload" else $resources end) + " for " + $environment + "."))),
        scope:(if ($i.scope|strings|length)>0 then ($i.scope|strings) else [$deploymentId,$environment] end),
        stakeholders:(if ($i.stakeholders|strings|length)>0 then ($i.stakeholders|strings) else ["platform engineering","workload owner"] end),
        concerns:(if ($i.concerns|strings|length)>0 then ($i.concerns|strings) else ["security","cost","compliance","operations"] end)
      },
      drivers:$drivers,
      alternatives:$alternatives,
      selected_alternative:$selected,
      rationale:text($i.rationale;"This draft preserves the intent supplied to Git-Ape; rationale requires author review."),
      tradeoffs:{
        security:tradeoff($i;"security"),cost:tradeoff($i;"cost"),
        compliance:tradeoff($i;"compliance"),operations:tradeoff($i;"operations")
      },
      authority:{
        authority_status:"unknown",
        decision_owner:(if $owner=="unknown" then null else $owner end),
        deciders:($i.deciders|strings),approvers:($i.approvers|strings),
        delegation_ref:(if ($i.delegation_ref|type)=="string" then $i.delegation_ref else null end)
      },
      provenance:{
        sources:[{id:"git-ape-source",uri:$sourcePath,title:"Git-Ape captured requirements and intent",
          authority_status:(if ($s|has("intent")) then "user-confirmed" else "unknown" end),digest:$sourceDigest}],
        activities:[{id:"git-ape-intent-capture",type:"generation",timestamp:$createdAt,used:["git-ape-source"],associated_agents:["git-ape-record-producer"]}],
        agents:[{id:"git-ape-record-producer",type:"software-agent",name:"Git-Ape",role:"draft Intent producer",
          acted_on_behalf_of:(if $owner=="unknown" then null else $owner end)}]
      },
      lifecycle:{created_at:$createdAt,effective_at:null,review_by:null,expires_at:null,
        review_triggers:(if ($i.review_triggers|strings|length)>0 then ($i.review_triggers|strings)
          else ["deployment requirements change","security or compliance constraints change","deployment authority changes"] end)},
      consequences:{positive:($i.positive_consequences|strings),negative:($i.negative_consequences|strings),risks:($i.risks|strings),
        actions:(if ($i.actions|strings|length)>0 then ($i.actions|strings) else ["Review and ratify this Intent before treating it as authoritative"] end)},
      implementation:{policy_refs:($i.policy_refs|strings),artifact_refs:[$sourcePath],evidence_refs:[]},
      relationships:{revises:null,supersedes:null,invalidates:null,implements:($i.implements|strings),depends_on:($i.depends_on|strings)},
      autonomy:{
        proceed:(if ($i.proceed|strings|length)>0 then ($i.proceed|strings) else ["Generate and assess deployment artifacts without creating Azure resources"] end),
        always_ask:(if ($i.always_ask|strings|length)>0 then ($i.always_ask|strings) else ["Approve Azure deployment after reviewing security, cost, and architecture outputs"] end),
        never:(if ($i.never|strings|length)>0 then ($i.never|strings) else ["Deploy Azure resources without explicit approval"] end)
      },
      gaps:$gaps,
      ratification:null
    }
  ' > "$record_tmp"

  write_json "$record_tmp" "$output"
  rm -f "$record_tmp"
  local record_fingerprint status_tmp
  record_fingerprint=$(fingerprint adrp "$output")
  inferred=$(jq -c '
    [.gaps[] | select(
      . == "Intent was inferred from Git-Ape requirements and requires author review" or
      . == "Alternative options have not been supplied" or
      . == "Decision owner has not been identified"
    )]
  ' "$output")
  status_tmp="$(dirname "$status_output")/.intent-status.$$.json"
  mkdir -p "$(dirname "$status_output")"
  jq -n \
    --arg profile "$ADRP_SCHEMA" \
    --arg record "$output" \
    --arg fingerprint "$record_fingerprint" \
    --arg source "$source" \
    --arg sourceDigest "$source_digest" \
    --argjson notes "$inferred" \
    '{schemaVersion:"git-ape-record-status/v1",recordType:"intent",status:"draft",profile:$profile,
      record:$record,fingerprint:$fingerprint,source:$source,sourceDigest:$sourceDigest,
      authoritative:false,independentlyVerified:false,notes:$notes}' > "$status_tmp"
  write_json "$status_tmp" "$status_output"
  rm -f "$status_tmp"
  jq -cS . "$status_output"
}

artifact_mapping() {
  case "$1" in
    requirements.json) echo $'observation\tinput' ;;
    authorization.json|intent.json|intent-status.json) echo $'approval\tsupporting' ;;
    template.json) echo $'execution\toutput' ;;
    parameters.json) echo $'execution\tinput' ;;
    architecture.md) echo $'observation\treport' ;;
    security-analysis.md|security-gate.json|policy-assessment.md|availability-report.md|preflight-report.md|cost-estimate.json|waf-review.md) echo $'assessment\treport' ;;
    policy-recommendations.json) echo $'assessment\tsupporting' ;;
    metadata.json|state.json) echo $'execution\tsupporting' ;;
    deployment.log) echo $'execution\tlog' ;;
    tests.json) echo $'outcome\treport' ;;
    error.log) echo $'outcome\tlog' ;;
    architecture-live.md) echo $'observation\tsnapshot' ;;
    execution-graph.json|execution-graphs/*.json) echo $'execution\tsupporting' ;;
    trace-validation.json|trace-validations/*.json) echo $'assessment\treport' ;;
    traces/*.json) echo $'execution\tlog' ;;
    *) return 1 ;;
  esac
}

command_trace() {
  local graph="" events="" output="" validation_output="" invocation_id=""
  local workflow="" identity="" producer_type="workflow" outcome="" started_at="" ended_at=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --graph) graph="${2:-}"; shift 2 ;;
      --events) events="${2:-}"; shift 2 ;;
      --output) output="${2:-}"; shift 2 ;;
      --validation-output) validation_output="${2:-}"; shift 2 ;;
      --invocation-id) invocation_id="${2:-}"; shift 2 ;;
      --workflow) workflow="${2:-}"; shift 2 ;;
      --identity) identity="${2:-}"; shift 2 ;;
      --producer-type) producer_type="${2:-}"; shift 2 ;;
      --outcome) outcome="${2:-}"; shift 2 ;;
      --started-at) started_at="${2:-}"; shift 2 ;;
      --ended-at) ended_at="${2:-}"; shift 2 ;;
      *) die "unknown trace argument: $1" ;;
    esac
  done
  [[ -n "$graph" && -n "$events" && -n "$output" && -n "$validation_output" &&
     -n "$invocation_id" && -n "$workflow" && -n "$identity" && -n "$outcome" ]] ||
    die "trace requires --graph, --events, --output, --validation-output, --invocation-id, --workflow, --identity, and --outcome"
  [[ "$outcome" == "succeeded" || "$outcome" == "failed" ]] ||
    die "trace outcome must be succeeded or failed"
  [[ "$producer_type" == "workflow" || "$producer_type" == "agent-observed" ]] ||
    die "trace producer type must be workflow or agent-observed"
  [[ ! -e "$output" ]] || die "refusing to overwrite immutable record: $output"
  [[ -f "$graph" ]] || die "file not found: $graph"
  [[ -f "$events" ]] || die "file not found: $events"

  jq -e --arg schema "$TRACE_GRAPH_SCHEMA" '
    . as $g |
    ($g.nodes | map(.id)) as $nodeIds |
    $g.schemaVersion == $schema and
    ($g.graphId | type == "string" and length > 0) and
    ($g.entryNode | type == "string" and length > 0) and
    ($g.successTerminal | type == "string" and length > 0) and
    ($g.nodes | type == "array" and length > 0) and
    ($g.edges | type == "array") and
    ($nodeIds | length == (unique | length)) and
    ($nodeIds | index($g.entryNode) != null) and
    ($nodeIds | index($g.successTerminal) != null) and
    all($g.edges[]; . as $edge |
      ($edge.from | type == "string" and length > 0) and
      ($edge.to | type == "string" and length > 0) and
      ($nodeIds | index($edge.from) != null) and
      ($nodeIds | index($edge.to) != null))
  ' "$graph" >/dev/null || die "$graph is not a valid $TRACE_GRAPH_SCHEMA graph"
  jq -e '
    type == "array" and
    all(.[];
      (.id | type == "string" and length > 0) and
      (.type == "node" or .type == "transition") and
      (.recordedAt | type == "string" and length > 0) and
      (if .type == "node" then
         (.node | type == "string" and length > 0) and
         (.status == "completed" or .status == "failed") and
         (.evidence | type == "array")
       else
         (.from | type == "string" and length > 0) and
         (.to | type == "string" and length > 0) and
         (.evidence | type == "array")
       end))
  ' "$events" >/dev/null || die "$events must contain a valid trace event array"

  started_at="${started_at:-$(utc_now)}"
  ended_at="${ended_at:-$(utc_now)}"
  local graph_digest trace_tmp
  graph_digest=$(sha256_file "$graph")
  trace_tmp="$(dirname "$output")/.execution-trace.$$.json"
  mkdir -p "$(dirname "$output")"
  jq -n \
    --arg schema "$TRACE_SCHEMA" \
    --arg traceId "$(new_uuid)" \
    --arg invocationId "$invocation_id" \
    --arg workflow "$workflow" \
    --arg identity "$identity" \
    --arg producerType "$producer_type" \
    --arg graphPath "$graph" \
    --arg graphDigest "$graph_digest" \
    --arg startedAt "$started_at" \
    --arg endedAt "$ended_at" \
    --arg outcome "$outcome" \
    --slurpfile events "$events" '
    {
      schemaVersion:$schema,
      traceId:$traceId,
      invocationId:$invocationId,
      workflow:$workflow,
      producer:{type:$producerType,identity:$identity},
      graph:{path:$graphPath,digest:$graphDigest},
      startedAt:$startedAt,
      endedAt:$endedAt,
      outcome:$outcome,
      events:$events[0]
    }
  ' > "$trace_tmp"
  write_json "$trace_tmp" "$output" true
  rm -f "$trace_tmp"

  command_trace_validate \
    --graph "$graph" \
    --trace "$output" \
    --output "$validation_output"
}

command_trace_validate() {
  local graph="" trace="" output=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --graph) graph="${2:-}"; shift 2 ;;
      --trace) trace="${2:-}"; shift 2 ;;
      --output) output="${2:-}"; shift 2 ;;
      *) die "unknown trace-validate argument: $1" ;;
    esac
  done
  [[ -n "$graph" && -n "$trace" && -n "$output" ]] ||
    die "trace-validate requires --graph, --trace, and --output"
  [[ -f "$graph" ]] || die "file not found: $graph"
  [[ -f "$trace" ]] || die "file not found: $trace"

  local expected_graph_digest actual_graph_digest report_tmp status
  expected_graph_digest=$(sha256_file "$graph")
  actual_graph_digest=$(jq -r '.graph.digest // empty' "$trace")
  report_tmp="$(dirname "$output")/.trace-validation.$$.json"
  mkdir -p "$(dirname "$output")"

  jq -n \
    --arg schema "$TRACE_VALIDATION_SCHEMA" \
    --arg graphPath "$graph" \
    --arg tracePath "$trace" \
    --arg expectedGraphDigest "$expected_graph_digest" \
    --arg actualGraphDigest "$actual_graph_digest" \
    --arg validatedAt "$(utc_now)" \
    --slurpfile graph "$graph" \
    --slurpfile trace "$trace" '
    $graph[0] as $g |
    $trace[0] as $t |
    ($g.nodes | map(.id)) as $nodeIds |
    ($g.edges | map({key:(.from + "\u0000" + .to), value:.}) | from_entries) as $edges |
    ($t.events // []) as $events |
    ($t.events | map(select(.type == "node"))) as $nodeEvents |
    ($t.events | map(select(.type == "transition"))) as $transitions |
    ($nodeEvents | map(.node)) as $observedNodes |
    ([
      if $t.schemaVersion != "git-ape-execution-trace/v1" then
        {code:"INVALID_TRACE_SCHEMA",message:"Trace schemaVersion is not git-ape-execution-trace/v1."}
      else empty end,
      if $actualGraphDigest != $expectedGraphDigest then
        {code:"GRAPH_DIGEST_MISMATCH",message:"Trace is not bound to the supplied graph bytes."}
      else empty end,
      ($nodeEvents[] as $event |
        select(($nodeIds | index($event.node)) == null) |
        {code:"UNDECLARED_NODE",message:("Trace references undeclared node " + $event.node + "."),eventId:$event.id}),
      ($transitions[] as $event |
        ($event.from + "\u0000" + $event.to) as $key |
        if $edges[$key] == null then
          {code:"UNDECLARED_TRANSITION",message:("Transition " + $event.from + " -> " + $event.to + " is not declared."),eventId:$event.id}
        else
          (($edges[$key].requiredEvidence // []) - ($event.evidence // [])) as $missing |
          if ($missing | length) > 0 then
            {code:"MISSING_REQUIRED_EVIDENCE",message:("Transition " + $event.from + " -> " + $event.to + " lacks required evidence."),eventId:$event.id,missingEvidence:$missing}
          else empty end
        end),
      if ($nodeEvents | length) == 0 or $nodeEvents[0].node != $g.entryNode then
        {code:"INVALID_ENTRY_NODE",message:("Trace must begin at " + $g.entryNode + ".")}
      else empty end,
      if ($g.ordered // false) then
        if ($events | length) % 2 == 0 then
          {code:"INVALID_EVENT_SEQUENCE",message:"An ordered trace must begin and end with node events, with transitions between them."}
        else empty end,
        [range(0; $events | length) as $i |
          if ($i % 2 == 0 and $events[$i].type != "node") or
             ($i % 2 == 1 and $events[$i].type != "transition") then
            {code:"INVALID_EVENT_SEQUENCE",message:("Unexpected event type at position " + ($i | tostring) + "."),eventId:($events[$i].id // null)}
          else empty end][],
        [range(1; ($events | length); 2) as $i |
          select(($i + 1) < ($events | length)) |
          select($events[$i].from != $events[$i - 1].node or
                 $events[$i].to != $events[$i + 1].node) |
          {code:"TRANSITION_NODE_MISMATCH",message:("Transition " + ($events[$i].id // ($i | tostring)) + " does not connect its adjacent node events."),eventId:($events[$i].id // null)}][]
      else empty end,
      if $t.outcome == "succeeded" then
        ($g.nodes[] as $required |
          select($required.requiredForSuccess == true) |
          select((any($nodeEvents[]; .node == $required.id and .status == "completed")) | not) |
          {code:"MISSING_REQUIRED_NODE",message:("Successful trace is missing required completed node " + $required.id + "."),node:$required.id}),
        if (any($nodeEvents[]; .node == $g.successTerminal and .status == "completed")) | not then
          {code:"MISSING_SUCCESS_TERMINAL",message:("Successful trace does not complete " + $g.successTerminal + ".")}
        elif ($g.ordered // false) and
             (($events | length) == 0 or $events[-1].type != "node" or $events[-1].node != $g.successTerminal) then
          {code:"INVALID_SUCCESS_TERMINAL",message:("Successful ordered trace must end at " + $g.successTerminal + ".")}
        else empty end
      elif ($g.ordered // false) and
           (($events | length) == 0 or $events[-1].type != "node" or $events[-1].status != "failed") then
        {code:"MISSING_FAILED_TERMINAL",message:"Failed ordered trace must end with the failed node event."}
      else empty end
    ]) as $errors |
    {
      schemaVersion:$schema,
      status:(if ($errors | length) == 0 then "passed" else "failed" end),
      graph:{path:$graphPath,digest:$expectedGraphDigest},
      trace:{path:$tracePath,id:($t.traceId // null),invocationId:($t.invocationId // null),outcome:($t.outcome // null)},
      validatedAt:$validatedAt,
      summary:{errors:($errors | length),nodesObserved:($nodeEvents | length),transitionsObserved:($transitions | length)},
      errors:$errors
    }
  ' > "$report_tmp"
  write_json "$report_tmp" "$output" true
  rm -f "$report_tmp"
  status=$(jq -r '.status' "$output")
  jq -cS . "$output"
  [[ "$status" == "passed" ]] || return 1
}

binding_for() {
  local profile="$1" path="$2"
  [[ -f "$path" ]] || die "file not found: $path"
  local fp
  fp=$(fingerprint "$profile" "$path")
  if [[ "$profile" == "adrp" ]]; then
    jq -c --arg fp "$fp" '
      select(.schema_version == "ape-decision-record/v1") |
      {decision_id,record_id,record_version,record_fingerprint:$fp}
    ' "$path"
  else
    jq -c --arg fp "$fp" '
      select(.schema_version == "ape-structure-record/v1") |
      {structure_id,record_id,record_version,record_fingerprint:$fp}
    ' "$path"
  fi
}

command_evidence() {
  local deployment_dir="" output="" status_output="" identity="" target=""
  local producer_version="unknown" invocation_id="" observed_at="" environment="azure"
  local decisions=() structures=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --deployment-dir) deployment_dir="${2:-}"; shift 2 ;;
      --output) output="${2:-}"; shift 2 ;;
      --status-output) status_output="${2:-}"; shift 2 ;;
      --identity) identity="${2:-}"; shift 2 ;;
      --target) target="${2:-}"; shift 2 ;;
      --producer-version) producer_version="${2:-}"; shift 2 ;;
      --invocation-id) invocation_id="${2:-}"; shift 2 ;;
      --observed-at) observed_at="${2:-}"; shift 2 ;;
      --environment) environment="${2:-}"; shift 2 ;;
      --decision) decisions+=("${2:-}"); shift 2 ;;
      --structure) structures+=("${2:-}"); shift 2 ;;
      *) die "unknown evidence argument: $1" ;;
    esac
  done
  [[ -n "$deployment_dir" && -n "$output" && -n "$status_output" && -n "$identity" && -n "$target" ]] ||
    die "evidence requires --deployment-dir, --output, --status-output, --identity, and --target"
  [[ -d "$deployment_dir" ]] || die "deployment directory not found: $deployment_dir"
  [[ ! -e "$output" ]] || die "refusing to overwrite immutable record: $output"
  invocation_id="${invocation_id:-$(basename "$deployment_dir")}"
  observed_at="${observed_at:-$(utc_now)}"

  local decision_json="[]" structure_json="[]" item
  set +u
  for item in "${decisions[@]}"; do
    decision_json=$(jq -c --argjson item "$(binding_for adrp "$item")" '. + [$item]' <<<"$decision_json")
  done
  for item in "${structures[@]}"; do
    structure_json=$(jq -c --argjson item "$(binding_for asrp "$item")" '. + [$item]' <<<"$structure_json")
  done
  set -u

  local producer_json
  producer_json=$(jq -cn --arg version "$producer_version" --arg identity "$identity" --arg invocation "$invocation_id" \
    '{name:"git-ape",version:$version,identity:$identity,invocation_id:$invocation}')
  local records="[]" count=0 name mapping evidence_type role path digest result media record_tmp record_fp
  local artifact_paths=()
  for name in architecture-live.md architecture.md authorization.json availability-report.md cost-estimate.json deployment.log error.log execution-graph.json intent-status.json intent.json metadata.json parameters.json policy-assessment.md policy-recommendations.json preflight-report.md requirements.json security-analysis.md security-gate.json state.json template.json tests.json trace-validation.json waf-review.md; do
    [[ -f "$deployment_dir/$name" ]] && artifact_paths+=("$deployment_dir/$name")
  done
  if [[ -d "$deployment_dir/traces" ]]; then
    while IFS= read -r path; do
      artifact_paths+=("$path")
    done < <(find "$deployment_dir/traces" -maxdepth 1 -type f -name '*.json' -print | LC_ALL=C sort)
  fi
  if [[ -d "$deployment_dir/execution-graphs" ]]; then
    while IFS= read -r path; do
      artifact_paths+=("$path")
    done < <(find "$deployment_dir/execution-graphs" -maxdepth 1 -type f -name '*.json' -print | LC_ALL=C sort)
  fi
  if [[ -d "$deployment_dir/trace-validations" ]]; then
    while IFS= read -r path; do
      artifact_paths+=("$path")
    done < <(find "$deployment_dir/trace-validations" -maxdepth 1 -type f -name '*.json' -print | LC_ALL=C sort)
  fi
  for path in "${artifact_paths[@]}"; do
    name="${path#"$deployment_dir"/}"
    [[ -f "$path" ]] || continue
    mapping=$(artifact_mapping "$name")
    IFS=$'\t' read -r evidence_type role <<<"$mapping"
    digest=$(sha256_file "$path")
    result=$(infer_result "$path" "$evidence_type")
    media=$(media_type "$path")
    record_tmp="$deployment_dir/.evidence-record.$$.json"
    jq -n \
      --arg schema "$AERP_RECORD_SCHEMA" \
      --arg evidenceId "$(new_uuid)" \
      --arg type "$evidence_type" \
      --arg deployment "$(basename "$deployment_dir")" \
      --arg name "${name%.*}" \
      --arg path "$name" \
      --arg digest "$digest" \
      --arg role "$role" \
      --arg media "$media" \
      --arg result "$result" \
      --arg observed "$observed_at" \
      --arg environment "$environment" \
      --arg target "$target" \
      --arg toolVersion "$TOOL_VERSION" \
      --argjson producer "$producer_json" \
      --argjson decisions "$decision_json" \
      --argjson structures "$structure_json" '
      {schema_version:$schema,evidence_id:$evidenceId,evidence_type:$type,
       subject:{name:$name,uri:("git-ape:deployment:"+$deployment+"#"+$path),digest:null},
       claim:{statement:("Git-Ape produced "+$path+" during deployment "+$deployment),result:$result,
         summary:("Captured and fingerprinted Git-Ape artifact "+$path+"."),criteria_refs:[]},
       producer:$producer,method:{name:"git-ape-native-producer",version:$toolVersion,parameters_digest:null},
       timing:{observed_at:$observed,valid_from:null,valid_until:null},
       environment:{name:$environment,target:$target,correlation_ids:{git_ape_deployment_id:$deployment}},
       decision_bindings:$decisions,structure_bindings:$structures,policy_refs:[],control_refs:[],
       artifacts:[{name:($path|split("/")|last),path:$path,media_type:$media,digest:$digest,role:$role}],
       relationships:{derived_from:[],supersedes:[],revokes:[]},integrity:{record_fingerprint:null}}
    ' > "$record_tmp"
    record_fp=$(fingerprint aerp "$record_tmp")
    jq --arg fp "$record_fp" '.integrity.record_fingerprint=$fp' "$record_tmp" > "$record_tmp.final"
    records=$(jq -c --argjson item "$(cat "$record_tmp.final")" '. + [$item]' <<<"$records")
    rm -f "$record_tmp" "$record_tmp.final"
    count=$((count + 1))
  done
  [[ "$count" -gt 0 ]] || die "no recognised Git-Ape artifacts found in $deployment_dir"

  mkdir -p "$(dirname "$output")" "$(dirname "$status_output")"
  local bundle_tmp bundle_fp relative_output
  bundle_tmp="$(dirname "$output")/.evidence-bundle.$$.json"
  jq -n \
    --arg schema "$AERP_BUNDLE_SCHEMA" \
    --arg bundleId "$(new_uuid)" \
    --arg created "$observed_at" \
    --arg deployment "$(basename "$deployment_dir")" \
    --argjson producer "$producer_json" \
    --argjson records "$records" '
    {schema_version:$schema,bundle_id:$bundleId,created_at:$created,producer:$producer,
     subject:{name:$deployment,uri:("git-ape:deployment:"+$deployment),digest:null},
     records:$records,integrity:{bundle_fingerprint:null}}
  ' > "$bundle_tmp"
  bundle_fp=$(fingerprint aerp "$bundle_tmp")
  jq --arg fp "$bundle_fp" '.integrity.bundle_fingerprint=$fp' "$bundle_tmp" > "$bundle_tmp.final"
  write_json "$bundle_tmp.final" "$output" true
  rm -f "$bundle_tmp" "$bundle_tmp.final"

  relative_output="${output#"$deployment_dir"/}"
  local status_tmp
  status_tmp="$(dirname "$status_output")/.evidence-status.$$.json"
  jq -n --arg profile "$AERP_BUNDLE_SCHEMA" --arg bundle "$relative_output" --arg fingerprint "$bundle_fp" \
    '{schemaVersion:"git-ape-record-status/v1",recordType:"evidence",status:"generated",profile:$profile,
      bundle:$bundle,fingerprint:$fingerprint,authoritative:false,independentlyVerified:false,
      reason:"Git-Ape emitted a conformant bundle; independent AERP verification has not run."}' > "$status_tmp"
  write_json "$status_tmp" "$status_output"
  rm -f "$status_tmp"
  jq -cS . "$status_output"
}

usage() {
  cat <<'EOF'
Usage:
  git-ape-records.sh intent --source FILE --output FILE --status-output FILE [--created-at TIME] [--force]
  git-ape-records.sh trace --graph FILE --events FILE --output FILE --validation-output FILE --invocation-id ID --workflow NAME --identity ID --outcome succeeded|failed [--producer-type workflow|agent-observed] [options]
  git-ape-records.sh trace-validate --graph FILE --trace FILE --output FILE
  git-ape-records.sh evidence --deployment-dir DIR --output FILE --status-output FILE --identity ID --target TARGET [options]
  git-ape-records.sh fingerprint --profile adrp|asrp|aerp FILE
EOF
}

main() {
  require_tools
  local command="${1:-}"
  [[ -n "$command" ]] || { usage; exit 2; }
  shift
  case "$command" in
    intent) command_intent "$@" ;;
    trace) command_trace "$@" ;;
    trace-validate) command_trace_validate "$@" ;;
    evidence) command_evidence "$@" ;;
    fingerprint)
      [[ "${1:-}" == "--profile" && -n "${2:-}" && -n "${3:-}" ]] || die "fingerprint requires --profile and a file"
      fingerprint "$2" "$3"
      ;;
    -h|--help|help) usage ;;
    *) die "unknown command: $command" ;;
  esac
}

main "$@"
