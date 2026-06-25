# Copilot enterprise configuration (`.github-private`)

This repository is the **single source of truth** for distributing GitHub Copilot
customizations to everyone on your enterprise's Copilot plan. It does two jobs:

1. **Enterprise-managed plugin standards** — auto-installs the **Git‑Ape plugin**
   (agents + skills + the `azure-mcp` MCP server) for every user, via
   [`.github/copilot/managed-settings.json`](.github/copilot/managed-settings.json).
2. **(Optional) Standalone custom agents** — single, self-contained agent profiles
   dropped into [`agents/`](agents/).

> [!IMPORTANT]
> This repo must be named exactly `.github-private` and be owned by an organization
> that an **enterprise owner has designated** under **Enterprise → AI controls**.
> Without that designation, none of the files here take effect at enterprise scope.

> [!NOTE]
> This file was scaffolded by the Git‑Ape onboarding skill (`/git-ape-onboarding`,
> enterprise mode). Edit it to fit your organization before publishing.

---

## How Git‑Ape is distributed (the recommended path)

Git‑Ape is a **plugin**, not a lone agent — it bundles agents, skills, and an MCP
server that only work together. So Git‑Ape is distributed as a whole plugin through
`managed-settings.json` rather than by copying individual agent files into `agents/`.

When a user authenticates from a supported client, Copilot reads
`managed-settings.json` and:

- registers the `Azure/git-ape` plugin marketplace, and
- auto-installs the `git-ape` plugin (agents **+** skills **+** MCP config).

```jsonc
// .github/copilot/managed-settings.json
{
  "extraKnownMarketplaces": {
    "git-ape": { "source": { "source": "github", "repo": "Azure/git-ape" } }
  },
  "enabledPlugins": {
    "git-ape@git-ape": true
  }
}
```

**Supported clients:** Copilot CLI and VS Code **1.122+**. Users on older clients
must upgrade before the standards apply. Users licensed by multiple billing entities
must select this enterprise under *"Usage billed to"* in their personal Copilot
settings.

### Optional: also ship the `ape-context` companion plugin

The `Azure/git-ape` marketplace also publishes the community `ape-context` plugin.
To auto-install it too, add it to `enabledPlugins`:

```json
"enabledPlugins": {
  "git-ape@git-ape": true,
  "ape-context@git-ape": true
}
```

---

## The `agents/` directory (standalone custom agents)

Org/enterprise **custom agents** are single Markdown profiles
(`agents/AGENT-NAME.md`, with `name` / `description` / prompt frontmatter) that
become available to all members.

> [!WARNING]
> **Do not copy Git‑Ape's agent files here.** Git‑Ape's agents call its skills and
> the `azure-mcp` server. The `agents/` route distributes **agents only** — the
> skills and MCP would be missing, so the agents would load but fail. Ship Git‑Ape
> through `managed-settings.json` (above) instead.

Use `agents/` only for your own self-contained agents that don't depend on bundled
skills or MCP servers.

> [!NOTE]
> **Standalone org/enterprise _skills_ are "coming soon."** Today, skills reach users
> two ways: bundled in a plugin (how Git‑Ape ships them — already covered above) or
> pulled per-user with `gh skill install`. There is not yet a `skills/` folder in
> `.github-private` that fans out the way `agents/` does.

---

## One-time admin setup

1. **Create this repo** from GitHub's
   [custom agents template](https://github.com/docs/custom-agents-template), owned by
   an org in your enterprise, named `.github-private`.
   - Visibility **Internal** = read access for all enterprise members.
   - Visibility **Private** = grant access manually.
2. **Designate the org:** Enterprise → **AI controls** → **Custom agents** →
   *Select organization* → choose the org that owns this repo. This same designation
   also points the enterprise at this repo's `managed-settings.json`.
3. **(Recommended) Protect the files:** in the same *AI controls* page, under
   *"Protect agent files using rulesets"*, click **Create ruleset** so only enterprise
   owners can merge changes to agent profiles.
4. **Commit `managed-settings.json` to the default branch.** Users pick up the
   standards the next time they authenticate.

## Governance

All changes flow through pull requests against the default branch and are auditable in
Git history. Members with write access can propose changes; only ruleset bypassers can
merge.

## Prerequisite: Azure access is configured separately

Distributing Git‑Ape installs the **tooling**, not Azure credentials. Each user / repo
still needs:

- `az login` (interactive) or OIDC + RBAC (CI), and the `azure-mcp` server configured —
  see [Azure setup](https://azure.github.io/git-ape/docs/getting-started/azure-setup).
- `/git-ape-onboarding` (repository mode) per repo to scaffold the deploy pipelines.

## References

- [About enterprise-managed plugin standards](https://docs.github.com/en/copilot/concepts/agents/about-enterprise-plugin-standards)
- [Configuring enterprise plugin standards](https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-enterprise/manage-agents/configure-enterprise-plugin-standards)
- [Preparing to use custom agents in your enterprise](https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-for-enterprise/manage-agents/prepare-for-custom-agents)
- [About custom agents](https://docs.github.com/en/copilot/concepts/agents/cloud-agent/about-custom-agents)
- [About agent skills](https://docs.github.com/en/copilot/concepts/agents/about-agent-skills) (org/enterprise skills "coming soon")
