# Workshop Evidence — Transcript Schema

> Schema and conventions for capturing literal command output from workshop labs. Used by `scripts/capture-lab-evidence.sh` (records first run) and `scripts/verify-lab-evidence.sh` (diffs current vs committed transcripts).

## Why transcripts

Lab text drifts from real behaviour over time as agents and skills evolve. A literal capture of "command + actual output" is the ground truth a customer can compare against when they hit a discrepancy. Captured transcripts are diff-checked in CI; drift surfaces as a PR comment before customers see it.

## File layout

    workshops/track-<N>-<name>/
      evidence/
        lab-NN-transcript.md   # one per lab

Each transcript file is committed to the repo so reviewers can diff PR changes against it.

## File format

    # Lab NN Transcript

    > Captured: 2026-05-29 by <facilitator-name>
    > Environment: <Codespace | local | CI>
    > Azure subscription: <REDACTED-SUB>

    ## Step 1: <step name from lab>

    $ az account show --query "{name:name, id:id}" -o table
    Name                  Id
    --------------------  ----------------------------------
    Workshop Sandbox      <REDACTED-SUB>

Rules:

- Every command line begins with `$ ` (dollar + space).
- Output follows the command line immediately, no blank line.
- Steps are level-2 headings matching the lab's step headings.
- Sensitive values replaced with `<REDACTED-*>` tokens.

## Redaction tokens

| Class | Token |
|---|---|
| Subscription ID | `<REDACTED-SUB>` |
| Tenant ID | `<REDACTED-TENANT>` |
| App/SP object ID | `<REDACTED-APP-OBJ>` |
| Client ID | `<REDACTED-CLIENT-ID>` |
| Resource ID full path | `<REDACTED-RID>` |
| User principal | `<REDACTED-UPN>` |
| Token / PAT | `<REDACTED-TOKEN>` |
| Storage account suffix | `<REDACTED-RAND>` |
| Timestamp | `<REDACTED-TS>` |

`scripts/redact-evidence.js` applies these via regex. Commit only redacted transcripts.

## Drift tolerance

`verify-lab-evidence.sh` treats these as expected differences:

- All redacted tokens
- Whitespace at end-of-line
- Numeric durations
- Resource-creation order within a single deployment

Anything else is flagged as drift in the PR comment.

## Per-lab coverage

Not every lab step is captureable. The capture script skips human-in-the-loop steps and emits:

    ## Step 4: Approve in Copilot Chat
    > NOT CAPTURED: human-in-the-loop step.

Captureable today: `az`, `gh`, `bash` commands. NOT captureable: `@git-ape` chat invocations (these are facilitator-captured during dry-run).