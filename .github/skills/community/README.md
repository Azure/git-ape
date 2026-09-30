# Community Skills

This directory is the **third-party skill registry** for Git-Ape. Anyone can
contribute a skill here via pull request — you do not need to be a
maintainer, and you do not need prior approval to open the PR.

Community skills are **not** maintained by the Git-Ape team. Each skill must
declare its own author (and, ideally, a source repository) so users know who
to contact and where the canonical version lives.

## How this differs from `.github/skills/<name>/`

| | First-party (`.github/skills/<name>/`) | Community (`.github/skills/community/<name>/`) |
|---|---|---|
| Maintained by | Git-Ape team | The contributor / their org |
| Required frontmatter | `name`, `description` | `name`, `description`, **`metadata.author`** |
| Review bar | Maintainer review + full CI (structure, script lint, markdownlint) | **Same** — maintainer review + full CI |
| Listed in | [Skill Registry](https://azure.github.io/git-ape/docs/skills/registry) as `first-party` | [Skill Registry](https://azure.github.io/git-ape/docs/skills/registry) as `community` |

## Adding a skill here

See [`CONTRIBUTING.md`](../../../CONTRIBUTING.md#contributing-a-community-skill)
for the full process. In short:

1. Copy [`.github/templates/COMMUNITY_SKILL.template.md`](../../templates/COMMUNITY_SKILL.template.md)
   to `.github/skills/community/<your-skill-slug>/SKILL.md`.
2. Fill in `metadata.author` (required) and, if you maintain the skill
   elsewhere, `metadata.source`.
3. Open a PR. It goes through the same review and CI checks as any
   first-party skill.
4. Once merged, `node scripts/generate-docs.js` picks it up automatically —
   it appears in `.github/skills/registry.json` and the
   [Skill Registry](https://azure.github.io/git-ape/docs/skills/registry) docs
   page with no further registration step.
