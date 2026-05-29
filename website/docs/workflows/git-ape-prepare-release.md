---
title: "Git-Ape: Prepare Release PR"
sidebar_label: "Prepare Release PR"
description: "GitHub Actions workflow: Git-Ape: Prepare Release PR"
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/workflows/git-ape-prepare-release.yml -->


# Git-Ape: Prepare Release PR

**Workflow file:** `.github/workflows/git-ape-prepare-release.yml`

## Triggers

- **`workflow_dispatch`**


## Permissions

- `contents: write`
- `pull-requests: write`

## Jobs

### `prepare`

| Property | Value |
|----------|-------|
| **Display Name** | prepare |
| **Runs On** | `ubuntu-latest` |
| **Steps** | 4 |



## Source

<details>
<summary>Click to view full workflow YAML</summary>

```yaml
name: "Git-Ape: Prepare Release PR"

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to prepare (without leading v, e.g. 0.2.0)'
        required: true
        type: string

permissions:
  contents: write
  pull-requests: write

concurrency:
  group: git-ape-prepare-release-${{ github.ref }}-${{ inputs.version }}
  cancel-in-progress: false

jobs:
  prepare:
    runs-on: ubuntu-latest
    steps:
      - name: Resolve and validate version
        id: ver
        run: |
          set -euo pipefail
          VERSION="${{ inputs.version }}"
          if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
            echo "❌ '$VERSION' is not valid semver"
            exit 1
          fi
          echo "version=$VERSION" >> "$GITHUB_OUTPUT"
          echo "tag=v$VERSION" >> "$GITHUB_OUTPUT"
          echo "branch=release/v$VERSION" >> "$GITHUB_OUTPUT"

      - name: Checkout
        uses: actions/checkout@v6
        with:
          fetch-depth: 0
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Apply release version and changelog entry
        id: apply
        env:
          VERSION: ${{ steps.ver.outputs.version }}
          TAG: ${{ steps.ver.outputs.tag }}
          BRANCH: ${{ steps.ver.outputs.branch }}
        run: |
          set -euo pipefail

          git fetch origin main
          git checkout -B "$BRANCH" origin/main

          PLUGIN_JSON="plugin.json"
          MARKETPLACE_JSON=".github/plugin/marketplace.json"
          PLUGIN_NAME=$(jq -r '.name' "$PLUGIN_JSON")

          jq --arg v "$VERSION" '.version = $v' "$PLUGIN_JSON" > "$PLUGIN_JSON.tmp"
          mv "$PLUGIN_JSON.tmp" "$PLUGIN_JSON"

          jq --arg v "$VERSION" --arg name "$PLUGIN_NAME" '
            .metadata.version = $v
            | .plugins |= map(if .name == $name then .version = $v else . end)
          ' "$MARKETPLACE_JSON" > "$MARKETPLACE_JSON.tmp"
          mv "$MARKETPLACE_JSON.tmp" "$MARKETPLACE_JSON"

          DATE=$(date -u +%Y-%m-%d)
          ENTRY_HEADER="## [$VERSION] - $DATE"

          if [[ ! -f CHANGELOG.md ]]; then
            {
              echo "# Changelog"
              echo
              echo "All notable changes to this project are documented here."
              echo "This project follows [Semantic Versioning](https://semver.org/)."
              echo
            } > CHANGELOG.md
          fi

          if ! grep -Fq "$ENTRY_HEADER" CHANGELOG.md; then
            NEW_ENTRY=$(printf '%s\n\n- Release %s prepared. Final notes are generated during the release workflow.\n\n' "$ENTRY_HEADER" "$TAG")
            awk -v entry="$NEW_ENTRY" '
              BEGIN { inserted = 0 }
              {
                print
                if (!inserted && /^# /) {
                  print ""
                  print entry
                  inserted = 1
                }
              }
            ' CHANGELOG.md > CHANGELOG.md.tmp
            mv CHANGELOG.md.tmp CHANGELOG.md
          fi

          if git diff --quiet plugin.json .github/plugin/marketplace.json CHANGELOG.md; then
            echo "No release prep changes needed for $TAG."
            echo "changed=false" >> "$GITHUB_OUTPUT"
            exit 0
          fi

          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git add plugin.json .github/plugin/marketplace.json CHANGELOG.md
          git commit -m "chore(release): prepare $TAG"
          git push --force-with-lease origin "$BRANCH"
          echo "changed=true" >> "$GITHUB_OUTPUT"

      - name: Open or update release PR
        if: steps.apply.outputs.changed == 'true'
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          VERSION: ${{ steps.ver.outputs.version }}
          TAG: ${{ steps.ver.outputs.tag }}
          BRANCH: ${{ steps.ver.outputs.branch }}
        run: |
          set -euo pipefail

          EXISTING_PR=$(gh pr list \
            --base main \
            --head "$BRANCH" \
            --state open \
            --json number \
            --jq '.[0].number // empty')

          TITLE="chore(release): prepare $TAG"
          BODY=$(printf 'Prepare release **%s** by syncing:\n- `plugin.json`\n- `.github/plugin/marketplace.json`\n- `CHANGELOG.md`\n\nAfter this PR merges:\n1. Create tag `%s` on the merge commit.\n2. Let `Git-Ape: Plugin Release` publish artifacts and release notes.\n' "$TAG" "$TAG")

          if [[ -n "$EXISTING_PR" ]]; then
            gh pr edit "$EXISTING_PR" --title "$TITLE" --body "$BODY"
            echo "Updated existing PR #$EXISTING_PR"
          else
            gh pr create \
              --base main \
              --head "$BRANCH" \
              --title "$TITLE" \
              --body "$BODY"
          fi

```

</details>
