---
title: "Git-Ape: Plugin Release"
sidebar_label: "Plugin Release"
description: "GitHub Actions workflow: Git-Ape: Plugin Release"
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/workflows/git-ape-release.yml -->


# Git-Ape: Plugin Release

**Workflow file:** `.github/workflows/git-ape-release.yml`

## Triggers

- **`push`**
- **`workflow_dispatch`**


## Permissions

- `contents: write`
- `pull-requests: write`

## Jobs

### `release`

| Property | Value |
|----------|-------|
| **Display Name** | release |
| **Runs On** | `ubuntu-latest` |
| **Steps** | 13 |



## Source

<details>
<summary>Click to view full workflow YAML</summary>

```yaml
name: "Git-Ape: Plugin Release"

on:
  push:
    tags:
      - 'v*.*.*'
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to release (without leading v, e.g. 0.1.0). Will create tag v<version>.'
        required: true
        type: string

permissions:
  contents: write
  pull-requests: write

# Prevent overlapping release runs that could push conflicting tags or commits.
# Different tags/versions still queue rather than cancel — we never want to
# abandon a release mid-flight.
concurrency:
  group: git-ape-release-${{ github.ref }}
  cancel-in-progress: false

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v6
        with:
          fetch-depth: 0
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Resolve target version
        id: ver
        run: |
          set -euo pipefail
          if [[ "${{ github.event_name }}" == "workflow_dispatch" ]]; then
            VERSION="${{ inputs.version }}"
          else
            # Tag push: github.ref = refs/tags/vX.Y.Z
            VERSION="${GITHUB_REF#refs/tags/v}"
          fi
          if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
            echo "❌ '$VERSION' is not valid semver"
            exit 1
          fi
          echo "version=$VERSION" >> "$GITHUB_OUTPUT"
          echo "tag=v$VERSION" >> "$GITHUB_OUTPUT"

          # Mark as prerelease if semver has a pre-release suffix (e.g. 0.1.0-rc.1).
          if [[ "$VERSION" == *-* ]]; then
            echo "prerelease=true" >> "$GITHUB_OUTPUT"
          else
            echo "prerelease=false" >> "$GITHUB_OUTPUT"
          fi
          echo "Resolved version: $VERSION (tag: v$VERSION)"

      - name: Validate release commit is on main history
        run: |
          set -euo pipefail
          # Runs for both push (tag already exists) and workflow_dispatch (tag
          # created later in this job). Guarding here — before any tag is
          # created or pushed — ensures a manual release cannot publish from a
          # commit that is not reachable from main.
          git fetch origin main
          if ! git merge-base --is-ancestor "$GITHUB_SHA" origin/main; then
            echo "❌ Release commit $GITHUB_SHA is not reachable from origin/main."
            echo "Create releases from commits already merged to main."
            exit 1
          fi
          echo "✅ Release commit is reachable from origin/main."

      - name: Validate release version invariant
        env:
          VERSION: ${{ steps.ver.outputs.version }}
        run: |
          set -euo pipefail

          PLUGIN_JSON="plugin.json"
          MARKETPLACE_JSON=".github/plugin/marketplace.json"
          PLUGIN_NAME=$(jq -r '.name' "$PLUGIN_JSON")

          PLUGIN_VERSION=$(jq -r '.version' "$PLUGIN_JSON")
          MKT_METADATA_VERSION=$(jq -r '.metadata.version' "$MARKETPLACE_JSON")
          MKT_ENTRY_VERSION=$(jq -r --arg name "$PLUGIN_NAME" \
            '.plugins[] | select(.name == $name) | .version' "$MARKETPLACE_JSON")

          echo "Current versions at release commit:"
          echo "  plugin.json:        $PLUGIN_VERSION"
          echo "  marketplace.meta:   $MKT_METADATA_VERSION"
          echo "  marketplace.entry:  $MKT_ENTRY_VERSION"
          echo "Target version:       $VERSION"

          ERRORS=0

          if [[ "$PLUGIN_VERSION" != "$VERSION" ]]; then
            echo "❌ plugin.json version ($PLUGIN_VERSION) does not match release version ($VERSION)"
            ERRORS=$((ERRORS + 1))
          fi

          if [[ "$MKT_ENTRY_VERSION" != "$VERSION" ]]; then
            echo "❌ marketplace plugin entry version ($MKT_ENTRY_VERSION) does not match release version ($VERSION)"
            ERRORS=$((ERRORS + 1))
          fi

          if [[ "$MKT_METADATA_VERSION" != "$VERSION" ]]; then
            echo "❌ marketplace metadata.version ($MKT_METADATA_VERSION) does not match release version ($VERSION)"
            ERRORS=$((ERRORS + 1))
          fi

          if [[ "$ERRORS" -gt 0 ]]; then
            echo
            echo "Release invariant failed: tag v$VERSION must point to a commit where version files are already synchronized."
            echo "Fix by merging a release PR that bumps plugin.json + .github/plugin/marketplace.json before tagging."
            exit 1
          fi

      - name: Ensure release tag exists (workflow_dispatch only)
        if: github.event_name == 'workflow_dispatch'
        env:
          TAG: ${{ steps.ver.outputs.tag }}
        run: |
          set -euo pipefail
          if git ls-remote --exit-code --tags origin "$TAG" >/dev/null 2>&1; then
            echo "Tag $TAG already exists on origin; reusing it."
            exit 0
          fi

          git tag -a "$TAG" -m "Release $TAG"
          git push origin "$TAG"

      - name: Generate release notes
        id: notes
        env:
          TAG: ${{ steps.ver.outputs.tag }}
        run: |
          set -euo pipefail

          # Use the tag as the tip of the range when it exists as a ref. On
          # workflow_dispatch with versions already aligned, the prior
          # "Commit version bump" step is skipped, so the tag does not yet
          # exist locally — fall back to HEAD so git log still walks the
          # right commits.
          if git rev-parse --verify "$TAG" >/dev/null 2>&1; then
            TIP="$TAG"
          else
            TIP="HEAD"
          fi

          PREV_TAG=$(git describe --tags --abbrev=0 "${TIP}^" 2>/dev/null || echo "")

          # Collect commits grouped by conventional-commit type
          if [[ -n "$PREV_TAG" ]]; then
            RANGE="${PREV_TAG}..${TIP}"
          else
            RANGE="$TIP"
          fi

          declare -A SECTIONS=(
            [feat]=""
            [fix]=""
            [docs]=""
            [ci]=""
            [chore]=""
            [refactor]=""
            [perf]=""
            [test]=""
            [other]=""
          )

          declare -A SECTION_TITLES=(
            [feat]="Features"
            [fix]="Bug Fixes"
            [docs]="Documentation"
            [ci]="CI/CD"
            [chore]="Chores"
            [refactor]="Refactoring"
            [perf]="Performance"
            [test]="Tests"
            [other]="Other Changes"
          )

          while IFS= read -r line; do
            hash="${line%% *}"
            msg="${line#* }"

            # Parse conventional commit: type(scope): description  OR  type: description
            if [[ "$msg" =~ ^([a-zA-Z]+)(\(.*\))?!?:\ (.+)$ ]]; then
              type="${BASH_REMATCH[1],,}"  # lowercase
              scope="${BASH_REMATCH[2]}"
              desc="${BASH_REMATCH[3]}"
              scope="${scope#(}"
              scope="${scope%)}"

              if [[ -z "${SECTIONS[$type]+_}" ]]; then
                type="other"
              fi

              if [[ -n "$scope" ]]; then
                SECTIONS[$type]+="- **${scope}:** ${desc} (\`${hash}\`)"$'\n'
              else
                SECTIONS[$type]+="- ${desc} (\`${hash}\`)"$'\n'
              fi
            else
              SECTIONS[other]+="- ${msg} (\`${hash}\`)"$'\n'
            fi
          done < <(git log --pretty=format:'%h %s' "$RANGE" | head -200)

          # Build the release notes file
          {
            echo "## Git-Ape $TAG"
            echo
            if [[ -n "$PREV_TAG" ]]; then
              echo "Changes since [$PREV_TAG](https://github.com/${{ github.repository }}/releases/tag/$PREV_TAG):"
            else
              echo "Initial tagged release."
            fi
            echo

            # Emit sections in display order
            for type in feat fix perf refactor docs ci test chore other; do
              if [[ -n "${SECTIONS[$type]}" ]]; then
                echo "### ${SECTION_TITLES[$type]}"
                echo
                echo -n "${SECTIONS[$type]}"
                echo
              fi
            done

            echo "## Install"
            echo
            echo '### VS Code'
            echo
            echo '```jsonc'
            echo '"chat.plugins.marketplaces": ["Azure/git-ape"]'
            echo '```'
            echo
            # shellcheck disable=SC2016
            echo 'Then install **git-ape** from the `@agentPlugins` Extensions view.'
            echo
            echo '### Copilot CLI'
            echo
            echo '```bash'
            echo 'copilot plugin marketplace add Azure/git-ape'
            echo 'copilot plugin install git-ape@git-ape'
            echo '```'
          } > release-notes.md

          {
            echo 'notes<<EOF'
            cat release-notes.md
            echo 'EOF'
          } >> "$GITHUB_OUTPUT"

      - name: Setup Node.js
        uses: actions/setup-node@v6
        with:
          node-version: '22'

      - name: Install vsce
        run: npm install -g @vscode/vsce

      - name: Assemble extension payload
        env:
          VERSION: ${{ steps.ver.outputs.version }}
        run: |
          set -euo pipefail
          cp LICENSE extension/
          cp APE.png extension/
          cp -r .github extension/.github

          # Copy template and stamp the release version
          jq --arg v "$VERSION" '.version = $v' extension/package.template.json > extension/package.json

      - name: Package VSIX
        working-directory: extension
        run: |
          set -euo pipefail
          vsce package --no-dependencies --allow-missing-repository
          echo "VSIX packaged:"
          ls -lh ./*.vsix

      - name: Create GitHub release
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          TAG: ${{ steps.ver.outputs.tag }}
          PRERELEASE: ${{ steps.ver.outputs.prerelease }}
        run: |
          set -euo pipefail
          PRERELEASE_FLAG=""
          if [[ "$PRERELEASE" == "true" ]]; then
            PRERELEASE_FLAG="--prerelease"
            echo "Marking $TAG as a prerelease."
          fi

          if gh release view "$TAG" >/dev/null 2>&1; then
            echo "Release $TAG already exists; updating notes."
            # shellcheck disable=SC2086
            gh release edit "$TAG" --notes-file release-notes.md $PRERELEASE_FLAG
          else
            # shellcheck disable=SC2086
            gh release create "$TAG" \
              --title "Git-Ape $TAG" \
              --notes-file release-notes.md \
              $PRERELEASE_FLAG
          fi

      - name: Upload VSIX to release
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          TAG: ${{ steps.ver.outputs.tag }}
        run: |
          set -euo pipefail
          VSIX_FILE=$(ls ./extension/*.vsix)
          echo "Uploading $VSIX_FILE to release $TAG"
          gh release upload "$TAG" "$VSIX_FILE" --clobber

      - name: Publish to VS Code Marketplace
        working-directory: extension
        env:
          VSCE_PAT: ${{ secrets.VSCE_PAT }}
          VERSION: ${{ steps.ver.outputs.version }}
        run: |
          set -euo pipefail
          if [[ -z "${VSCE_PAT:-}" ]]; then
            echo "VSCE_PAT secret not set; skipping marketplace publish."
            exit 0
          fi

          # VS Code Marketplace rejects semver pre-release suffixes
          # (e.g. 0.1.0-rc.1). We publish every release as a stable
          # marketplace release regardless of minor parity — the odd/even
          # minor convention is opt-in and would require packaging the VSIX
          # with --pre-release to match, which we don't do here.
          if [[ "$VERSION" == *-* ]]; then
            echo "Version $VERSION carries a semver pre-release suffix, which the"
            echo "VS Code Marketplace does not accept. Skipping marketplace publish."
            exit 0
          fi

          VSIX_FILE=$(ls ./*.vsix)
          echo "Publishing $VSIX_FILE to VS Code Marketplace (Release channel)"
          vsce publish --packagePath "$VSIX_FILE" --no-dependencies

```

</details>
