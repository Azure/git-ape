# Git-Ape Onboarding Templates

This folder is the **canonical source** for the workflow files, deployment
standards, and enterprise-distribution layout that the `/git-ape-onboarding`
skill scaffolds into a user's repository.

> [!NOTE]
> This README is for **repository maintainers only**. It is not shown to users
> who run onboarding.

## How it works

The Git-Ape VS Code extension ships only the paths registered in `plugin.json`
(`.github/agents/` and `.github/skills/`). Files in this `templates/` folder
ride along inside the skill folder, so they are present on disk after the
extension installs.

When `/git-ape-onboarding` runs in a user's own repository, the playbook
resolves the skill's install directory and copies these template files into
the user's `.github/workflows/` and `.github/copilot-instructions.md`.

## Single source of truth

The files here are **canonical**.

**Workflow templates** (`workflows/*.yml`, `workflows/git-ape-drift.{md,lock.yml}`)
are **not mirrored** into this repository's `.github/workflows/`. They are
scaffolded only into a **user's repository** by `scaffold-repo.{sh,ps1}` during
onboarding. Git-Ape's own repo doesn't run these workflows.

**Enterprise distribution templates** (`github-private/**`) are likewise
**scaffold-only** — never mirrored into this repo. They are scaffolded into a
**`.github-private` repository** by `scaffold-enterprise.{sh,ps1}` when
onboarding runs in enterprise-distribution mode. See the "Mode: Enterprise
Distribution" section of `../SKILL.md`.

**`copilot-instructions.md`** is mirrored to this repository's
`.github/copilot-instructions.md` so that Copilot uses the same deployment
standards when assisting on the git-ape repo itself. The mirror is kept in sync by:

- `.github/skills/git-ape-onboarding/scripts/sync-templates.sh` — bash
  helper for macOS/Linux/WSL (`check`, `apply`, `diff`)
- `.github/skills/git-ape-onboarding/scripts/sync-templates.ps1` — PowerShell
  parity helper for Windows (same three subcommands, byte-identical results)
- `.github/workflows/git-ape-onboarding-template-check.yml` — CI gate that
  runs both helpers (Ubuntu and Windows runners) plus a recursive `diff -r`
  between bash and pwsh scaffold sandboxes; fails any PR whose
  `copilot-instructions.md` mirror diverges OR whose two scaffolders produce
  different output

**Editing workflow (copilot-instructions.md):**

1. Edit `.github/skills/git-ape-onboarding/templates/copilot-instructions.md`
2. Run **one** of:
   - `.github/skills/git-ape-onboarding/scripts/sync-templates.sh apply` (bash)
   - `pwsh .github/skills/git-ape-onboarding/scripts/sync-templates.ps1 apply` (PowerShell)
3. Commit both the canonical change and the mirror update in the same PR

**Editing workflow templates:** Edit the file under
`.github/skills/git-ape-onboarding/templates/workflows/` and commit. No mirror
update is needed because Git-Ape's own repo does not contain a mirror copy.

**Editing the helpers themselves:** if you change one of `sync-templates.{sh,ps1}`,
`scaffold-repo.{sh,ps1}`, or `scaffold-enterprise.{sh,ps1}`, edit the parity
sibling in the same PR. The `scaffold-parity-smoke` and
`scaffold-enterprise-parity-smoke` CI jobs recursively diff the output of each
scaffolder pair and will fail on any divergence.

## Scaffold behavior

The skill scaffolds files **into the user's working copy only**:

- No `git add`, `git commit`, `git push`, or PR creation
- Skip-with-notice on collision — never overwrites a pre-existing file
- Final summary lists `Created` and `Skipped` counts so the user can reconcile

## Contents

| Template | Destination in user repo | Purpose |
|----------|--------------------------|---------|
| `workflows/git-ape-plan.yml` | `.github/workflows/git-ape-plan.yml` | Validate template + what-if on PR |
| `workflows/git-ape-deploy.yml` | `.github/workflows/git-ape-deploy.yml` | Execute deployment on merge to main |
| `workflows/git-ape-destroy.yml` | `.github/workflows/git-ape-destroy.yml` | Tear down stack on `destroy-requested` |
| `workflows/git-ape-verify.yml` | `.github/workflows/git-ape-verify.yml` | Manual verify OIDC + RBAC + workflow presence |
| `workflows/git-ape-drift.md` | `.github/workflows/git-ape-drift.md` | Agentic drift workflow source (gh-aw) |
| `workflows/git-ape-drift.lock.yml` | `.github/workflows/git-ape-drift.lock.yml` | Compiled drift workflow (runnable as-is) |
| `copilot-instructions.md` | `.github/copilot-instructions.md` | Git-Ape deployment standards |
| `github-private/README.md` | `README.md` | Maintainer guide for the `.github-private` config repo |
| `github-private/.github/copilot/managed-settings.json` | `.github/copilot/managed-settings.json` | Enterprise plugin standards (auto-installs the `git-ape` plugin) |
| `github-private/agents/.gitkeep` | `agents/.gitkeep` | Placeholder for optional standalone custom agents |

The first seven rows are scaffolded into a **user's deployment repo** by
`scaffold-repo.{sh,ps1}`. The three `github-private/**` rows are scaffolded into a
separate **`.github-private` enterprise config repo** by
`scaffold-enterprise.{sh,ps1}` (the "Destination" column is relative to that
repo's root). See the "Mode: Enterprise Distribution" section of `../SKILL.md`.

## Regenerating the drift lock file

`git-ape-drift.lock.yml` is generated from `git-ape-drift.md` by:

```bash
gh aw compile
```

The sync script does **not** auto-run `gh aw compile`. If you edit
`git-ape-drift.md`, regenerate the lock file manually and commit both. The
template check workflow does not validate that the `.md` source produces the
`.lock.yml`.

### gh-aw lock file is repo-dependent (expected)

When a user runs `gh aw compile` in their own scaffolded repo, the resulting
`git-ape-drift.lock.yml` will **not** be byte-identical to the one we shipped.
Two known drift sources, both intentional:

1. **Cron scattering** — gh-aw uses repository identity to deterministically
   pick a cron slot, so the user's repo gets a different slot than ours.
2. **Action SHA re-resolution** — tags like `actions/github-script@v9` and
   `azure/login@v2` get re-pinned to the current HEAD at compile time.

The scaffolder ships a fully compiled lock file so users can run the workflow
without installing gh-aw. If they later edit the `.md` source and recompile,
both sources of drift are expected and acceptable.
