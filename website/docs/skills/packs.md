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

_No packs have been contributed yet._

## Preview and install

Use the helper in `.github/skills/git-ape-skills/scripts/skills.js`:

```text
node skills.js plan-pack <name> --workspace <directory> [--revision <full-sha>]
node skills.js install-pack <name> --workspace <directory> --revision <approved-full-sha> --yes
```

Preview resolves one Azure/git-ape commit and lists exact member files, destinations, and conflicts without writes.
The pinned source manifest must validate and match the registry.
Approve that commit, complete member list, and destination before installation. Installation repeats validation,
downloads and verifies every file before any final copy, never overwrites, and records pack membership in each
member's `.git-ape-provenance.json`. Failures roll back only newly created member directories and report cleanup errors.
Scripts and dependencies are never executed. Installation is workspace-only; reload or start a new session to discover skills.
Older registries without a `packs` array remain supported.

To contribute, copy [the pack scaffold](https://github.com/Azure/git-ape/blob/main/.github/templates/SKILL_PACK.template.json),
then follow [CONTRIBUTING.md](https://github.com/Azure/git-ape/blob/main/CONTRIBUTING.md#contributing-a-community-pack).
