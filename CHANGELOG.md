# Changelog

## [0.3.0] - 2026-06-19

Changes since [v0.2.0](https://github.com/Azure/git-ape/releases/tag/v0.2.0):

### Features

- **workshops:** 4-track workshop program (source) + Docusaurus pages (`052ead2`)
- **workshops:** deterministic sync + deck-build automation (`856280d`)
- **workshops:** agentic weekly workshop-content-updater (Phase 2) (`db5f7e7`)
- **git-ape-onboarding:** harden prereq gate, input collection, and trigger precision (`aff5c52`)
- **skill+evals:** bump Compliance Score Low->High and add refusal grader (`124f628`)
- **skill:** extract classification rules and discovery script for azure-policy-advisor (`85a1e67`)
- **skill:** trim and re-trigger azure-policy-advisor SKILL.md (`02c452f`)
- **evals:** add azure-policy-advisor eval suite (`b95fe9c`)

### Bug Fixes

- **deploy:** stop --verbose output corrupting deploy JSON parsed by jq (`c1dd848`)
- **workshops:** enable lockdown on agentic updater and address review nits (`582c24d`)
- **workshops:** satisfy public CI gates (markdownlint + actionlint) (`60c3d21`)
- **evals:** address PR #157 review on negative tests (`72464dd`)

### Refactoring

- **deploy:** use EXIT trap to clean up verbose log temp file (`6a137f3`)

### Documentation

- regenerate workflow docs for script-lint gate (`e6b9d10`)
- regenerate onboarding skill pages to match final SKILL.md (`f2e8459`)
- regenerate website docs for azure-policy-advisor and skill metadata (`abc3b82`)

### Chores

- **skills:** move argument-hint and user-invocable into metadata per agentskills.io spec (`fdbed0c`)
- **waza:** align token-budget thresholds with agentskills.io spec (`c764536`)

### Dependencies

- **website:** bump dompurify from 3.4.10 to 3.4.11 (`5413e63`)
- **website:** bump launch-editor (`d98ed1a`)
- **website:** bump ws (`1c1fe76`)
- **website:** bump dompurify from 3.4.0 to 3.4.10 (`836b671`)
- **website:** bump shell-quote from 1.8.3 to 1.8.4 (`d42f4b1`)
- **actions:** bump github/gh-aw-actions (`c1b9385`)
- **actions:** bump github/gh-aw-actions (`50ac152`)

### Other Changes

- Add optional drift-detector onboarding to git-ape-onboarding (`0784bb0`)
- Add lint + parse CI gate for skill shell/PowerShell scripts (`4aa2a71`)

## [0.2.0] - 2026-06-10

Changes since [v0.1.1](https://github.com/Azure/git-ape/releases/tag/v0.1.1):

### Features

- **skills:** emit partially-destroyed in local destroy scripts (`95dc3de`)
- **extension:** register prompt files in VSIX and tighten .vscodeignore (`4b2a1b8`)
- **onboarding:** replace exampleyml stubs with template-driven scaffold (`451686a`)
- **skills:** refine azure-stack-deploy and azure-stack-destroy guidance (`904a7dd`)
- **agents:** delegate to skills in deployer and template-generator (`a1d5633`)
- add azure-stack-* skills with fast async destroy (`69113e4`)
- implement Deployment Stacks for idempotent destroy + extended state schema (`79df223`)

### Bug Fixes

- **docs:** rewrite cross-skill SKILL.md links to resolvable slugs (`bc89221`)
- **docs:** read AZURE_SUBSCRIPTION_ID from vars in agent and example workflows (`8c1ca1b`)
- **workflows:** run release main-history guard for workflow_dispatch (`2bb671f`)
- **onboarding:** set AZURE_SUBSCRIPTION_ID as a variable, not a secret (`de50e71`)
- **onboarding:** sync copilot-instructions template with merged mirror (`e0ae84c`)
- **workflows:** route parameters.json values through env to block injection (`dce5833`)
- **onboarding:** remove /deploy comment trigger and fail loud on state push (`afb05ea`)
- **onboarding:** harden scaffolded workflows against matrix.deployment_id injection (`59c303e`)
- **workflows:** preserve FAILED counter in subscription resource cleanup (`236e840`)
- **onboarding:** harden and correct scaffolded workflows (`d6b41dc`)
- **workflows:** prevent shell and JS injection in deploy/destroy (`b2325f3`)
- **skills:** resolve PR review findings for deployment stacks (`9f14080`)
- **workflows:** address PR review findings (`9190c66`)
- **workflows:** prevent post-tag release version drift (`702f01c`)
- **plugin:** bump marketplace.json to 0.1.0 to match plugin.json (`6e017ab`)

### Documentation

- **website:** add companion page for git-ape-drift agentic workflow source (`e66e2ec`)
- **website:** regenerate for templated workflows and prompt assets (`7137093`)
- **instructions:** switch deploy/destroy guidance to Azure Deployment Stacks (`1fb61bd`)
- **onboarding:** reconcile AZURE_SUBSCRIPTION_ID as a variable (`67005a7`)
- drop /deploy comment trigger references (`d3cb045`)
- regenerate agent and workflow docs after upstream merge (`98c6318`)
- regenerate website docs from source (`4b07b5f`)

### Chores

- **models:** rename gpt-5-codex to gpt-5.3-codex across eval matrix (`8d5b9cf`)
- **evals:** pin LLM-as-judge to claude-opus-4.7 to eliminate self-grading bias (`c263d48`)
- **workflows:** recompile daily-repo-status lockfile against current source (`7a81254`)
- **evals:** fix stale judge model in waza-evals PR comment header (`6f2d00b`)
- **evals:** address PR review feedback on judge-model pin (`190887c`)
- **actionlint:** exclude gh-aw compiler output from lint (`f364da5`)
- regenerate gh-aw lock files with v0.76.1 (`175f81a`)

### Dependencies

- **website:** bump react group (`a56bcec`)
- **actions:** bump github/gh-aw-actions (`2ee8546`)
- **website:** bump js-yaml (`9cd63b0`)
- **website:** bump @types/react (`8e75378`)

### Tests

- **evals:** add evals for azure-stack-deploy and azure-stack-destroy (`ed078a0`)

## [0.1.1] - 2026-05-28

Changes since [v0.1.0](https://github.com/Azure/git-ape/releases/tag/v0.1.0):

### Bug Fixes

- **prereq-check:** parse az version via JSON on PowerShell (`47c76d2`)

### Chores

- **daily-status:** move schedule to 08:00 SGT (00:00 UTC) (`913988f`)
- **git-ape:** switch progress bar from ASCII to Unicode blocks (`a800e91`)

### Other Changes

- Merge pull request #126 from Azure/chore/git-ape-unicode-progress-bar (`058b4ed`)
- Merge pull request #125 from Azure/fix/release-drop-odd-minor-prerelease (`8f0498c`)
- Merge pull request #127 from Azure/chore/daily-status-schedule-sgt (`022208f`)
- Merge pull request #131 from Azure/fix/prereq-check-ps-az-parsing (`2ae81c7`)

All notable changes to this project are documented here.
This project follows [Semantic Versioning](https://semver.org/).

> Entries for `0.0.2` and `0.0.3` were reconstructed retroactively as part of
> recovering version-bump drift on `main`; future entries are generated
> automatically by the release workflow.

## [0.0.3] - 2026-05-13

### Documentation

- **extension:** fill VS Code Marketplace listing and surface install paths (`d6c6a8f`)
- Make VS Code install badges clickable via HTTPS redirects (`58905b5`)
- **extension:** add blank line between list and heading to satisfy markdownlint (`d6a6e3f`)

### Dependencies

- **website:** bump mermaid from 11.14.0 to 11.15.0 (`434796f`)

## [0.0.2] - 2026-05-11

### Features

- **extension:** add VS Code extension scaffolding and CI/CD workflows (`b6bcc13`)
- **extension:** set publisher to Git-APE and auto-publish to VS Code Marketplace (`845b6c2`)
- **release:** publish to VS Code Marketplace using odd-minor channel convention (`6b5cebf`)
- **plugin:** add `ape-context` plugin for enhanced context management (`ac2c892`)
- **devcontainer:** customize dev environment and add VS Code tasks (`f5fce29`)
- **devcontainer:** split into website and agent-engineering configs (`2131f9f`)
- **devcontainer:** add waza CLI and chat-customizations-evaluations to agent container (`d4972db`)
- **devcontainer:** ensure sandbox dependencies are installed before IaC tools (`d428922`)
- Add `CONTRIBUTING.md` and structural PR validation CI (`0dec1ad`)
- Add agentic workflows for issue-triage and daily repo status (`14bda1c`, `2de05d1`)

### Bug Fixes

- **extension:** correct chat contribution schema and bump engines/Node (`71c8c9d`)
- **extension:** set publisher to Git-ApeTeam (`2302f73`)
- **release:** remove stray `gh release upload` from marketplace publish step (`11c8fe4`)
- **workflows:** disable lockdown on issue-triage-agent (`8732a46`)
- **workflows:** silence SC2015 in gh-aw lock files and fix README fences (`499d25c`)
- **workflows:** recompile gh-aw lock files to v0.72.1 for valid awf release (`19cab81`)
- **devcontainer:** use sudo for waza installation to ensure proper binary placement (`96ebebe`)
- **devcontainer:** correct image tag for Git-Ape Website (`5c84ec5`)

### Documentation

- Reframe pitch as workload-agnostic and document workflow activation (`5080705`)

### Performance

- **devcontainer:** tighten install steps in both containers (`e2a1eab`)

### CI/CD

- **deps:** add Dependabot, bump Node to 24 LTS (`3d23ee0`)

### Chores

- **devcontainer:** drop Node feature from agent container (`451fde8`)
- Remove downloaded actionlint binary (`58df8de`)

### Dependencies

- **website:** bump the react group across 1 directory with 2 updates (`3ddf958`)
- **website:** bump the docusaurus group (`caa7d32`)
- **website:** bump `@babel/plugin-transform-modules-systemjs` (`ef6a125`)
- **website:** bump `fast-uri` from 3.1.0 to 3.1.2 (`6997bdb`)
- **actions:** bump the github-actions group with 7 updates (`e8aa1a3`)

## [0.0.1] - 2026-05-05

Initial tagged release.
