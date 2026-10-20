# Contributing to Git-Ape

Thank you for your interest in contributing to Git-Ape! This document provides guidelines and instructions for contributing.

## Code of Conduct

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Contribution Model

- **Skills** are community-contributable via Pull Request, either as core skills (`.github/skills/<name>/`) or opt-in **community skills** (`.github/community-skills/<name>/`) — see [Contributing a Community Skill](#contributing-a-community-skill).
- **Agents** are maintainer-curated. To propose agent changes, open a Discussion first.

## Adding a New Skill

### Directory Structure

First-party skills live in their own directories under `.github/skills/`.
For community contributions, use the [community skill template and source
layout](#contributing-a-community-skill) instead; the schema and naming rules
below apply to both tiers.

```
.github/skills/
└── your-skill-name/
    └── SKILL.md
```

### Naming Conventions

- Directory names **must** use kebab-case (e.g., `azure-cost-estimator`, `prereq-check`).
- The `name` field in SKILL.md frontmatter **must** match the directory name exactly.

### SKILL.md Schema

Every SKILL.md file must have YAML frontmatter with the following fields:

```yaml
---
name: your-skill-name          # Required. Must match directory name.
description: "Short description of what this skill does."  # Required.
argument-hint: "Usage hint"    # Optional. Shown in autocomplete.
user-invocable: true           # Optional. Defaults to true.
---
```

### Required Sections

After the frontmatter, the skill body **must** include these sections:

- `## When to Use` — Describes the scenarios where this skill should be invoked.
- `## Procedure` — Step-by-step instructions the agent follows when executing the skill.
  Equivalent headings (`## Execution Playbook`, `## Command Playbook`) are also accepted.

### Example

```markdown
---
name: my-new-skill
description: "Does something useful for Azure deployments."
user-invocable: true
---

# My New Skill

Brief overview of the skill.

## When to Use

- When the user asks for X
- During Y phase of deployment

## Procedure

1. Step one
2. Step two
3. Step three
```

## Contributing a Community Pack

Packs collect independent community skills for explicit project or personal installation.
They are not merged skills, dependencies, global plugin installs, or client UI groups.

1. Copy `.github/templates/SKILL_PACK.template.json` to
   `.github/skill-packs/<name>/pack.json`.
2. Supply exactly `name`, `description`, `author`, and `skills`. The name must
   match its directory, be portable lowercase kebab-case (at most 100 characters),
   and not be a Windows reserved device name. Description and author must be
   non-empty strings without control characters.
3. List every member explicitly by its existing community skill name in `skills`.
   Empty lists, duplicates, missing members, and first-party members are rejected.
   Packs may share members; installation never overwrites an already installed skill.
   No wildcard expansion or nested packs are supported.
4. Run `node --test scripts/tests/*.test.js` and `node scripts/generate-docs.js`.
   Commit the generated `.github/skills/registry.json` and changed website docs
   with the manifest. The generator validates manifests and creates the pack catalog.
5. Choose "This project only" (`--scope workspace --workspace <directory>`) or
   "All my projects" (`--scope personal`, no project/path question). Review using
   `plan-pack <name> <scope-options>` in the `git-ape-skills` helper.
   Explicitly approve the pinned commit, full member list, files, scope,
   and resolved destination before `install-pack <name> <same-scope-options>
   --revision <approved-full-sha> --yes`. Installation copies all supporting files,
   records pack membership per member, and never runs community code.

## Contributing a Community Skill

Git-Ape maintains a **skill registry** so third parties can build and ship
skills within the Git-Ape framework without needing to be a maintainer.
Community skills live in their own subdirectory and are picked up
automatically by the generated registry (`.github/skills/registry.json`
and the [Skill Registry](https://azure.github.io/git-ape/docs/skills/registry)
docs page) — no separate registration step is required.

### Where they live

```
.github/community-skills/
└── your-skill-name/
    └── SKILL.md
```

Same rules as first-party skills apply: kebab-case directory name, `name:`
frontmatter matching the directory exactly, and the required
`## When to Use` / `## Procedure` sections.

### Additional required frontmatter

Community skills must also set `metadata.author` so users know who built and
maintains the skill:

```yaml
---
name: your-skill-name
description: "Short description of what this skill does."
license: MIT
metadata:
  author: your-github-handle       # Required. Who maintains this skill.
  source: https://github.com/you/your-repo   # Optional. Canonical home, if not here.
  maturity: experimental           # Optional. experimental (default) | stable
  version: "1.0.0"                 # Optional.
---
```

### Required authoring template

New community skills **must** start from
[`.github/templates/COMMUNITY_SKILL.template.md`](.github/templates/COMMUNITY_SKILL.template.md),
not the first-party `SKILL.template.md`.

1. Copy the template to `.github/community-skills/<name>/SKILL.md`, using a
   kebab-case directory name that exactly matches the skill's `name` field.
2. Replace the scaffold's `title`/`description` frontmatter with the real skill
   frontmatter shown in the template. Set `metadata.author` and remove the
   template instruction block and every `TODO` placeholder.
3. Complete the `When to Use`, `Procedure`, `Outputs`, `Constraints`, and
   `Attribution` sections. Keep attribution consistent with `metadata.author`
   and the optional `metadata.source`, and identify where to request support.
4. Keep any supporting `scripts/` and `references/` inside the skill's own
   directory so explicit installation can copy the complete skill.

`.github/community-skills/<name>/SKILL.md` is the authoring source of truth.
Do not author community contributions in `.github/skills/` (the core and
installed-skill loader path) or `website/docs/skills/community/` (generated
documentation). Follow the template for new skills and use it as the checklist
when updating existing community skills.

### Review bar

Community skills go through **the same process as first-party skills**:
maintainer review plus the full PR validation suite (`validate-structure.js`,
markdownlint, and Script Lint if the skill ships shell/PowerShell scripts).
The only functional differences are the directory location and the required
`metadata.author` field, which CI enforces — a community `SKILL.md` missing
`metadata.author` fails structural validation.

Community skills are clearly labeled as **third-party, not maintained by the
Git-Ape team** wherever they're listed (registry, docs pages), so users can
make an informed choice about trusting them.

### Discovery and explicit project or personal installation

Community sources remain in Azure/git-ape and are reviewed through repository
PRs. Review provides oversight and provenance, not a guarantee of safety.
The source directory is outside core's `.github/skills/` loader path and
excluded from the VSIX; core ships only community registry metadata.

Use `/git-ape-skills search <capability>` to search the unified registry.
Search reads local registry metadata, not installed status, and does not activate
or install anything. To install a selected skill, use
`/git-ape-skills install <name>` and approve the pinned Azure/git-ape commit and
resolved destination. Ask "This project only" vs "All my projects" before asking
for a project folder. Resolve the current project when possible; ask for a folder
only when needed for workspace scope. The bundled Node.js helper uses authenticated
`gh` to download the complete skill directory into
`<workspace>/.github/skills/<name>/` (`--scope workspace --workspace <directory>`)
or `os.homedir()/.copilot/skills/<name>/` (`--scope personal`, no `--workspace`), preserving
scripts and references. It refuses overwrites, does not run skill scripts, and
writes `.git-ape-provenance.json`. Use `plan <name> <scope-options>` to preview a
single skill without writes, even if the personal root does not exist. Approve
its exact files, full commit SHA, scope, and resolved destination before
`install <name> <same-scope-options> --revision <approved-full-sha> --yes`.
CLI scope defaults to workspace and still requires an existing workspace;
invalid scope or personal combined with `--workspace` is rejected.
Both scopes install file-based skills, not a global plugin or App sidebar group.
Personal discovery depends on client support; reload or start a new session and
verify discovery before claiming the skill is active.
External `metadata.source` URLs provide attribution only, never install sources.
Dependencies on files outside a community skill's directory are not supported.

## Proposing Agent Changes

Agents are **maintainer-curated** and not open for direct community contribution via PR.

To propose a change to an agent:

1. Open a [Discussion](https://github.com/Azure/git-ape/discussions) describing your proposed change.
2. Wait for maintainer feedback and approval.
3. If approved, a maintainer will either implement it or invite you to submit a PR.

Agent files live in `.github/agents/` and require:

- YAML frontmatter with `description` field.
- A `## Warning` section (experimental disclaimer).

## Adding an Eval Suite

Every skill and agent in this repo can have a companion behavioral eval
under `.github/evals/`. Evals are scored on PRs via the
[`waza-evals`](.github/workflows/waza-evals.yml) and
[`waza-agent-evals`](.github/workflows/waza-agent-evals.yml) workflows.

To scaffold an eval for an existing skill or agent, use the slash
commands in VS Code (Copilot Chat):

- `/skill-onboard skillName=<name>` — bootstraps `.github/evals/<name>/`
  and appends a `{ name, tier: expanded }` entry to `manifest.yaml`.
- `/agent-onboard agentName=<name>` — bootstraps
  `.github/evals/agents/<name>/`. No `manifest.yaml` edit (agent evals
  are auto-discovered).

The full lifecycle (`onboard` → `bench` → `improve` → `promote`) and the
authoring framework are documented under
[Authoring](https://azure.github.io/git-ape/docs/authoring/) on the docs
site. Decision rationale for the harness choice lives in
[`.github/evals/README.md`](.github/evals/README.md).

## Pull Request Process

### Required registry and documentation refresh

Every PR that adds, updates, renames, or removes a first-party or community
skill **must** run the generator from the repository root before submission:

```bash
node scripts/generate-docs.js
```

Install the website dependencies first if needed (see [Development Setup](#development-setup)).
Commit the regenerated `.github/skills/registry.json` and all changed generated
files under `website/docs/` in the same PR as the skill changes. This includes
community skill pages under `website/docs/skills/community/` and the skills
overview and registry pages. Do not edit generated files manually.

The registry powers `/git-ape-skills search`; adding a source `SKILL.md` alone
does not publish its metadata to search. If regeneration produces no changes,
state that in the PR description. The Docs Check workflow is advisory, but
the refresh and inclusion of changed outputs are required for skill PRs.

1. **Fork and branch** — Create a feature branch from `main`.
2. **Make your changes** — Follow the directory structure and naming conventions above.
3. **Run validation locally** (optional):

   ```bash
   node scripts/validate-structure.js
   ```

4. **Refresh generated outputs and submit a PR** — For every skill PR, complete
   the required refresh above and include its changed outputs. Fill in the PR
   template and describe your changes.
5. **CI checks run automatically** — The PR validation workflow verifies:
   - YAML frontmatter has required fields (`name`, `description` for skills; `description` for agents)
   - Community skills (`.github/community-skills/<name>/`) additionally require `metadata.author`
   - Skill `name` matches its parent directory name
   - All skill/agent directories use kebab-case
   - Every skill directory contains a `SKILL.md` file
   - Skills have `## When to Use` and `## Procedure` sections
   - Agents have a `## Warning` disclaimer section
   - Cross-references (slash-commands `/skill-name`) map to existing skill directories
   - Relative markdown links resolve to real file paths
   - Markdown passes linting (markdownlint)

   If your PR touches a skill's shell or PowerShell scripts, the separate
   **Script Lint** workflow (`git-ape-script-lint.yml`) also runs:
   - Shell scripts (`.sh`) must pass `shellcheck` (severity ≥ warning) and `bash -n`
   - PowerShell scripts (`.ps1`) must pass `PSScriptAnalyzer` (Error/Warning, per
     [`.github/linters/PSScriptAnalyzerSettings.psd1`](.github/linters/PSScriptAnalyzerSettings.psd1))
     and the PowerShell language parser
6. **Review** — Maintainers will review your PR and provide feedback.

## Development Setup

```bash
# Clone the repository
git clone https://github.com/Azure/git-ape.git
cd git-ape

# Install website dependencies (needed for validation script)
cd website && npm ci && cd ..

# Run structural validation
node scripts/validate-structure.js

# Regenerate registry and documentation (required for every skill PR)
node scripts/generate-docs.js
```

If you edit a skill's embedded scripts, reproduce the **Script Lint** checks
locally before pushing:

```bash
# Shell: static analysis + syntax (needs shellcheck + bash)
find .github/skills -name '*.sh' -print0 | xargs -0 shellcheck --severity=warning
find .github/skills -name '*.sh' -exec bash -n {} \;

# PowerShell: static analysis + parser (needs pwsh + PSScriptAnalyzer)
pwsh -NoProfile -Command "Install-Module PSScriptAnalyzer -Scope CurrentUser -Force"
pwsh -NoProfile -Command "Get-ChildItem -Recurse .github/skills -Filter *.ps1 |
  ForEach-Object { Invoke-ScriptAnalyzer -Path \$_.FullName -Settings .github/linters/PSScriptAnalyzerSettings.psd1 }"
```

## Reporting Issues

Please use [GitHub Issues](https://github.com/Azure/git-ape/issues) to report bugs or request features.

## License

By contributing to this project, you agree that your contributions will be licensed under the [MIT License](LICENSE).
