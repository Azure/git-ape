---
title: "PR Validation"
sidebar_label: "PR Validation"
description: "GitHub Actions workflow: PR Validation"
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/workflows/pr-validation.yml -->


# PR Validation

**Workflow file:** `.github/workflows/pr-validation.yml`

## Triggers

- **`pull_request`** — branches: `["main"]`


## Permissions

- `contents: read`

## Jobs

### `structure-check`

| Property | Value |
|----------|-------|
| **Display Name** | Structural Validation |
| **Runs On** | `ubuntu-latest` |
| **Steps** | 5 |

### `markdownlint`

| Property | Value |
|----------|-------|
| **Display Name** | Markdown Lint |
| **Runs On** | `ubuntu-latest` |
| **Steps** | 4 |



## Source

<details>
<summary>Click to view full workflow YAML</summary>

```yaml
name: "PR Validation"

on:
  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  structure-check:
    name: "Structural Validation"
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1

      - name: Setup Node.js
        uses: actions/setup-node@820762786026740c76f36085b0efc47a31fe5020 # v7.0.0
        with:
          node-version: '24'
          cache: 'npm'
          cache-dependency-path: website/package-lock.json

      - name: Install dependencies
        working-directory: website
        run: npm ci

      - name: Run structural validation
        run: node scripts/validate-structure.js

      - name: Test skill discovery and opt-in installation
        run: node --test scripts/tests/skill-discovery.test.js

  markdownlint:
    name: "Markdown Lint"
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1

      - name: Setup Node.js
        uses: actions/setup-node@820762786026740c76f36085b0efc47a31fe5020 # v7.0.0
        with:
          node-version: '20'

      - name: Install markdownlint-cli
        run: npm install -g markdownlint-cli@0.41.0

      - name: Run markdownlint
        run: |
          markdownlint '**/*.md' \
            --ignore 'website/node_modules/**' \
            --ignore 'website/build/**' \
            --ignore 'website/docs/**' \
            --config .markdownlint.json

```

</details>
