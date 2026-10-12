# Screenshot Library

> Workshop screenshots for visually-meaningful steps. Captured by the facilitator on first dry-run and refreshed when UI changes break them.

This directory ships **empty intentionally** -- screenshots are environment-specific (Codespace name, sandbox sub) and must be captured by a facilitator who can produce a presentable image.

## What to capture

Per track, capture these screenshots. Save as PNG with the listed filename.

### Track 1 -- Zero to Deploy

| File | Captures |
|---|---|
| `t1-copilot-chat-git-ape.png` | Copilot Chat panel showing `@git-ape deploy ...` invocation and the first agent response |
| `t1-security-gate-passed.png` | Security gate output showing PASSED with listed checks |
| `t1-deployment-success.png` | Azure portal RG showing the deployed Function App + Storage + App Insights |

### Track 2 -- Deploy Like a Pro

| File | Captures |
|---|---|
| `t2-onboarding-summary.png` | Final onboarding summary: App Reg, federated credentials, RBAC roles created |
| `t2-security-gate-blocked.png` | Security gate showing BLOCKED on a deliberately broken template (Lab 3) |
| `t2-cost-estimate.png` | Cost-estimate output with per-resource monthly figures |

### Track 3 -- Platform Engineering

| File | Captures |
|---|---|
| `t3-plan-pr-comment.png` | GitHub PR view with the Plan workflow comment (4 sections: validation, what-if, architecture, cost) |
| `t3-deploy-success-comment.png` | PR view with Deploy workflow result comment |
| `t3-headless-issue-to-pr.png` | Side-by-side: opened Issue and the auto-generated PR |
| `t3-destroy-stack-result.png` | Workflow run showing `az stack sub delete` output |

### Track 4 -- Executive Briefing

| File | Captures |
|---|---|
| `t4-demo-end-state.png` | Resource group view after the guided demo deployment |

## Capture process

1. Run the lab end-to-end on a clean sandbox.
2. At each capture point, screenshot the relevant window (use a tool that preserves font crispness; avoid heavy compression).
3. Crop to the smallest box that includes the meaningful content.
4. Redact any sensitive identifiers: subscription names, tenant names, UPNs.
5. Save with the listed filename in this directory.
6. Commit; the screenshots become part of the audit trail and reference for future facilitators.

## When to refresh

Re-capture whenever:

- The Azure portal UI changes materially.
- Copilot Chat redesigns the agent output panel.
- An agent's output schema changes (different sections, different colours).
- The workshop sandbox subscription changes (cosmetic, but worth keeping current).

The customer-readiness checklist (see `workshops/CUSTOMER-READINESS-CHECKLIST.md` when shipped) will list "screenshots populated and current" as a pre-customer gate.
