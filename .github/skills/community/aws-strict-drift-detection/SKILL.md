---
name: aws-strict-drift-detection
description: "Deep, property-level configuration drift detection for AWS resources. Wraps CloudFormation's native stack drift detection with severity classification and an ignore list, and extends coverage to tagged resources that live outside a CloudFormation stack."
license: MIT
metadata:
  author: dawright22
  source: https://github.com/dawright22/aws_skills
  maturity: stable
  version: "1.0.0"
---

# AWS Strict Drift Detection

> Deep, property-level configuration drift detection for AWS resources.

## When to Use

- Deep, property-level configuration drift detection for AWS resources

## Procedure

A companion to `aws-cloudformation` that turns AWS's native, already-deep stack drift
detection into an actionable, severity-ranked report — and extends the same approach
to resources that are not managed by a CloudFormation stack.

Companion implementation (Azure equivalent, same severity-rules/ignore-list design):
https://github.com/dawright22/strict-drift-detection

## Table of Contents

- [Why CloudFormation drift detection alone isn't enough](#why-cloudformation-drift-detection-alone-isnt-enough)
- [Core Concepts](#core-concepts)
- [CLI Reference](#cli-reference)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Why CloudFormation drift detection alone isn't enough

`aws cloudformation detect-stack-drift` / `describe-stack-resource-drifts` already
returns deep, property-level `PropertyDifferences` (`PropertyPath`, `ExpectedValue`,
`ActualValue`, `DifferenceType`) for every resource in a stack. That part is already
"strict." What it does **not** do:

- Classify how serious each difference is — a changed tag and an opened security group
  rule show up with equal weight.
- Filter out noisy, expected differences (e.g. `CreationDate`, auto-generated ARNs).
- Cover resources that were created or tagged outside of any CloudFormation stack.

`aws-strict-drift-detection` layers a severity-rules engine and an ignore list on top of
CloudFormation's native output, and adds a tag-based path for unmanaged resources.

## Core Concepts

### CloudFormation-managed resources

1. `aws cloudformation detect-stack-drift --stack-name <stack>` kicks off an async
   drift-detection run and returns a `StackDriftDetectionId`.
2. Poll `aws cloudformation describe-stack-drift-detection-status` until `DETECTION_COMPLETE`.
3. `aws cloudformation describe-stack-resource-drifts --stack-name <stack>` returns every
   resource's `StackResourceDriftStatus` plus its `PropertyDifferences` array.
4. Each `PropertyDifferences[].PropertyPath` is classified against `drift-rules.json`
   (first-match-wins regex, mandatory `.*` catch-all) and filtered against
   `ignore-properties.json` before being reported.

### Tag-based resources (no CloudFormation stack)

For resources tagged (e.g. `git-ape:managed=true`) but not deployed via CloudFormation:

1. `aws resourcegroupstaggingapi get-resources --tag-filters Key=git-ape:managed,Values=true`
   enumerates managed-but-unstacked resources.
2. A baseline snapshot of each resource's `describe-*`/`get-*` output is captured on
   first run (mirroring the baseline-snapshot approach used by the Azure
   `strict-drift-detection` companion skill).
3. Subsequent runs re-fetch and diff against that baseline with the same severity
   rules and ignore list, so coverage is consistent whether or not the resource is
   stack-managed.

## CLI Reference

```bash
# Kick off and poll CloudFormation-native drift detection for a stack
aws cloudformation detect-stack-drift --stack-name my-saas-stack
aws cloudformation describe-stack-drift-detection-status --stack-drift-detection-id <id>
aws cloudformation describe-stack-resource-drifts --stack-name my-saas-stack

# Baseline tag-managed resources outside any stack (first run)
./aws-strict-detect-drift.sh --tag-filter git-ape:managed=true --baseline

# Compare tag-managed resources against their baseline
./aws-strict-detect-drift.sh --tag-filter git-ape:managed=true

# Only report findings at or above a severity
./aws-strict-detect-drift.sh --stack-name my-saas-stack --min-severity high
```

## Best Practices

- Run stack drift detection on a schedule (EventBridge + Lambda) rather than only
  on demand — drift accumulates silently between deployments.
- Re-baseline tag-managed resources deliberately after any approved manual change.
- Always add new IAM/security-group/encryption-related property paths to
  `drift-rules.json` as `critical`/`high` before relying on this in CI — the default
  catch-all classifies unmatched diffs as `info`.
- Exclude noisy, auto-generated properties (`CreationDate`, `LastModifiedTime`,
  generated physical IDs) via `ignore-properties.json` to avoid alert fatigue.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `describe-stack-resource-drifts` returns empty | Drift detection still running | Poll `describe-stack-drift-detection-status` until `DETECTION_COMPLETE` |
| Every tag-managed resource reports drift | No baseline captured yet | Run with `--baseline` first |
| Expected change reported as drift | Volatile property not in ignore list | Add its path pattern to `ignore-properties.json` |
| Findings missing expected severity | No matching rule in `drift-rules.json` | Add a pattern before the `.*` catch-all |
| Resource missing from tag-based scan | Resource untagged or tag key/value mismatch | Verify `--tag-filters` matches the resource's actual tags |

## Outputs

This is a reference skill: it does not generate files or make changes on its own. It returns the AWS CLI commands, boto3/SDK snippets, CloudFormation patterns, and guidance described in the Procedure section below, scoped to the user's current question.

## Constraints

**Always:**

- Verify CLI flags, API parameters, and resource properties against the current AWS CLI/SDK documentation before presenting them, since AWS APIs evolve.
- Recommend least-privilege IAM policies and secure-by-default configurations when giving examples.
- Call out regional availability or service quota caveats when they materially affect the recommendation.

**Never:**

- Invent CLI flags, API actions, or resource properties that are not documented.
- Apply destructive or cost-incurring AWS CLI commands on the user's behalf without explicit confirmation.

## Attribution

- **Author:** dawright22
- **Source:** <https://github.com/dawright22/aws_skills>
- **Support:** <https://github.com/dawright22/aws_skills/issues>
