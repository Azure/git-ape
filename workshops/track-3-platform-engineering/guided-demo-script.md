# Guided Demo Script — Track 3: Platform Engineering

> 25 minutes facilitator-led | Azure sandbox + GitHub OIDC repo + Copilot Coding Agent enabled | Audience: DevOps, SRE, platform engineers

The Track 3 demo shows Git-Ape as a *platform* — not just a chat experience. Three loops: (1) PR-driven Plan → Deploy on merge, (2) headless mode where a GitHub Issue produces a deployment PR with no human at a chat panel, (3) safe teardown via metadata-flip + PR review. This is the closer for platform-team buy-in.

## Before the Demo

### Setup Checklist

- [ ] Sandbox subscription with OIDC federated credential and RBAC roles in place
- [ ] GitHub repo with the three workflows present: `git-ape-plan.yml`, `git-ape-deploy.yml`, `git-ape-destroy.yml`
- [ ] GitHub environments `azure-deploy` and `azure-destroy` configured with main-branch protection
- [ ] Copilot Coding Agent enabled on the repo (Settings → Code & automation → Copilot coding agent)
- [ ] Three browser tabs ready: repo (Issues), repo (PRs), Azure portal
- [ ] Local checkout of the workshop repo open in VS Code (mostly for narration; demo is GitHub-driven)
- [ ] An existing test deployment stack in the sandbox (we'll destroy it at the end)

### Backup Plan

- Coding Agent slow or unavailable → use the prepared seed branch `demo/track-3-pr` with the template already generated; skip to the Plan-comment moment
- Workflow run fails → switch to recorded segments at `workshops/shared/recordings/track-3-demo.mp4`

---

## Demo Script

### [0:00] The platform pivot (1 minute)

**Say:**
> "Tracks 1 and 2 showed Git-Ape as a developer experience — type a sentence, get infrastructure. That's powerful for individual engineers. But platform teams care about something different: how does this scale to 50 engineers, 200 PRs a week, with policy, audit, and lifecycle? In the next 25 minutes I'll show you three loops that turn Git-Ape into a platform: the PR loop, the headless loop, and the destroy loop. All Git. All audited. All policy-checkable."

### [1:00] Loop 1 — The PR-driven flow (8 minutes)

#### [1:00] Open a deployment PR

Switch to VS Code. On a fresh feature branch, open Copilot Chat:

```text
@git-ape deploy a container app with a postgres database
for the catalog project, staging environment, eastus
```

Let the agent run requirements → template → security analysis. **Skip narration of this** — the audience saw it in Track 2.

Once `.azure/deployments/<id>/` is generated, commit and push:

```bash
git checkout -b feat/catalog-staging
git add .azure/deployments/
git commit -m "feat: catalog staging container app + postgres"
git push -u origin feat/catalog-staging
gh pr create --title "Deploy catalog staging" --body "Container app + Postgres"
```

**Say:**
> "The deployment intent is now a PR. From here on, the platform does the work."

#### [3:00] The Plan workflow runs

Switch to the GitHub PR page. Wait for `git-ape-plan.yml` to complete (~30–60s — fill the time by narrating).

**Narrate while it runs:**
> "The Plan workflow logs into Azure via OIDC — no stored secrets. It validates the template, runs `az deployment sub what-if`, reads the architecture diagram from the PR, and posts everything as a single comment on the PR."

Once the comment appears, scroll through it. Three sections to highlight:

1. **Validation result** — green check, errors listed inline if any
2. **What-if** — every resource the deploy will create, modify, delete
3. **Architecture diagram** — the Mermaid from the PR rendered inline

**Say:**
> "This comment is the review surface. A reviewer opens the PR, reads this comment, and either requests changes or approves. Same workflow as code review — except the artefact is infrastructure."

#### [5:00] Approve and merge

Approve the PR yourself (or have a co-facilitator approve). Merge to main.

**Say:**
> "Merge triggers `git-ape-deploy.yml`. Same OIDC login. Same template. Now it deploys."

#### [5:30] Deploy workflow runs

Switch to the Actions tab and open the running deploy job. Narrate:

- "Validates the template again — never trust state."
- "Creates the Deployment Stack with `--action-on-unmanage deleteAll`."
- "Runs integration tests."
- "Commits `state.json` (with `stackId` and managed resources) back to main."

When complete, switch to Azure portal — show the stack and resources exist. Then back to GitHub — show the new commit on main with `state.json`.

**Say:**
> "Three things just happened: infrastructure deployed, state committed to Git, comment posted back to the PR with the deployment result. Reviewable, auditable, reproducible."

### [9:00] Loop 2 — Headless mode (8 minutes)

#### [9:00] Why headless matters

**Say:**
> "Up until now, a human was typing in Copilot Chat. That's fine for one engineer. But what if your platform team gets infrastructure requests via tickets? What if a service team raises an Issue saying 'we need a new microservice with a queue and a database'? You don't want to hand-translate every Issue. Headless mode lets the Copilot Coding Agent do that translation, on a branch, in a PR."

#### [9:30] Open an Issue

Switch to the Issues tab. Click New Issue. Title and body:

```text
Title: Deploy notifications worker

Body:
@github-copilot
Please deploy a Python container app with a service bus queue
for the notifications project, dev environment, southeastasia.
Use managed identity for the queue.
```

Assign Copilot. Submit.

**Say:**
> "Copilot Coding Agent picks up the Issue on its own runner. It does exactly what I did in Tracks 1 and 2 — requirements, template, security, cost — but on a fresh branch with no human in the chat. Then it opens a PR."

#### [10:30] Wait for the PR (and fill the time)

The agent typically takes 3–5 minutes. **Don't sit in silence.** Use this time to:

- Show the agent's instructions file: `.github/instructions/git-ape-agent.md` (or wherever your repo stores it)
- Explain the Issue → Branch → PR flow on a whiteboard
- Take audience questions about how this scales (rate limits, concurrent runs, etc.)
- If pre-staged, switch to the prepared `demo/track-3-headless` branch and skip ahead

#### [13:30] PR opened by the agent

When the PR appears, walk through it:

- Branch name (auto-generated by the agent)
- Files changed: `.azure/deployments/<id>/template.json`, `parameters.json`, `architecture.md`
- Plan workflow already running on the PR

**Say:**
> "No human typed in chat. An Issue with the right format became a PR. The Plan workflow validates, posts the same comment we saw in Loop 1, and now a platform engineer can review and approve."

#### [15:30] Review the Plan comment

Same three sections as before. Optionally tweak the template (e.g., change region) directly on the PR branch to show iteration:

```bash
gh pr checkout <number>
# edit template
git commit -am "tweak: change region to eastus2"
git push
```

The Plan workflow re-runs and updates the same comment (idempotent via HTML marker).

**Say:**
> "Comment updates in place. No comment spam. One PR, one canonical plan."

#### [17:00] Approve and merge → deploy

Approve, merge. Deploy workflow runs. Don't narrate this part — the audience saw it in Loop 1.

**Say while it runs:**
> "From an Issue, in three to five minutes of agent time and a one-minute human review, we have a deployed, integration-tested infrastructure change with a complete audit trail."

### [18:00] Loop 3 — Safe destroy (6 minutes)

#### [18:00] Why destroy is a separate flow

**Say:**
> "Most platforms make destruction easy and dangerous — one CLI flag, the whole thing is gone. Git-Ape treats teardown as a deliberate, reviewable action. You don't run `destroy`. You open a PR that flips a flag, and a human approves."

#### [18:30] Flip the metadata

Switch to the catalog staging deployment from Loop 1. Open `.azure/deployments/<id>/metadata.json`. Show the current status:

```json
{ "status": "deployed", ... }
```

On a new branch, change to:

```json
{ "status": "destroy-requested", ... }
```

Commit, push, open a PR titled "Destroy catalog staging".

**Say:**
> "One file. One field. The PR is the destroy request. Reviewers see exactly which deployment is targeted — by deployment ID — and what its stack name is."

#### [20:30] Review and approve

Show the PR diff: a single field change. Approve. Merge.

#### [21:00] Destroy workflow runs

`git-ape-destroy.yml` triggers. Watch the run:

- Reads `state.json` to find the stack name
- Calls `az stack sub show` to inventory managed resources
- Calls `az stack sub delete --action-on-unmanage deleteAll`
- Updates `metadata.json` status to `destroyed`

**Say:**
> "One call. One stack. Every managed resource gone — across all RGs, role assignments, policy assignments at sub scope. No orphans. Idempotent if re-run."

Switch to Azure portal to confirm the resources are gone.

### [24:00] The platform takeaways (1 minute)

**Closing line:**
> "Three loops, three lessons. Loop 1: every deploy is a PR. Loop 2: an Issue can become a PR without a human in chat. Loop 3: destroy is a deliberate, reviewable action — not an oops. All Git. All policy-checkable. All reversible. This is what 'infrastructure as a platform' looks like. Lab 1 will walk you through wiring this up on your own sandbox. Questions?"

---

## Key Talking Points to Emphasize

| Moment | What to highlight |
|--------|------------------|
| Plan workflow comment | "Single canonical review surface. Updates in place." |
| OIDC, not secrets | "Zero stored Azure credentials in the repo. Federated trust." |
| State.json committed | "Every deploy leaves a Git breadcrumb. Auditable forever." |
| Coding Agent loop | "An Issue with a `@github-copilot` mention becomes a PR. No chat panel required." |
| Deployment Stack | "One unit of lifecycle. One destroy, no orphans." |
| Destroy is a PR | "Destruction is reviewed like any other change. No one-flag wipeouts." |
| metadata.json flip | "Single field change. Clear intent. Diff-able." |

---

## Common Audience Questions

| Question | Answer |
|----------|--------|
| "What if Coding Agent generates the wrong thing?" | "It opens a PR — review and reject like any other PR. The agent doesn't deploy anything itself; the workflow on merge does. Multiple gates." |
| "How do we enforce org-specific policy?" | "Policy Advisor agent (Lab 4) integrates Azure Policy checks into the Plan comment. Lab 4 walks the CIS Azure Foundations v3 assessment." |
| "What about multi-environment promotion?" | "Lab 3 covers it: one template, parameter files per environment, separate PRs per promotion. Same workflows." |
| "What if two PRs deploy at the same time?" | "Deploy workflow has `concurrency` set with `max-parallel: 1`. PRs serialise. In-flight deploys are never cancelled." |
| "Can I import existing resources?" | "Lab 5: the IaC Exporter agent reverse-engineers a live RG into an ARM template you can take over." |
| "What's the blast radius if OIDC creds leak?" | "OIDC tokens are short-lived (~1 hour) and bound to repo + workflow + branch. Rotate the federated credential trust subject; no static secret to rotate." |
| "How does this work with private endpoints / hub-and-spoke?" | "The agent generates VNet integration and private endpoint resources. Networking patterns are in the Onboarding skill's reference templates." |

---

## Pre-Recording Option

1. Record against a real OIDC-onboarded sandbox repo
2. Record each loop separately and stitch — the Coding Agent wait is the biggest cut
3. For Loop 2, pre-trigger the Issue and edit so only the result-time is visible
4. Chapter markers at: 1:00 (Loop 1 starts), 9:00 (Loop 2 starts), 18:00 (Loop 3 starts)
5. Target final duration: 18–20 minutes
6. Save to `workshops/shared/recordings/track-3-demo.mp4`
