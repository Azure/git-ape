---
title: "Git-Ape: Docs Deploy"
sidebar_label: "Docs Deploy"
description: "GitHub Actions workflow: Git-Ape: Docs Deploy"
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/workflows/git-ape-docs.yml -->


# Git-Ape: Docs Deploy

**Workflow file:** `.github/workflows/git-ape-docs.yml`

## Triggers

- **`push`** — branches: `["main"]` — paths: `.github/agents/**, .github/skills/**, .github/workflows/**...`


## Permissions

- `contents: read`
- `pages: write`
- `id-token: write`

## Jobs

### `build`

| Property | Value |
|----------|-------|
| **Display Name** | build |
| **Runs On** | `ubuntu-latest` |
| **Steps** | 6 |

### `deploy`

| Property | Value |
|----------|-------|
| **Display Name** | deploy |
| **Runs On** | `ubuntu-latest` |
| **Environment** | `github-pages` |
| **Depends On** | `build` |
| **Steps** | 1 |



## Source

<details>
<summary>Click to view full workflow YAML</summary>

```yaml
name: "Git-Ape: Docs Deploy"

on:
  push:
    branches: [main]
    paths:
      - '.github/agents/**'
      - '.github/skills/**'
      - '.github/workflows/**'
      - '.github/plugin/**'
      - 'docs/**'
      - 'plugin.json'
      - 'website/**'
      - 'scripts/generate-docs.js'

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  build:
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

      - name: Build Docusaurus
        working-directory: website
        run: npm run build

      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: website/build

  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4

```

</details>
