---
title: "Git Ape Skills"
sidebar_label: "Git Ape Skills"
description: "Search Git-Ape core skills, community skills, and named packs, or explicitly install community skills and packs from Azure/git-ape for this project or all your projects. USE FOR: find a skill, search capabilities, list community skills or packs, install a community skill or pack. DO NOT USE FOR: automatically installing search results, global plugin installation, or invoking skills not available in the current session."
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/skills/git-ape-skills/SKILL.md -->


# Git Ape Skills

> Search Git-Ape core skills, community skills, and named packs, or explicitly install community skills and packs from Azure/git-ape for this project or all your projects. USE FOR: find a skill, search capabilities, list community skills or packs, install a community skill or pack. DO NOT USE FOR: automatically installing search results, global plugin installation, or invoking skills not available in the current session.

## Details

| Property | Value |
|----------|-------|
| **Skill Directory** | `.github/skills/git-ape-skills/` |
| **Phase** | General |
| **User Invocable** | ✅ Yes |
| **Usage** | `/git-ape-skills search <capability> | plan <skill-name> | install <skill-name> | plan-pack <pack-name> | install-pack <pack-name>` |


## Documentation

# Git-Ape Skill Discovery

Search one registry for core skills and community skills reviewed through
Azure/git-ape PRs. Community source lives outside core's loader path and is not
included in the VSIX. Review is oversight, not a guarantee of safety.

## When to Use

- Find a capability, list skills, or inspect a skill's author and source.
- Explicitly install one community skill for this project or all your projects.
- Discover or explicitly install a named pack of independent community skills.

## Procedure

1. For discovery, run `node` with the [skills.js](https://github.com/Azure/git-ape/blob/main/.github/skills/git-ape-skills/scripts/skills.js) helper:
   `search <query>`. The helper reads the bundled `.github/skills/registry.json`
   without network access, file changes, or scanning installed skills. Alternatively read that registry
   directly if Node.js is unavailable.
2. Present matches with name, description, tier (or `kind: pack`), author, source, and docs.
   Clearly distinguish core skills from community skills that are only listed.
   Do not invoke a listed community skill unless it is available in this session.
3. For an installation request (single skill or pack), ask **"This project only"
   vs "All my projects" before requesting any project folder**:
   - **This project only**: use `--scope workspace --workspace <directory>`.
     Resolve the current project where possible; ask for a folder only if no
     project is available or the target is unclear. The project must already
     exist. The helper resolves `<workspace>/.github/skills/`.
   - **All my projects**: use `--scope personal`, without `--workspace`.
     Do not ask for a raw path or a project. The helper uses `os.homedir()` to
     resolve the user's `.copilot/skills/` directory automatically, for example
     `C:\Users\davidwright\.copilot\skills`. A missing personal root is allowed.
   The helper requires Node.js and an authenticated `gh` CLI. Run
   `plan <name> <scope-options> [--revision <full-sha>]` for a single skill.
   Preview resolves one Azure/git-ape commit and shows scope, resolved destination,
   exact files/hashes, provenance location, and conflicts with **no writes**,
   including when the personal root does not exist. Stop on errors or conflicts.
   Do not fetch skill bodies from external repositories.
4. Show the plan and ask for explicit approval of the skill, **full commit SHA,
   files, scope, and resolved destination** before writing files. Then run:
   `install <name> <same-scope-options> --revision <approved-full-sha> --yes`.
   Never pass `--yes` merely because a search returned a match.
5. Report the installed location and provenance. Existing skills are never
   overwritten, and skill scripts are not executed by installation. Tell the
   user to reload or start a new session if the client has not discovered the
   new skill. Personal discovery depends on client support (including App/CLI);
   do not claim it is active or available until session reload and verification.

## Pack installation

Packs are explicit member lists in `.github/skill-packs/<name>/pack.json`.
Each member remains an independent skill; packs do not introduce UI grouping.

1. Search with `search <query>`. Pack metadata and member names are searchable.
   An older registry without `packs` still supports individual skill discovery.
2. Choose scope as described above, then run
   `plan-pack <name> <scope-options> [--revision <full-sha>]`.
   This resolves one pinned Azure/git-ape commit and returns pack metadata, the
   complete member list, exact source files/hashes and destinations, the generated
   provenance file, and conflicts. It verifies the pinned pack manifest against
   the registry and makes **no writes**. Stop on validation
   errors and resolve conflicts without overwriting existing skills.
3. Show the plan and request explicit approval of its **full commit SHA, entire
   member list, files, scope, and resolved destination**. Never infer approval from
   search or preview.
4. After approval, run
   `install-pack <name> <same-scope-options> --revision <approved-full-sha> --yes`.
   A full pinned SHA is required. The helper repeats all source/destination
   validation, downloads and hash-verifies **all** members before the first final
   write, and refuses overwrites (including dangling symlinks and case collisions).
   Failed installation removes only its newly created member directories;
   cleanup failures are surfaced explicitly for manual review.
5. Report destinations and each member's provenance, including the pack name.
   Do not execute community scripts or install their dependencies. Ask the user
   to reload or start a new session and verify discovery before invoking skills.

## Outputs

Search returns matching registry metadata, not installed status. Previews and
installation return the scope, resolved destinations, and pinned commit.
Installation writes `.git-ape-provenance.json` within each selected skill,
including its scope and destination. Workspace changes can be reviewed and
committed by their owner; personal skills remain outside the project.

CLI scope defaults to `workspace` for compatibility and requires `--workspace`;
never silently choose a destination in conversation. Invalid scopes and combining
`--scope personal` with `--workspace` are rejected before network access or writes.

## Constraints

- Search never installs or activates anything.
- Install only from Azure/git-ape, never a registry entry's external source URL.
- Copy the complete selected skill directory, including scripts and references.
- Stop on missing content, unsafe paths, symlinks, incomplete trees, or collisions.
- Do not automatically install dependencies or run community scripts.
- Both scopes install file-based skills, not a global plugin. Personal scope
  does not install the Git-Ape plugin or introduce App sidebar grouping.
- Client support for the selected skill discovery location is required.
