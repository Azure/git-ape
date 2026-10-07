# Git-Ape Record Producer Contract

Git-Ape is a standalone producer of portable Intent and Evidence records.
Installing Ape Context or the ISEE suite is not required to preserve either.

## Conformance levels

### Producer

Git-Ape always supports this level:

- creates `ape-decision-record/v1` draft Intent records;
- creates `aerp-evidence-bundle/v1` Evidence bundles;
- creates `git-ape-execution-trace/v1` traces bound to a declared execution
  graph;
- validates declared nodes, transitions, required receipts, and successful
  terminal paths;
- computes canonical fingerprints and artifact SHA-256 digests;
- reports Intent as `draft`;
- reports Evidence as `generated`.

### Governed

Optional profile tooling adds:

- ADRP validation, authority, review, and ratification;
- ASRP Structure records, gates, and execution manifests;
- AERP independent validation and verification;
- cross-record lifecycle and drift management.

## Status rules

| Record | Native Git-Ape status | Governed status |
|---|---|---|
| Intent | `draft` | `ratified` or `effective` only through ADRP |
| Evidence | `generated` | `verified` only after AERP validation and verification |

Execution traces describe the observed workflow path. They do not replace
`state.json`, establish decision authority, or independently prove that a
control was effective.

Missing optional tooling must never cause Git-Ape to discard records or report
false success. Azure deployment state remains in `state.json`; record status is
kept separately.

## Compatibility

Git-Ape implements the versioned JSON profiles directly with its existing
Bash, `jq`, and SHA-256 command-line toolchain. It introduces no native runtime
or package dependency. Optional ISEE profile CLIs provide governance and
independent verification, not access to the portable formats themselves.

## Structured execution traces

The deploy workflow copies the canonical declared graph into the deployment
directory, archives the exact graph bytes used by each attempt, reconstructs
events from GitHub Actions step outcomes, and writes immutable per-attempt
artifacts:

```text
execution-graph.json
execution-graphs/<run-id>-<run-attempt>.json
traces/<run-id>-<run-attempt>.json
trace-validations/<run-id>-<run-attempt>.json
```

The trace validator rejects undeclared nodes or transitions, missing transition
receipts, graph digest drift, malformed node-transition-node ordering,
discontinuous ordered paths, and successful traces that omit mandatory nodes.
The archived graph, trace, and validation report are then captured in the
AERP-compatible Evidence bundle.

Workflow ownership is deliberate: CI reconstructs traces from actual step
outcomes instead of treating an agent's report about its own execution as
independent proof. Interactive execution remains supported, but its producer is
labelled `agent-observed` and carries no stronger assurance than that
provenance permits.

## Delayed ISEE adoption

Repositories may install the ISEE suite after Git-Ape onboarding or deployment.
Existing records are adopted in place:

```bash
.github/git-ape/isee/adopt-existing.sh \
  --deployment-id <id> \
  --mode optional
```

The command validates existing records with installed profile CLIs, verifies
existing Evidence against the original artifacts, creates exact-byte
`isee-bindings.json`, and writes `isee-adoption.json`. It never regenerates
records or ratifies a draft.

Required governance needs an explicitly ratified Intent:

```bash
.github/git-ape/isee/adopt-existing.sh \
  --deployment-id <id> \
  --mode required \
  --intent .github/ape-decisions/<ratified-record>.json
```
