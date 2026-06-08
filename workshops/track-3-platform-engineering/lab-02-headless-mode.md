# Lab 2: Headless Mode

> 15 minutes | Azure required

File a GitHub Issue describing what you need. Watch the Copilot Coding Agent generate a PR and deploy automatically.

## What You Learn

- How headless mode works (no human in the loop during generation)
- How the Coding Agent parses requirements from issue text
- How the full pipeline runs: issue → branch → PR → plan → deploy

## Step 1: Create a GitHub Issue

```bash
gh issue create \
  --title "Deploy: Container App for demo-api in dev, Southeast Asia" \
  --body "Deploy a container app for the demo-api project in dev environment, region southeastasia. Include a container registry and log analytics workspace."
```

Note the issue number returned.

> **What happens next depends on whether Copilot Coding Agent is enabled for your repo.** If it is, the agent picks up the issue automatically. If not, you can simulate the flow manually (see Alternative Path below).

## Step 2: Watch the Coding Agent (If Enabled)

The Copilot Coding Agent:
1. Reads the issue body
2. Creates a feature branch
3. Generates ARM template, architecture diagram, requirements, metadata
4. Opens a PR referencing the issue

Monitor progress:

```bash
# Check for new PRs
gh pr list --state open
```

## Step 3: Review the Auto-Generated PR

Open the PR the agent created:

```bash
gh pr view <PR_NUMBER> --web
```

The PR contains:
- ARM template with Container App, Container Registry, Log Analytics
- Architecture diagram
- Requirements captured from the issue body
- Metadata with `mode: headless`

The `git-ape-plan.yml` workflow runs automatically and posts the plan comment.

## Step 4: Approve and Deploy

Review the plan, then approve and merge:

```bash
gh pr review <PR_NUMBER> --approve
gh pr merge <PR_NUMBER> --squash
```

The deploy workflow executes and posts results.

## Alternative Path: Simulate Headless Mode

If the Coding Agent isn't enabled, simulate the flow:

```bash
# Create branch
git checkout -b deploy/demo-api
```

In Copilot Chat:

```text
@git-ape deploy a container app for demo-api in dev, region southeastasia.
Include a container registry and log analytics workspace.
```

Then commit, push, and open a PR as in Lab 1. The CI/CD workflows run the same way.

## What You Learned

| Concept | What It Means |
|---------|--------------|
| **Headless mode** | Copilot Coding Agent generates infrastructure from issue descriptions |
| **Human gate** | Agent generates the PR but humans still approve before deployment |
| **Issue-to-deploy** | Complete flow from a written description to running infrastructure |
| **Same workflows** | Whether interactive or headless, the same plan/deploy workflows run |

**Next:** [Lab 3 — Multi-Environment](lab-03-multi-environment.md)

## Step 6: How the agent parses the issue

The Copilot Coding Agent reads the Issue body, extracts requirements, runs the same stages as interactive Git-Ape (Requirements -> Template -> Security -> Cost), and opens a PR. The agent never deploys directly.

Required issue format:

Project: <slug>
Environment: dev|staging|prod
Region: <azure-region>
Resources: <natural language description>

Missing fields prompt clarification on the Issue.

## Step 7: PR review surface

The opened PR has the same Plan workflow as Lab 1. Review and approve as normal. Headless = Issue -> Branch -> PR automation; everything past the PR is the standard deploy.

## Common failures

- Coding Agent not enabled: repo Settings, enable.
- No PR after agent run: missing required fields; clarify on Issue.
