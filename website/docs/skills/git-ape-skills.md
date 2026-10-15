---
title: "Git Ape Skills"
sidebar_label: "Git Ape Skills"
description: "Search the Git-Ape core and community skill registry, or explicitly install a selected community skill from Azure/git-ape. USE FOR: find a skill, search capabilities, list community skills, install a community skill. DO NOT USE FOR: automatically installing search results or invoking skills not available in the current session."
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/skills/git-ape-skills/SKILL.md -->


# Git Ape Skills

> Search the Git-Ape core and community skill registry, or explicitly install a selected community skill from Azure/git-ape. USE FOR: find a skill, search capabilities, list community skills, install a community skill. DO NOT USE FOR: automatically installing search results or invoking skills not available in the current session.

## Details

| Property | Value |
|----------|-------|
| **Skill Directory** | `.github/skills/git-ape-skills/` |
| **Phase** | General |
| **User Invocable** | ✅ Yes |
| **Usage** | `/git-ape-skills search <capability> | install <skill-name>` |


## Documentation

# Git-Ape Skill Discovery

Search one registry for core skills and community skills reviewed through
Azure/git-ape PRs. Community source lives outside core's loader path and is not
included in the VSIX. Review is oversight, not a guarantee of safety.

## When to Use

- Find a capability, list skills, or inspect a skill's author and source.
- Explicitly install one community skill into a chosen workspace.

## Procedure

1. For discovery, run `node` with the [skills.js](https://github.com/Azure/git-ape/blob/main/.github/skills/git-ape-skills/scripts/skills.js) helper:
   `search <query>`. The helper reads the bundled `.github/skills/registry.json`
   without network access or file changes. Alternatively read that registry
   directly if Node.js is unavailable.
2. Present matches with name, description, tier, author, source, and docs.
   Clearly distinguish core skills from community skills that are only listed.
   Do not invoke a listed community skill unless it is available in this session.
3. For an installation request, identify the destination workspace and explain
   that the helper requires Node.js and an authenticated `gh` CLI. Show the
   selected skill and supporting files from Azure/git-ape at the commit to be
   installed. Resolve the commit with `gh api repos/Azure/git-ape/commits/main
   --jq .sha`, or use a user-selected full commit SHA. Do not fetch skill bodies
   from external repositories.
4. Ask for explicit approval of the skill, commit, and destination before
   writing files. Then run the helper with:
   `install <name> --workspace <directory> --revision <full-sha> --yes`.
   Never pass `--yes` merely because a search returned a match.
5. Report the installed location and provenance. Existing skills are never
   overwritten, and skill scripts are not executed by installation. Tell the
   user to reload or start a new session if the client has not discovered the
   new workspace skill. Do not claim it is available until verified.

## Outputs

Search returns matching registry entries. Installation returns the destination
and pinned commit, and writes `.git-ape-provenance.json` within the selected
skill. The workspace change can be reviewed and committed by its owner.

## Constraints

- Search never installs or activates anything.
- Install only from Azure/git-ape, never a registry entry's external source URL.
- Copy the complete selected skill directory, including scripts and references.
- Stop on missing content, unsafe paths, symlinks, incomplete trees, or collisions.
- Do not automatically install dependencies or run community scripts.
- Workspace installation is not global plugin installation. Client support
  for workspace `.github/skills/` discovery is required.
