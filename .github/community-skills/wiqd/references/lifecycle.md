# WIQD lifecycle reference

Documentation reviewed: 2026-11-10. Documentation baseline: WIQD public preview
0.25.0. Local scaffolding, source checks and offline preview packaging were
smoke-tested with that version. Tenant operations were not tested.
Verify installed help before using these patterns; preview interfaces can change.

## Authoritative sources

| Source | Use |
|---|---|
| [Build a plugin](https://microsoft.github.io/wiqd/getting-started/build-a-plugin/) | Composition, lifecycle, scope and identity prerequisites |
| [CLI reference](https://microsoft.github.io/wiqd/cli/reference/#wiqd-plugin) | Installed command comparison and flags |
| [Authentication](https://microsoft.github.io/wiqd/getting-started/authentication/) | Independent providers, tenant checks and real-terminal login |
| [Installation](https://microsoft.github.io/wiqd/getting-started/installation/) | User-controlled CLI installation |
| [Plugin authoring reference](https://microsoft.github.io/wiqd/getting-started/plugin-reference/) | Manifest versions and component constraints |
| [Preview schema](https://developer.microsoft.com/en-us/json-schemas/teams/vDevPreview/MicrosoftTeams.schema.json) | Canonical preview manifest schema |
| [Changelog](https://microsoft.github.io/wiqd/project/changelog/) | Preview changes and compatibility investigation |

Use these official pages and installed help, not remembered schemas.
If a page cannot be fetched, state the freshness limitation. Do not infer
unsupported flags or sensitive-operation semantics from stale examples.

## Command patterns

Examples use a hypothetical `dev` environment; it is not a default to apply.
Each line is an independent operation, not an instruction to run the full list.
Run within the resolved project or use a verified explicit path option.
Replace example names and paths with separately quoted user-approved values.

```text
wiqd --version
wiqd plugin --help
wiqd plugin validate --help
wiqd auth status

wiqd plugin create --name "Incident Triage"
wiqd plugin add skill --name "Triage Incidents"
wiqd plugin add agent
wiqd plugin add connector --name "Incident Tools" --description "Approved incident tools" --url "https://tools.example.com/mcp"

wiqd plugin validate --mode source --env dev
wiqd plugin provision --env dev
wiqd plugin package --env dev
wiqd plugin package --offline --path "<approved-preview-project>" --env local
wiqd plugin validate --mode package --env dev --package-file "<exact-built-zip>"
wiqd plugin share --env dev --scope users --email "<approved-recipient>"
wiqd plugin share --env dev --scope tenant
wiqd plugin publish --env dev
wiqd plugin show
wiqd plugin delete --env dev --yes
```

Only run deletion after separate destructive approval. Never run both sharing
examples unless both distinct access changes were requested and approved.
For multiple recipients, inspect installed help rather than guessing separators.
Authentication and upload permission remain prerequisites for package validation.

## Semantics that must not be conflated

### Validation

- Explicit `--mode source` is the offline choice. Bare `plugin validate`
  defaults to package validation, which uploads a ZIP.
- Source checks cover applicable saved declarative-agent diagnostics and basic
  readable-object guards for project/app manifests. They do not fully validate
  those schemas, plugin skills, root connectors or referenced OpenAPI content.
- A skill/connector-only plugin can have no declarative-agent source coverage.
  A declared but missing declarative agent is an error, not a skip.
- Package validation checks an existing ZIP through upstream Core/TDP. It does
  not build a ZIP or authenticate automatically. Select an exact ZIP.
- Marketplace validation adds policy/evidence checks; it is not Store approval.
- Old `static`, `deep` and `manifest` modes are rejected by this baseline.
  The detailed validation section is more specific than older homepage examples.
- A source change or rebuilt ZIP invalidates prior package-validation evidence.
- Runtime connector invocation and administrator acceptance are separate checks.

### Identity and scope

- Inspect the selected environment under its configured environment folder.
  Packaging can fail if `TEAMS_APP_ID` is absent, malformed or unresolved.
- Normal lifecycle order is source validation, approved provisioning, packaging,
  approved package upload validation, then separately approved delivery.
  Already provisioned environments may be reused after verification.
- `AGENT_SCOPE=shared` is required for sharing. Missing, duplicate, invalid
  or personal scope can produce `INVALID_AGENT_SCOPE`.
- `--scope users|tenant` selects the audience, not provisioning scope.
  There is no `plugin provision --scope shared` option.
- Provider authentication status does not prove all resource permissions.
  A login `--tenant` option is not a universal cross-provider tenant selector.

### Explicit offline preview packaging

Installed `wiqd plugin package --help` on 0.25.0 documents `--offline` for a
local-only devPreview skill/connector ZIP without provisioning or server
validation. This is a separate path from normal environment-bound packaging.

- Require explicit offline-preview intent and agreement to preview source
  changes; do not silently change a standard packaging request.
- The source manifest must have `"manifestVersion": "devPreview"` and
  `"$schema": "https://developer.microsoft.com/en-us/json-schemas/teams/vDevPreview/MicrosoftTeams.schema.json"`.
  Changing only one field is insufficient.
- Re-run source validation after changing the manifest, while acknowledging
  its limited coverage for skill/connector-only projects.
- The CLI persists a local package ID without provisioning. Do not populate
  `TEAMS_APP_ID` manually or treat the local ID as a tenant registration.
- In offline mode, `--env` labels output only. Inspect the returned
  `outputPath`, non-zero file size, ZIP entries and packaged manifest.
- Do not upload, provision, share or publish as a consequence of this command.
  Cowork/AVL acceptance and runtime behaviour remain unverified.

### Publication and deletion

- Inspect the selected YAML `publish:` lifecycle before running it.
  Project lifecycle actions can have additional effects.
- Tenant catalogue submission, direct sharing and public-store certification
  are different operations.
- Preserve publication IDs separately from provisioning IDs; do not assume
  a published identifier is the same as the current provisioned instance.
- Deletion removes the selected upstream target; verify what actually changed.
  Do not assume it also revokes all access, removes catalogue publications,
  deletes external connector services or destroys Azure infrastructure.

## Failure handling

| Evidence | Response |
|---|---|
| Executable missing | Block; link installation instructions; do not auto-install |
| EULA acceptance required | Hand off to the user in a real terminal; do not accept or bypass the gate |
| Provider signed out or tenant ambiguous | Block the tenant step; request user-owned authentication/selection |
| Non-zero exit | Report the code and sanitised error; stop dependent steps |
| Exit 0 but failure in payload or missing postcondition | Report failure or uncertainty; do not report verified completion |
| Existing deployment but provisioning request timed out | Inspect before retry; do not create a duplicate blindly |
| Invalid shared scope | Explain configuration; do not copy IDs or provision silently |
| Missing standard packaging identity | Block standard packaging; provisioning or offline preview requires its own explicit intent/approval |
| Offline package rejects a numbered manifest | Explain the preview prerequisite; change both version fields only with preview opt-in, then revalidate |
| ZIP validation rejection | Report actual findings; do not assume an upstream rollout issue |
| Earlier success followed by later failure | Report partial completion and remaining state; no automatic deletion |

The CLI reference documents exit `0` for success, `1` for user/upstream errors,
`2` for configuration/infrastructure errors, and `130` for cancellation.
Use returned evidence; do not classify every code `2` as expired credentials.
