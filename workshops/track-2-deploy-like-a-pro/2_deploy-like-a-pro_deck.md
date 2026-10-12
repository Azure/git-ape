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
<!-- Speaker notes (Slide 1 - Hero). Track 2 is for engineers and developers ready to deploy multi-resource architectures. This 60-minute session covers the agent architecture, the blocking security gate, CAF naming, real-pricing cost estimates, drift detection, and finishes with a hands-on lab that deploys a Web App with a SQL Database, Key Vault, and Application Insights. Prerequisites: a sandbox Azure subscription and completed onboarding (OIDC plus RBAC). -->

<div class="hero-grid">
<div>
<div class="eyebrow">Git-Ape - Track 2 - Deploy Like a Pro</div>

# Deploy Like a Pro

## Multi-resource Azure with security, cost, and drift built in

### 60 minutes hands-on for engineering teams

<div class="badge-row"><div class="badge">Security gate</div><div class="badge">Cost transparency</div><div class="badge">CAF naming</div><div class="badge">Drift detection</div></div>
</div>
<div class="hero-card center">

![w:84](../../website/static/img/logo.png)

### AI-powered cloud deployment

<div class="pill">9 slides</div><div class="pill">60 minutes</div><div class="pill">Engineers</div>
</div>
</div>

---

<!-- _class: gradient -->
<!-- Speaker notes (Slide 2 - Architecture). Git-Ape is not one model with one prompt. It is an orchestrated system of eight specialised agents. The orchestrator at the top coordinates the pipeline. Sub-agents do the heavy lifting (Requirements Gatherer, Template Generator, Resource Deployer). Advisory agents review templates (Principal Architect for the Well-Architected Framework, Policy Advisor for CIS and NIST). Utility agents handle peripheral tasks like IaC export and onboarding. Each agent invokes one or more of the 33 skills at the right moment of the pipeline. Emphasise that this is what makes Git-Ape produce trustworthy templates rather than plausible-looking ones. -->

# Git-Ape Architecture

## 8 agents, 33 skills, 4 workflows

<div class="columns">
<div>

### The orchestration model

- **Orchestrator** (`@git-ape`) coordinates the full pipeline
- **Sub-agents** do the work: Requirements, Template, Deployer
- **Advisory** review templates: Principal Architect (WAF), Policy Advisor (CIS/NIST)
- **Utility** handle peripheral tasks: IaC Export, Onboarding
- **Skills** are invoked at every stage - naming, security, cost, testing

</div>
<div class="panel">

### Agent topology

<img src="../shared/img/agents-t2.svg" alt="Agent architecture: orchestrator fans out to sub-agents, advisory agents, and utility agents; all draw on 33 shared skills and 4 workflows" style="width:100%;height:auto;display:block;" />

</div>
</div>

---

<!-- _class: light -->
<!-- Speaker notes (Slide 3 - Security gate). This is the slide that wins enterprise audiences. The security gate is BLOCKING - deployment literally cannot proceed if any Critical or High finding is unresolved. Every deployment ships with managed identities everywhere, HTTPS-only, TLS 1.2 minimum, FTP disabled, AAD-only SQL auth, and Key Vault references for every secret. In CI/CD, OIDC federated identity removes stored secrets entirely. The gate can be overridden but only with an explicit 'I accept the security risk' statement which is logged for audit. -->

# Security-First Approach

## Deployment stops if security fails

<div class="columns">
<div>

### What is enforced on every deployment

- **Blocking security gate** - Critical and High findings prevent deployment
- **Managed identities** everywhere - no connection strings, no shared keys
- **HTTPS-only**, TLS 1.2 plus, FTP disabled, AAD-only SQL auth
- **Key Vault references** for all secrets in app settings
- **OIDC federated identity** in CI/CD - zero stored secrets

</div>
<div class="panel">

### Gate behaviour

<img src="../shared/img/security-gate-t2.svg" alt="Security gate flow: template feeds the security analyzer which either passes deployment or blocks it pending fixes" style="width:100%;height:auto;display:block;" />

