---
title: "Git-Ape: Docs Check"
sidebar_label: "Docs Check"
description: "GitHub Actions workflow: Git-Ape: Docs Check"
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/workflows/git-ape-docs-check.yml -->


# Git-Ape: Docs Check

**Workflow file:** `.github/workflows/git-ape-docs-check.yml`

## Triggers

- **`pull_request`** — paths: `.github/agents/**, .github/skills/**, .github/workflows/git-ape-plan.yml...`


## Permissions

- `contents: read`
- `pull-requests: write`

## Jobs

### `check-docs`

| Property | Value |
|----------|-------|
| **Display Name** | check-docs |
| **Runs On** | `ubuntu-latest` |
| **Steps** | 6 |



## Source

<details>
<summary>Click to view full workflow YAML</summary>

```yaml
name: "Git-Ape: Docs Check"

on:
  pull_request:
    paths:
      - '.github/agents/**'
      - '.github/skills/**'
      - '.github/workflows/git-ape-plan.yml'
      - '.github/workflows/git-ape-deploy.yml'
      - '.github/workflows/git-ape-destroy.yml'
      - '.github/workflows/git-ape-verify.yml'
      - '.github/plugin/**'
      - 'plugin.json'

permissions:
  contents: read
  pull-requests: write

jobs:
  check-docs:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: website/package-lock.json

      - name: Install dependencies
        working-directory: website
        run: npm ci

      - name: Generate docs from source
        run: node scripts/generate-docs.js

      - name: Check for stale docs
        id: diff
        run: |
          if git diff --quiet website/docs/; then
            echo "stale=false" >> "$GITHUB_OUTPUT"
            echo "✅ Generated docs are up to date"
          else
            echo "stale=true" >> "$GITHUB_OUTPUT"
            echo "⚠️ Generated docs are stale"
            echo ""
            echo "Changed files:"
            git diff --name-only website/docs/
          fi

      - name: Comment on PR if stale
        if: steps.diff.outputs.stale == 'true'
        uses: actions/github-script@v7
        with:
          script: |
            const { execSync } = require('child_process');
            const changedFiles = execSync('git diff --name-only website/docs/')
              .toString()
              .trim()
              .split('\n')
              .map(f => `- \`${f}\``)
              .join('\n');

            const body = `## ⚠️ Documentation Staleness Warning

            Source files (agents, skills, workflows, or config) changed in this PR, but the generated documentation is out of date.

            **Changed docs that need regeneration:**
            ${changedFiles}

            **To fix:** Run the following command and commit the results:
            \`\`\`bash
            node scripts/generate-docs.js
            \`\`\`

            > This is an advisory check — it does not block the PR.
            `.replace(/^            /gm, '');

            // Find existing comment to update
            const { data: comments } = await github.rest.issues.listComments({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
            });

            const marker = '## ⚠️ Documentation Staleness Warning';
            const existing = comments.find(c => c.body?.includes(marker));

            if (existing) {
              await github.rest.issues.updateComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                comment_id: existing.id,
                body,
              });
            } else {
              await github.rest.issues.createComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.issue.number,
                body,
              });
            }

```

</details>
