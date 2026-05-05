# Contributing to Git-Ape

Thank you for your interest in contributing to Git-Ape! This document provides guidelines and instructions for contributing.

## Code of Conduct

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Contribution Model

- **Skills** are community-contributable via Pull Request.
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

## Proposing Agent Changes

Agents are **maintainer-curated** and not open for direct community contribution via PR.

To propose a change to an agent:

1. Open a [Discussion](https://github.com/Azure/git-ape/discussions) describing your proposed change.
2. Wait for maintainer feedback and approval.
3. If approved, a maintainer will either implement it or invite you to submit a PR.

Agent files live in `.github/agents/` and require:

- YAML frontmatter with `description` field.
- A `## Warning` section (experimental disclaimer).

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
   - Skill `name` matches its parent directory name
   - All skill/agent directories use kebab-case
   - Every skill directory contains a `SKILL.md` file
   - Skills have `## When to Use` and `## Procedure` sections
   - Agents have a `## Warning` disclaimer section
   - Cross-references (slash-commands `/skill-name`) map to existing skill directories
   - Relative markdown links resolve to real file paths
   - Markdown passes linting (markdownlint)
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

## Reporting Issues

Please use [GitHub Issues](https://github.com/Azure/git-ape/issues) to report bugs or request features.

## License

By contributing to this project, you agree that your contributions will be licensed under the [MIT License](LICENSE).