</div>
</div>

---

<!-- _class: gradient -->
<!-- Speaker notes (Slide 4 - CAF naming). Cloud Adoption Framework naming conventions are enforced automatically. The pattern is type abbreviation, then project, then environment, then region. Git-Ape validates names against length limits, allowed character sets, and uniqueness scope BEFORE you ever try to deploy. Naming conflicts surface during planning, not during the deployment failure at minute fifteen. This eliminates an entire category of preventable errors. -->

# CAF Naming Conventions

## Every resource named correctly, automatically

<div class="columns">
<div>

### The rules

- **Cloud Adoption Framework** naming enforced
- Pattern: `{type}-{project}-{env}-{region}`
- Validated for **length, characters, uniqueness**
- Naming conflicts caught **before deployment**

<div class="badge-row"><div class="badge">No deploy-time surprises</div><div class="badge">Consistent across teams</div></div>

</div>
<div class="panel">

### Live examples

<div class="next-card">
<h3>Function App</h3>
<p><code>func-orderapi-dev-eastus</code></p>
</div>

<div class="next-card">
<h3>Key Vault</h3>
<p><code>kv-orderapi-prod-eus</code> &nbsp;<span class="note">(shortened region - 24-char limit)</span></p>
</div>

<div class="next-card">
<h3>SQL Server</h3>
<p><code>sql-orderapi-prod-eastus</code></p>
</div>

</div>
</div>

---

<!-- _class: light -->
<!-- Speaker notes (Slide 5 - Cost transparency). The cost estimate uses the Azure Retail Prices API directly, so the numbers you see are the numbers you will be billed. This is not an averaged estimate. Per-resource monthly costs are broken down so you can identify which choices are expensive. The same template deployed at the dev SKU costs cents per month; at the production SKU it costs dollars. Engineers can model these trade-offs before any deployment occurs. -->

# Cost Transparency

## See what you pay before you deploy

<div class="columns">
<div>

### How the estimate works

- **Azure Retail Prices API** - real pricing, not averaged estimates
- **Per-resource monthly** cost breakdown
- Compare **dev vs prod SKUs** side by side
- Surfaced **before** the deploy commits

<div class="badge-row"><div class="badge">No billing surprises</div><div class="badge">Real numbers</div></div>

</div>
<div class="panel">

### Sample estimate (Web App + SQL + KV)

<div class="metric">
<strong>$12.40 /mo</strong>
Dev SKUs: App Service B1, SQL Basic, KV Standard
</div>

<div class="metric">
<strong>$184.20 /mo</strong>
Prod SKUs: P1v3, S2, KV Premium, App Insights
</div>

<p class="note">Numbers come straight from the Azure Retail Prices API - same numbers you'll see on the invoice.</p>

</div>
</div>

---

<!-- _class: gradient -->
<!-- Speaker notes (Slide 6 - What you build today). The lab today deploys a four-resource architecture: an App Service Plan and Web App, a SQL Server and Database with AAD-only authentication, a Key Vault for app secrets, and Application Insights for monitoring. Every connection between resources uses managed identity. There is no connection string in app settings, no SQL password anywhere. This is the secure default Git-Ape produces every time. -->

# What You Build Today

## Web App + SQL Database + Key Vault

<div class="columns">
<div>

### Resources

- **App Service Plan + Web App** with managed identity
- **SQL Server + Database** with AAD-only auth
- **Key Vault** for app secrets, accessed by RBAC
- **Application Insights** for monitoring and traces
- All connected via the **managed-identity chain**

<div class="badge-row"><div class="badge">Zero connection strings</div><div class="badge">Zero SQL passwords</div></div>

</div>
<div class="panel">

### Architecture

<img src="../shared/img/webapp-sql-t2.svg" alt="Web App with managed identity connects to SQL Database (AAD-only), Key Vault (RBAC), and Application Insights" style="width:100%;height:auto;display:block;" />

