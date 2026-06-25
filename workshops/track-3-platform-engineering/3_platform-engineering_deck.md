---
marp: true
theme: uncover
size: 16:9
paginate: true
footer: "Git-Ape · Microsoft Azure · AI-Powered Cloud Deployment"
style: |
  :root {
    --color-background: #0f1419;
    --color-surface: #17202b;
    --color-surface-soft: rgba(255, 255, 255, 0.06);
    --color-foreground: #f5f7fb;
    --color-text-dark: #18212e;
    --color-highlight: #8b9df0;
    --color-highlight-strong: #667eea;
    --color-accent: #ffd700;
    --color-accent-soft: #ffe14d;
    --color-muted: #c0cad7;
    --color-panel: rgba(255, 255, 255, 0.08);
    --color-panel-border: rgba(255, 255, 255, 0.14);
    --color-panel-light: #ffffff;
    --color-cool: rgba(139, 157, 240, 0.14);
    --color-warm: rgba(255, 215, 0, 0.12);
    --hero-gradient: linear-gradient(135deg, #667eea 0%, #764ba2 48%, #f093fb 100%);
    --dark-gradient: linear-gradient(135deg, #0f1419 0%, #1a252f 45%, #2c3e50 100%);
    --panel-glow: 0 18px 50px rgba(0, 0, 0, 0.28);
  }
  section {
    position: relative;
    overflow: hidden;
    background: var(--dark-gradient);
    color: var(--color-foreground);
    padding: 48px 56px;
    font-size: 26px;
    line-height: 1.3;
  }
  section::before {
    content: "";
    position: absolute;
    inset: auto -8% -18% auto;
    width: 360px;
    height: 360px;
    border-radius: 50%;
    background: radial-gradient(circle, rgba(255, 215, 0, 0.16) 0%, rgba(255, 215, 0, 0) 70%);
    pointer-events: none;
  }
  section::after {
    font-size: 0.55em;
    color: rgba(255, 255, 255, 0.35);
  }
  section.lead::after {
    display: none;
  }
  .glow-tl {
    position: absolute;
    inset: -18% auto auto -8%;
    width: 420px;
    height: 420px;
    border-radius: 50%;
    background: radial-gradient(circle, rgba(102, 126, 234, 0.22) 0%, rgba(102, 126, 234, 0) 72%);
    pointer-events: none;
    z-index: 0;
  }
  section h1 {
    font-size: 1.8em;
    font-weight: 800;
    color: #ffffff;
    margin-bottom: 0.2em;
    letter-spacing: -0.02em;
  }
  section h2 {
    font-size: 1.02em;
    font-weight: 600;
    color: var(--color-muted);
    margin-bottom: 0.5em;
  }
  section.lead h1 {
    font-size: 2.2em;
  }
  section.lead {
    justify-content: center;
    background: var(--hero-gradient);
    color: #ffffff;
  }
  section.lead::before,
  section.gradient::before {
    opacity: 0.9;
  }
  section.lead h1,
  section.lead h2,
  section.lead h3,
  section.lead p,
  section.lead strong {
    color: #ffffff;
  }
  section.lead h2 {
    opacity: 0.85;
  }
  section.gradient {
    background: linear-gradient(135deg, #121826 0%, #253247 50%, #764ba2 100%);
  }
  section.light {
    background: linear-gradient(180deg, #f7f9fc 0%, #eef3fb 100%);
    color: var(--color-text-dark);
  }
  section.light h1 {
    color: #223047;
  }
  section.light h2 {
    color: #526277;
  }
  section.light strong {
    color: #4f6ae6;
  }
  section.light::before {
    background: radial-gradient(circle, rgba(102, 126, 234, 0.12) 0%, rgba(102, 126, 234, 0) 70%);
  }
  section.light::after {
    font-size: 0.55em;
    color: rgba(15, 23, 42, 0.3);
  }
  section h3 {
    color: var(--color-accent);
    font-size: 0.95em;
    font-weight: 700;
    margin: 0.2em 0 0.4em;
  }
  p,
  blockquote,
  table,
  ul,
  ol {
    margin-top: 0.35em;
  }
  ul {
    padding-left: 1.1em;
  }
  ol {
    padding-left: 1.2em;
  }
  li {
    margin: 0.22em 0;
  }
  strong {
    color: #ffffff;
  }
  blockquote {
    border-left: 6px solid var(--color-accent);
    background: rgba(255, 255, 255, 0.08);
    padding: 0.5em 0.8em;
    border-radius: 12px;
  }
  table {
    width: 100%;
    font-size: 0.72em;
    border-collapse: collapse;
    background: rgba(255, 255, 255, 0.1);
    border: 1px solid var(--color-panel-border);
    border-radius: 14px;
    overflow: hidden;
  }
  th {
    background: rgba(255, 255, 255, 0.12);
    color: #ffffff;
    text-align: left;
    padding: 12px 14px;
  }
  td {
    padding: 12px 14px;
    border-top: 1px solid rgba(255, 255, 255, 0.12);
  }
  .columns {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 28px;
    align-items: start;
  }
  .panel {
    position: relative;
    z-index: 1;
    background: var(--color-panel);
    border: 1px solid var(--color-panel-border);
    border-radius: 18px;
    padding: 20px 22px;
    backdrop-filter: blur(10px);
    box-shadow: var(--panel-glow);
  }
  .metric {
    position: relative;
    z-index: 1;
    background: linear-gradient(180deg, rgba(255,255,255,0.13) 0%, rgba(255,255,255,0.06) 100%);
    border: 1px solid var(--color-panel-border);
    border-radius: 18px;
    padding: 18px 20px;
    margin-top: 0.5em;
    box-shadow: var(--panel-glow);
  }
  .metric strong {
    display: block;
    font-size: 1.6em;
    margin-bottom: 0.12em;
    color: var(--color-accent);
  }
  .pill {
    display: inline-block;
    padding: 6px 12px;
    margin: 4px 8px 0 0;
    border-radius: 999px;
    background: rgba(255, 255, 255, 0.16);
    color: #ffffff;
    font-size: 0.7em;
    font-weight: 600;
    border: 1px solid rgba(255, 255, 255, 0.18);
  }
  .note {
    color: var(--color-muted);
    font-size: 0.72em;
  }
  .compact li {
    margin: 0.12em 0;
  }
  .tiny {
    font-size: 0.68em;
  }
  .center {
    text-align: center;
  }
  .eyebrow {
    text-transform: uppercase;
    letter-spacing: 0.08em;
    font-size: 0.58em;
    color: var(--color-accent-soft);
    font-weight: 700;
    margin-bottom: 0.7em;
  }
  .hero-grid {
    display: grid;
    grid-template-columns: 1.2fr 0.8fr;
    gap: 32px;
    align-items: center;
    width: 100%;
    max-width: 100%;
  }
  .hero-card {
    background: rgba(255, 255, 255, 0.12);
    border: 1px solid rgba(255, 255, 255, 0.18);
    border-radius: 22px;
    padding: 24px;
    backdrop-filter: blur(12px);
    box-shadow: var(--panel-glow);
  }
  .icon-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 14px;
    margin-top: 0.8em;
  }
  .icon-tile {
    background: rgba(255, 255, 255, 0.12);
    border: 1px solid rgba(255, 255, 255, 0.15);
    border-radius: 18px;
    padding: 16px;
    min-height: 118px;
  }
  .icon-tile svg {
    width: 34px;
    height: 34px;
    margin-bottom: 8px;
  }
  .icon-tile p {
    margin: 0;
    font-size: 0.72em;
  }
  .flow {
    display: grid;
    grid-template-columns: 1fr auto 1fr auto 1fr auto 1fr;
    gap: 10px;
    align-items: center;
    margin-top: 0.6em;
  }
  .flow-box {
    background: rgba(255,255,255,0.1);
    border: 1px solid rgba(255,255,255,0.14);
    border-radius: 16px;
    padding: 14px 12px;
    text-align: center;
    min-height: 80px;
    font-size: 0.88em;
  }
  .flow-box h3 {
    margin: 0 0 0.25em;
    font-size: 1.05em;
  }
  .flow-box p {
    margin: 0;
    font-size: 0.92em;
    line-height: 1.25;
  }
  .arrow {
    color: var(--color-accent);
    font-size: 1.3em;
    font-weight: 700;
    text-align: center;
    line-height: 1;
  }
  .badge-row {
    display: flex;
    gap: 10px;
    flex-wrap: wrap;
    margin-top: 0.65em;
  }
  .badge {
    background: rgba(255, 215, 0, 0.12);
    color: #ffe89a;
    border: 1px solid rgba(255, 215, 0, 0.28);
    border-radius: 999px;
    padding: 7px 12px;
    font-size: 0.64em;
    font-weight: 700;
  }
  .logo-mark {
    width: 84px;
    height: 84px;
    object-fit: contain;
    border-radius: 18px;
    background: rgba(255,255,255,0.1);
    padding: 10px;
    border: 1px solid rgba(255,255,255,0.18);
    box-shadow: var(--panel-glow);
  }
  .split-hero {
    display: grid;
    grid-template-columns: 0.95fr 1.05fr;
    gap: 28px;
    align-items: center;
  }
  .stat-stack {
    display: grid;
    gap: 14px;
  }
  .mini {
    font-size: 0.66em;
  }
  .narrow {
    max-width: 88%;
  }
  code {
    background: rgba(48, 64, 110, 0.55) !important;
    color: #e8efff !important;
    border-radius: 6px;
    padding: 0.12em 0.32em;
    font-weight: 500;
  }
  section.agenda h1,
  section.roi h1 {
    margin-bottom: 0.15em;
  }
  section.light .panel,
  section.light .metric,
  section.light .hero-card,
  section.light .icon-tile,
  section.light .flow-box,
  section.light table {
    background: rgba(255,255,255,0.92);
    border-color: rgba(79, 106, 230, 0.14);
    box-shadow: 0 14px 40px rgba(60, 72, 88, 0.1);
    color: var(--color-text-dark);
  }
  section.light th {
    background: rgba(102, 126, 234, 0.12);
    color: #20324f;
  }
  section.light td {
    border-top-color: rgba(79, 106, 230, 0.12);
  }
  section.light .metric strong,
  section.light .eyebrow,
  section.light h3 {
    color: #4f6ae6;
  }
  section.light .badge {
    background: rgba(102, 126, 234, 0.10);
    color: #3b51c4;
    border-color: rgba(102, 126, 234, 0.32);
  }
  section.light .pill {
    background: rgba(102, 126, 234, 0.10);
    color: #20324f;
    border-color: rgba(102, 126, 234, 0.22);
  }
  section.light .note {
    color: #5a6a7a;
  }
  section.light code {
    background: rgba(20, 30, 50, 0.07) !important;
    color: #20324f !important;
  }
  section.light .panel code,
  section.light .hero-card code {
    background: rgba(102, 126, 234, 0.10);
    color: #20324f;
  }
  .metric h3 {
    font-size: 0.95em;
    margin: 0 0 0.35em;
  }
  .panel pre,
  .hero-card pre {
    background: rgba(0, 0, 0, 0.32);
    border-radius: 12px;
    padding: 12px 14px;
    margin: 0.4em 0;
    overflow: hidden;
  }
  section.light .panel pre,
  section.light .hero-card pre {
    background: rgba(20, 30, 50, 0.06);
    border: 1px solid rgba(102, 126, 234, 0.18);
  }
  .panel pre code,
  .hero-card pre code {
    background: transparent;
    color: #f5f7fb;
    font-size: 0.78em;
  }
  section.light .panel pre code,
  section.light .hero-card pre code {
    color: #20324f;
  }
  .flow-tight {
    display: grid;
    grid-template-columns: 1fr auto 1fr auto 1fr auto 1fr;
    gap: 8px;
    align-items: stretch;
  }
  .flow-tight .flow-box {
    min-height: 96px;
    padding: 10px 8px;
    font-size: 0.78em;
    display: flex;
    flex-direction: column;
    justify-content: center;
  }
  .flow-tight .flow-box h3 {
    font-size: 0.95em;
    margin: 0 0 0.2em;
  }
  .flow-tight .flow-box p {
    font-size: 0.92em;
    line-height: 1.2;
    margin: 0;
  }
  .option-row {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 18px;
    margin-top: 0.6em;
  }
  .option {
    background: rgba(255, 255, 255, 0.10);
    border: 1px solid rgba(255, 255, 255, 0.16);
    border-radius: 18px;
    padding: 18px;
    text-align: center;
    box-shadow: var(--panel-glow);
  }
  .option .opt-name {
    color: var(--color-accent);
    font-weight: 800;
    font-size: 1.05em;
    margin-bottom: 0.25em;
    display: block;
  }
  .option .opt-meta {
    font-size: 0.7em;
    color: var(--color-muted);
  }
  section.light .option {
    background: rgba(255, 255, 255, 0.92);
    border-color: rgba(102, 126, 234, 0.14);
    color: var(--color-text-dark);
  }
  section.light .option .opt-name {
    color: #4f6ae6;
  }
  section.light .option .opt-meta {
    color: #5a6a7a;
  }
  .next-card {
    background: rgba(255, 255, 255, 0.10);
    border: 1px solid rgba(255, 255, 255, 0.16);
    border-radius: 16px;
    padding: 14px 16px;
    margin-bottom: 12px;
  }
  .next-card h3 {
    font-size: 0.95em;
    margin: 0 0 0.2em;
  }
  .next-card p {
    margin: 0;
    font-size: 0.78em;
    color: var(--color-muted);
  }
  section.light .next-card {
    background: rgba(255, 255, 255, 0.92);
    border-color: rgba(102, 126, 234, 0.14);
  }
  section.light .next-card p {
    color: #5a6a7a;
  }
---

<!-- _class: lead -->
<!-- Speaker notes (Slide 1 - Hero). Track 3 is for DevOps, SRE, and platform engineers. Ninety minutes covering CI/CD with OIDC, headless mode driven by Copilot Coding Agent, multi-environment promotion, Azure Policy compliance, IaC export from existing resources, and the full lifecycle through teardown. Prerequisite: Track 2 onboarding or equivalent Git-Ape experience. -->

<div class="hero-grid">
<div>
<div class="eyebrow">Git-Ape - Track 3 - Platform Engineering</div>

# Platform Engineering

## CI/CD, headless mode, multi-environment, policy, lifecycle

### 90 minutes hands-on for DevOps, SRE, platform engineers

<div class="badge-row"><div class="badge">OIDC zero secrets</div><div class="badge">Headless mode</div><div class="badge">Multi-env</div><div class="badge">CIS / NIST</div></div>
</div>
<div class="hero-card center">

![w:84](../../website/static/img/logo.png)

### AI-powered cloud deployment

<div class="pill">9 slides</div><div class="pill">90 minutes</div><div class="pill">Platform</div>
</div>
</div>

---

<!-- _class: gradient -->
<!-- Speaker notes (Slide 2 - CI/CD). Four GitHub Actions workflows. git-ape-plan runs on every PR with a template change - it validates the template, runs what-if, and posts the plan as an idempotent PR comment that updates on each push. git-ape-deploy runs on merge to main or on a slash-deploy comment on an approved PR - it deploys as an Azure Deployment Stack with action-on-unmanage set to deleteAll, runs integration tests, and commits state.json back to the repo. git-ape-destroy runs when metadata.json status flips to destroy-requested. git-ape-verify is a manual workflow for checking OIDC and RBAC configuration. All four use OIDC federated identity - zero stored secrets, no AZURE_CREDENTIALS secret in the repo. -->

# CI/CD Architecture

## PR-based deployments with zero stored secrets

<div class="columns">
<div>

### Four GitHub Actions workflows

1. `git-ape-plan.yml` - validates PR, posts plan as comment
2. `git-ape-deploy.yml` - deploys on merge or `/deploy`
3. `git-ape-destroy.yml` - tears down when `metadata.json` flips to `destroy-requested`
4. `git-ape-verify.yml` - manual OIDC / RBAC check

<div class="badge-row"><div class="badge">OIDC federated identity</div><div class="badge">Azure Deployment Stacks</div></div>

</div>
<div class="panel">

### Pipeline flow

<img src="../shared/img/cicd-t3.svg" alt="CI/CD flow: PR -> git-ape-plan -> approve -> deploy with state.json committed -> destroy on request" style="width:100%;height:auto;display:block;" />

</div>
</div>

---

<!-- _class: light -->
<!-- Speaker notes (Slide 3 - Headless mode). This is the killer demo for platform teams. An engineer files a GitHub issue describing what they need. The Copilot Coding Agent picks it up, generates an ARM template on a branch, and opens a PR. The plan workflow validates and comments. A human reviewer approves and merges. Deployment runs and the result is posted back as a PR comment. No engineer typed a template, no engineer ran a CLI command, and the human gate is preserved at the approval step. This is self-service deployment with full audit trail. -->

# Headless Mode

## GitHub Issue to deployed infrastructure - no engineer typing

<div class="columns">
<div>

### The flow

1. File an issue describing what you need
2. **Copilot Coding Agent** generates ARM template on a branch
3. PR opened with architecture diagram and plan
4. `git-ape-plan` validates and posts the plan
5. Human reviewer approves the PR
6. Deploy on merge - results posted back as PR comment

</div>
<div class="panel">

### From issue to deployment

<img src="../shared/img/headless-t3.svg" alt="Headless flow: issue -> Copilot Coding Agent -> PR with plan -> reviewer approves -> deploy on merge with result comment" style="width:100%;height:auto;display:block;" />

</div>
</div>

---

<!-- _class: gradient -->
<!-- Speaker notes (Slide 4 - Multi-environment). The recommended pattern is one Azure subscription per environment. This gives you the strongest blast-radius isolation. Each environment has its own OIDC federated credential scoped to the corresponding GitHub environment. Promotion is governed by GitHub environment protection rules - dev is automatic, staging needs one approver, production needs two plus a wait timer. Parameter files are environment-specific. The same template deploys to all three with different SKUs and different secret references. -->

# Multi-Environment Strategy

## Dev to staging to prod with isolation

<div class="columns">
<div>

### Isolation model

- Separate **Azure subscriptions** per environment
- Environment-specific **parameter files**
- **GitHub environments** with protection rules
- OIDC credentials **scoped per environment**
- **Promotion requires PR approval** at each stage

</div>
<div class="panel">

### Per-environment scoping

<div class="next-card">
<h3>dev</h3>
<p>Automatic deploy on merge - sandbox subscription, B1 SKUs</p>
</div>

<div class="next-card">
<h3>staging</h3>
<p>One approver - staging subscription, S2 SKUs</p>
</div>

<div class="next-card">
<h3>prod</h3>
<p>Two approvers plus wait timer - prod subscription, P1v3 plus geo-redundancy</p>
</div>

</div>
</div>

---

<!-- _class: light -->
<!-- Speaker notes (Slide 5 - Policy and compliance). The Policy Advisor agent assesses templates against Azure Policy frameworks. The defaults are CIS Azure Foundations v3.0 and NIST SP 800-53 Rev 5; custom initiatives are also supported. The policy gate is advisory rather than blocking - it surfaces findings without halting deployment, which keeps it useful during the early adoption period. Enforcement mode starts at Audit, then graduates to Deny for Critical-severity policies once the audit baseline is clean. -->

# Policy and Compliance

## Azure Policy assessment with CIS, NIST, or custom initiatives

<div class="columns">
<div>

### What is assessed

- **Frameworks:** CIS Azure Foundations v3.0, NIST SP 800-53 Rev 5
- **Categories:** identity, networking, storage, compute, monitoring, tagging
- **Per-resource** policy recommendations
- **Audit vs Deny** enforcement modes

<div class="badge-row"><div class="badge">Advisory gate</div><div class="badge">Pre-deploy</div></div>

</div>
<div class="panel">

### Gate behaviour

<div class="metric">
<strong>Advisory</strong>
Surfaces findings without halting deployment - safe for adoption
</div>

<div class="metric">
<strong>Audit then Deny</strong>
Start audit-only, graduate to Deny for Critical policies once baseline is clean
</div>

<p class="note">Output artifacts: <code>policy-assessment.md</code> and <code>policy-recommendations.json</code> per deployment.</p>

</div>
</div>

---

<!-- _class: gradient -->
<!-- Speaker notes (Slide 6 - IaC export). Most enterprises already have Azure resources that were created click-by-click in the portal or by hand. The IaC Exporter agent reverse-engineers live Azure state into an ARM template you can bring into Git-Ape management. This bridges the gap between legacy and new - you do not need to recreate everything from scratch to start using Git-Ape. The exported template can then be diffed against live state to detect drift. -->

# IaC Export

## Bring existing Azure resources under Git-Ape management

<div class="columns">
<div>

### What it does

- **Export live Azure resources** to ARM templates
- **Reverse-engineer** existing infrastructure
- Bring **legacy deployments** under management
- **Compare exported template** against live state for drift

<div class="badge-row"><div class="badge">No greenfield required</div><div class="badge">Drift baseline</div></div>

</div>
<div class="panel">

### Typical adoption path

<div class="next-card">
<h3>1. Export</h3>
<p>Point the IaC Exporter at an existing resource group or subscription</p>
</div>

<div class="next-card">
<h3>2. Review</h3>
<p>Inspect the generated template, refactor parameters, add tags</p>
</div>

<div class="next-card">
<h3>3. Adopt</h3>
<p>Re-deploy as a stack - drift detection runs on every subsequent change</p>
</div>

</div>
</div>

---

<!-- _class: light -->
<!-- Speaker notes (Slide 7 - Lifecycle). Every deployment is tracked through a clear lifecycle: planning, deployed, drift-detected, reconciled, destroyed. The state lives in dot-azure-slash-deployments and is committed back to the repo, so the audit trail is preserved even after teardown. Teardown itself is PR-driven: a PR sets metadata.json status to destroy-requested, the PR is reviewed and approved (human gate for destructive action), and on merge the destroy workflow executes deletion via Azure Deployment Stacks with action-on-unmanage set to deleteAll. No orphans, idempotent re-runs. -->

# Lifecycle Management

## Create -> Deploy -> Monitor -> Teardown

<div class="columns">
<div>

### State progression

- **`planning`** -> template generated, not yet deployed
- **`deployed`** -> stack created, state.json committed
- **`drift-detected`** -> live state diverged from template
- **`reconciled`** -> drift resolved (template or live updated)
- **`destroyed`** -> stack deleted, audit trail preserved

</div>
<div class="panel">

### Teardown is PR-driven

<div class="next-card">
<h3>1. Open PR</h3>
<p>Set <code>metadata.json</code> status to <code>destroy-requested</code></p>
</div>

<div class="next-card">
<h3>2. Approve</h3>
<p>Human gate for destructive action - required reviewers on <code>azure-destroy</code> env</p>
</div>

<div class="next-card">
<h3>3. Merge -> auto-delete</h3>
<p><code>az stack sub delete --action-on-unmanage deleteAll</code> - no orphans, idempotent</p>
</div>

</div>
</div>

---

<!-- _class: gradient -->
<!-- Speaker notes (Slide 8 - Lab roadmap). Six labs across ninety minutes. Lab 1 is the CI/CD pipeline - this is the longest at twenty minutes and is the foundation for everything else. Lab 2 demonstrates headless mode from an issue. Lab 3 promotes from dev to staging. Lab 4 runs the policy assessment against your template. Lab 5 exports an existing resource group. Lab 6 closes the loop with PR-driven teardown. Labs 1, 2, and 6 are the most demonstrable; if running short on time, abbreviate Labs 4 and 5. -->

# Lab Roadmap

## Six labs across 90 minutes

| Lab | Time | What you do |
|-----|------|-------------|
| **1. CI/CD Pipeline** | 20 min | PR-based plan and deploy workflow |
| **2. Headless Mode** | 15 min | Issue triggers auto-PR and deploy |
| **3. Multi-Environment** | 15 min | Dev to staging promotion |
| **4. Policy Compliance** | 15 min | CIS / NIST assessment |
| **5. IaC Export** | 10 min | Export existing resources |
| **6. Destroy Lifecycle** | 5 min | PR-driven teardown |

<p class="note center">Labs 1, 2, and 6 are the highest-impact demos. If time slips, abbreviate Lab 4 or Lab 5.</p>

---

<!-- _class: light -->
<!-- Speaker notes (Slide 9 - Let's Go). Two quick checks before Lab 1. First, confirm OIDC and GitHub environments are configured from Track 2 Lab 1. Second, run the git-ape-verify workflow to confirm the federated credential is healthy. Then start Lab 1. Prerequisite: completed Track 2 or equivalent Git-Ape onboarding. -->

# Let's Go!

## Verify onboarding, then start Lab 1

<div class="option-row">
<div class="option">
<span class="opt-name">1. Confirm OIDC</span>
<p>From Track 2 Lab 1<br/>or onboarding playbook</p>
<div class="opt-meta">Federated credential + RBAC</div>
</div>
<div class="option">
<span class="opt-name">2. Verify</span>
<p>Run <code>git-ape-verify.yml</code><br/>manual workflow dispatch</p>
<div class="opt-meta">Health check, no deployment</div>
</div>
<div class="option">
<span class="opt-name">3. Lab 1</span>
<p>CI/CD pipeline<br/>20 minutes</p>
<div class="opt-meta">Foundation for the rest</div>
</div>
</div>

<p class="note center"><strong>Prerequisite:</strong> Completed Track 2 onboarding or equivalent Git-Ape experience.</p>
