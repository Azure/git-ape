---
title: "Community Skill Packs"
sidebar_label: "Packs"
sidebar_position: 3
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/skill-packs/ -->


# Community Skill Packs

Packs list independent community skills in `.github/skill-packs/<name>/pack.json`.
They do not activate skills, introduce dependencies, or group the client UI.
Search with `/git-ape-skills search <query>`; pack names, descriptions, authors, and member names are searchable.

## aws-skills

AWS service guidance for compute, storage, networking, identity, messaging, monitoring, security, and cost estimation.

**Author:** dawright22

| Member | Source |
|--------|--------|
| [aws-api-gateway](./community/aws-api-gateway) | `.github/community-skills/aws-api-gateway/` |
| [aws-bedrock](./community/aws-bedrock) | `.github/community-skills/aws-bedrock/` |
| [aws-cloudformation](./community/aws-cloudformation) | `.github/community-skills/aws-cloudformation/` |
| [aws-cloudwatch](./community/aws-cloudwatch) | `.github/community-skills/aws-cloudwatch/` |
| [aws-cognito](./community/aws-cognito) | `.github/community-skills/aws-cognito/` |
| [aws-cost-estimator](./community/aws-cost-estimator) | `.github/community-skills/aws-cost-estimator/` |
| [aws-dynamodb](./community/aws-dynamodb) | `.github/community-skills/aws-dynamodb/` |
| [aws-ec2](./community/aws-ec2) | `.github/community-skills/aws-ec2/` |
| [aws-ecs](./community/aws-ecs) | `.github/community-skills/aws-ecs/` |
| [aws-eks](./community/aws-eks) | `.github/community-skills/aws-eks/` |
| [aws-eventbridge](./community/aws-eventbridge) | `.github/community-skills/aws-eventbridge/` |
| [aws-iam](./community/aws-iam) | `.github/community-skills/aws-iam/` |
| [aws-lambda](./community/aws-lambda) | `.github/community-skills/aws-lambda/` |
| [aws-naming-research](./community/aws-naming-research) | `.github/community-skills/aws-naming-research/` |
| [aws-rds](./community/aws-rds) | `.github/community-skills/aws-rds/` |
| [aws-s3](./community/aws-s3) | `.github/community-skills/aws-s3/` |
| [aws-secrets-manager](./community/aws-secrets-manager) | `.github/community-skills/aws-secrets-manager/` |
| [aws-security-analyzer](./community/aws-security-analyzer) | `.github/community-skills/aws-security-analyzer/` |
| [aws-sns](./community/aws-sns) | `.github/community-skills/aws-sns/` |
| [aws-sqs](./community/aws-sqs) | `.github/community-skills/aws-sqs/` |
| [aws-step-functions](./community/aws-step-functions) | `.github/community-skills/aws-step-functions/` |


## Preview and install

Use the helper in `.github/skills/git-ape-skills/scripts/skills.js`:

```text
node skills.js plan-pack <name> --workspace <directory> [--revision <full-sha>]
node skills.js install-pack <name> --workspace <directory> --revision <approved-full-sha> --yes

node skills.js plan-pack <name> --scope personal [--revision <full-sha>]
node skills.js install-pack <name> --scope personal --revision <approved-full-sha> --yes
```

Ask **"This project only" vs "All my projects"** before asking for a project folder.
For this project, resolve the current workspace if possible and ask for a folder only when needed.
Workspace scope (the CLI default, or `--scope workspace`) requires an existing `--workspace` and resolves
`<workspace>/.github/skills/`. Personal scope resolves `os.homedir()/.copilot/skills/` automatically,
requires no project or raw path question, and rejects `--workspace`.
Invalid scopes and ambiguous combinations fail before network access or writes.

Preview resolves one Azure/git-ape commit and lists scope, exact member files, destinations, and conflicts without writes,
even if the personal root does not yet exist.
The pinned source manifest must validate and match the registry.
Approve that full commit SHA, complete member list, files, scope, and resolved destination before installation using the same scope options. Installation repeats validation,
downloads and verifies every file before any final copy, never overwrites, and records pack membership in each
member's `.git-ape-provenance.json`. Failures roll back only newly created member directories and report cleanup errors.
Scripts and dependencies are never executed. Both scopes install file-based skills, not a global plugin or App sidebar groups.
Discovery depends on client support; reload or start a new session and verify discovery before claiming skills are active.
Older registries without a `packs` array remain supported.

To contribute, copy [the pack scaffold](https://github.com/Azure/git-ape/blob/main/.github/templates/SKILL_PACK.template.json),
then follow [CONTRIBUTING.md](https://github.com/Azure/git-ape/blob/main/CONTRIBUTING.md#contributing-a-community-pack).