</div>
</div>

---

<!-- _class: light -->
<!-- Speaker notes (Slide 7 - Lab roadmap). Five labs across sixty minutes. Lab 1 is onboarding - OIDC plus RBAC plus GitHub environments - this is the foundation everything else builds on. Lab 2 is the main deployment - Web App with SQL. Lab 3 is the breaking-change exercise where you intentionally violate security and watch the gate block deployment. Lab 4 covers cost estimation and the WAF architecture review. Lab 5 demonstrates drift detection: change something manually in Azure, then watch Git-Ape find it. Pacing: Labs 1 and 2 are critical; if running short on time, abbreviate Lab 5. -->

# Lab Roadmap

## Five labs across 60 minutes

| Lab | Time | What you do |
|-----|------|-------------|
| **1. Onboarding** | 10 min | OIDC, RBAC, and GitHub environments |
| **2. Web App + SQL** | 15 min | Multi-resource deployment |
| **3. Security Deep Dive** | 10 min | Break security, gate blocks, fix |
| **4. Cost & Architecture** | 10 min | Cost estimate plus WAF review |
| **5. Drift Detection** | 5 min | Manual drift, detect, reconcile |

<p class="note center">Labs 1 and 2 are foundational. Labs 3-5 each stand alone, so abbreviate the last one if time slips.</p>

---

<!-- _class: gradient -->
<!-- Speaker notes (Slide 8 - Aha moment Lab 3). This is the most impactful lab in the track. Engineers see that security is not a report - it is an enforcement mechanism. Walk through the four steps: enable shared key access on a storage account (a common anti-pattern), watch the analyzer surface the finding, see the gate block deployment, then disable shared keys and rerun. The gate flips from blocked to passed. The lesson: security guardrails are real, not advisory. -->

# The Aha Moment

## What happens when you break security?

<div class="columns">
<div class="panel">

### Walk-through (Lab 3)

1. You enable **shared key access** on a Storage Account (anti-pattern)
2. Git-Ape Security Analyzer catches it: `SECURITY GATE: BLOCKED`
3. **Deployment is prevented** - no resource is created
4. You disable shared keys, re-run, gate flips to `SECURITY GATE: PASSED`

</div>
<div>

### Why this matters

<div class="next-card">
<h3>Security is enforced, not advisory</h3>
<p>The gate is the difference between "we have policies" and "policies actually run."</p>
</div>

<div class="next-card">
<h3>Same rules in dev and prod</h3>
<p>You catch the violation on your laptop, not in a production audit.</p>
</div>

<div class="next-card">
<h3>Override requires intent</h3>
<p>"I accept the security risk" is logged with justification. No silent bypass.</p>
</div>

</div>
</div>

---

<!-- _class: gradient -->
<!-- Speaker notes (Slide 9 - Let's Go). Three steps to get started. Open your development environment, sign in to Azure, and start with Lab 1. Codespaces and Dev Containers ship with all the prerequisites; local VS Code users should have run prereq-check ahead of time. Allow two to three minutes for environment startup. -->

# Let's Go!

## Open your environment and start Lab 1

<div class="option-row">
<div class="option">
<span class="opt-name">1. Open env</span>
<p>Codespaces<br/>Dev Containers<br/>or VS Code</p>
<div class="opt-meta">Tools pre-installed in containers</div>
</div>
<div class="option">
<span class="opt-name">2. az login</span>
<p>Standard browser<br/>or device code<br/>in Codespaces</p>
<div class="opt-meta">Use your sandbox subscription</div>
</div>
<div class="option">
<span class="opt-name">3. Lab 1</span>
<p>Onboarding<br/>OIDC + RBAC<br/>10 minutes</p>
<div class="opt-meta">Foundation for Labs 2-5</div>
</div>
</div>

<p class="note center">If you completed Track 1, you already have the environment ready - jump straight to <strong>az login</strong> and then <strong>Lab 1</strong>.</p>
