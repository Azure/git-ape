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

Each skill lives in its own directory under `.github/skills/`:

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

Start from [`.github/templates/COMMUNITY_SKILL.template.md`](.github/templates/COMMUNITY_SKILL.template.md)
rather than the first-party `SKILL.template.md` — it includes the required
`metadata.author` field and an `## Attribution` section.

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

### Discovery and explicit workspace installation

Community sources remain in Azure/git-ape and are reviewed through repository
PRs. Review provides oversight and provenance, not a guarantee of safety.
The source directory is outside core's `.github/skills/` loader path and
excluded from the VSIX; core ships only community registry metadata.

Use `/git-ape-skills search <capability>` to search the unified registry.
Search does not activate or install anything. To install a selected skill, use
`/git-ape-skills install <name>` and approve the pinned Azure/git-ape commit and
destination repository. The bundled Node.js helper uses authenticated `gh` to
download the complete skill directory into `.github/skills/<name>/`, preserving
scripts and references. It refuses overwrites, does not run skill scripts, and
writes `.git-ape-provenance.json`. A client reload or new session may be needed.
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

1. **Fork and branch** — Create a feature branch from `main`.
2. **Make your changes** — Follow the directory structure and naming conventions above.
3. **Run validation locally** (optional):

   ```bash
   node scripts/validate-structure.js
   ```

4. **Submit a PR** — Fill in the PR template and describe your changes.
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

# Generate documentation (optional)
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
