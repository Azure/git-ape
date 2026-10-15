# Community Skills

Community skills are reviewed through pull requests in Azure/git-ape and stored
as standard `<name>/SKILL.md` files with their `scripts/` and `references/`.
Each skill must declare `metadata.author`. Review provides oversight and
provenance, not a guarantee that a skill is safe.

This directory is deliberately outside core's `.github/skills/` loader path
and excluded from the VSIX. Git-Ape includes searchable registry metadata,
not community skill bodies. Listing a skill does not install or activate it.

## Submitting a skill

1. Copy [COMMUNITY_SKILL.template.md](../templates/COMMUNITY_SKILL.template.md)
   into `<name>/SKILL.md` here, using a unique kebab-case name.
2. Include author attribution, standard skill sections, and all required
   supporting files. Keep dependencies within the skill directory.
3. Open a pull request and pass structural validation, Markdown lint, and
   script checks. Generate the registry and documentation.

## Installing a selected skill

Use `/git-ape-skills search <capability>` to search the unified registry.
After reviewing a skill and explicitly approving installation, use
`/git-ape-skills install <name>`. The installer downloads only from a pinned
revision of Azure/git-ape and copies the skill into your repository's
`.github/skills/<name>/`. It does not overwrite existing files or execute the
skill's scripts. Your client may need a reload or a new session to discover it.
