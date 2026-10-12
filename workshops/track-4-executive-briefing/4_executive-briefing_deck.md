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

<div class="hero-grid">
<div>
<div class="eyebrow">Git-Ape Executive Briefing</div>

# Deploy Azure Infrastructure

## With a Single Sentence

### Git-Ape for Engineering Leaders

<div class="badge-row"><div class="badge">Security gate</div><div class="badge">Cost visibility</div><div class="badge">Governance built in</div></div>
</div>
<div class="hero-card center">

![w:84](../../website/static/img/logo.png)

### AI-powered cloud deployment

<div class="pill">Executive briefing</div><div class="pill">10 slides</div><div class="pill">Live demo ready</div>
</div>
</div>

---

<!-- _class: gradient -->

# The Challenge

## Cloud Deployment Is Your Biggest Bottleneck

<div class="split-hero">
<div class="stat-stack">
<div class="metric">
<strong>73%</strong>
teams wait days for infrastructure changes
</div>
<div class="metric">
<strong>$4.35M</strong>
average cost of a cloud breach incident
</div>
</div>
<div class="hero-card">

### The executive problem

- **Shadow IT** grows when the approved path is too slow.
- **Security exposure** rises when changes skip guardrails.
- **Cost surprises** arrive after deployment, not before it.

<div class="badge-row"><div class="badge">Delay</div><div class="badge">Risk</div><div class="badge">Unplanned spend</div></div>
</div>
</div>

---

# What If Deployment Was This Easy?

## One Sentence. Production-Ready Infrastructure.

<div class="columns">
<div class="panel">

### Input

> "Deploy a web app with SQL database for the inventory app in production"

</div>
<div class="panel compact">

### Output in 2 minutes

- **7 resources** scaffolded
- **12 security checks** passed
- **$92/month** estimated cost
- **Architecture diagram** generated
- **Deployment** validated and tested

</div>
</div>

<div class="badge-row"><div class="badge">7 resources</div><div class="badge">12 checks passed</div><div class="badge">$92/month estimate</div></div>

---

<!-- _class: gradient -->

# Built-In Security Guardrails

## Security Is Not Optional — It's Enforced

<div class="columns compact">
<div class="panel">

### Deployment stops when

- Critical findings exist
- High-risk settings are misconfigured
- Required controls are missing

</div>
<div class="panel">

### Default controls

- Managed identities — no passwords
- HTTPS and TLS 1.2+ enforced
- Azure AD auth for databases
- Key Vault for all secrets

</div>
</div>

<p class="note narrow">The key point for leadership: insecure defaults are removed from the deployment path, not left to individual engineers.</p>

---

<!-- _class: light -->

# Cost Transparency

## Know What You Pay Before You Deploy

<div class="columns">
<div>

- **Live estimates** from the Azure Retail Prices API
- **Per-resource monthly breakdown** for clear review
- **SKU comparisons** for dev and production sizing
- **PR visibility** so reviewers see price before approval

</div>
<div class="metric center">
<strong>$45 - $120</strong>
typical monthly range for Function App + Storage + Monitoring
</div>
</div>

<p class="note">The point is not perfect prediction. It is cost visibility early enough to change the plan.</p>

---

<!-- _class: gradient -->

# Compliance and Governance

## CIS, NIST, and Custom Policy — Automated

<div class="columns compact">
<div class="panel">

### Coverage

- **CIS Azure Foundations v3.0**
- **NIST SP 800-53**
- **Custom enterprise policy** sets

</div>
<div class="panel">

### Outcomes

- Per-resource compliance scoring
- Audit trail for every deployment
- Drift detection for manual changes
- Audit or deny enforcement modes

</div>
</div>

<div class="icon-grid narrow">
<div class="icon-tile">
<span style="font-size:2em;display:block;margin-bottom:6px">🛡️</span>
<p>Policy checks before approval</p>
</div>
<div class="icon-tile">
<span style="font-size:2em;display:block;margin-bottom:6px">📋</span>
<p>Evidence trail for audits</p>
</div>
</div>

---

<!-- _class: light -->

# Architecture Quality

## AI-Powered Well-Architected Framework Review

<div class="columns compact">
<div>

1. **Security** — identity, encryption, access control
2. **Reliability** — monitoring, backup, resiliency
3. **Performance** — right-sizing and scaling

</div>
<div>

<ol start="4">
<li><strong>Cost</strong> — waste reduction and tier fit</li>
<li><strong>Operational excellence</strong> — IaC, observability, runbooks</li>
</ol>

</div>
</div>

<div class="metric">The AI evaluates each deployment like an experienced cloud architect before it reaches production.</div>

---

<!-- _class: agenda gradient -->

# How It Works

## A Conversation, Not a Configuration File

<div class="flow">
<div class="flow-box">

### Ask

Describe the workload in plain English

</div>
<div class="arrow">→</div>
<div class="flow-box">

### Clarify

Answer a few questions on env, region, scale

</div>
<div class="arrow">→</div>
<div class="flow-box">

### Review

Security, cost, and architecture outputs

</div>
<div class="arrow">→</div>
<div class="flow-box">

### Deploy

Approve and deploy, or stop at review

</div>
</div>

<p class="note">No ARM templates to write. No CLI sequence to memorize.</p>

---

<!-- _class: gradient -->

# Demo Time

## Watch It Deploy Live

<div class="columns compact">
<div class="panel">

### We will show

1. One-sentence request
2. Clarifying answers
3. Security, cost, architecture outputs
4. Deployment confirmation

</div>
<div class="panel">

### Demo target

**Python Function App** with storage and monitoring in **about 2 minutes**

<p class="note">Pre-recorded backup available if network latency gets theatrical.</p>

</div>
</div>

---

<!-- _class: roi gradient -->

# Results and ROI

## What Engineering Leaders Get

| Benefit | Impact |
|---------|--------|
| **Faster deployment** | Days to hours, or minutes for simple workloads |
| **Fewer incidents** | Guardrails and blocking security gates |
| **Cost predictability** | Estimates before approval |
| **Governance at scale** | Audit trail, drift detection, policy enforcement |
| **Team autonomy** | Less waiting on a central platform queue |

<div class="metric center"><strong>Bottom line</strong><p>More deployments. Fewer emergencies. Better control.</p></div>

---

<!--
Speaker Notes for Slide 1: Title Slide
---
Set the stage. Emphasize this is about solving a real engineering leadership problem.
Say: "In the next 10 minutes, I'll show you how AI can turn infrastructure deployment from a bottleneck into a competitive advantage."

Speaker Notes for Slide 2: The Challenge
---
Pause after each stat. Let the pain sink in.
Internal survey proxy: We can cite IBM, Forrester, or Gartner for 73% if needed.
Shadow IT is often the biggest surprise to executives. They don't realize developers are bypassing governance.

Speaker Notes for Slide 3: What If...
---
This is the "aha" moment. Let silence hang for 2–3 seconds after reading the output.
Say: "What you see here is the result of a single sentence, not hours of engineering work."

Speaker Notes for Slide 4: Security Guardrails
---
This is crucial. Executives are terrified of security incidents. Emphasize:
- "Blocking gate" means the deployment literally cannot proceed if security fails.
- No passwords = no breach surface. Managed identities eliminate the #1 attack vector.
- OIDC federated = GitHub Actions can deploy without storing Azure credentials in secrets.

Speaker Notes for Slide 5: Cost Transparency
---
Say: "Developers see the cost before they deploy, not after it appears on the bill."
This addresses CFO concerns about runaway cloud spend.

Speaker Notes for Slide 6: Compliance and Governance
---
For heavily regulated industries (finance, healthcare, government): This is the slide they care about most.
Drift detection is underrated. It catches the developer who SSHes into a VM and changes config manually.
Audit trail = compliance audit evidence.

Speaker Notes for Slide 7: WAF Review
---
Briefly touch the 5 pillars. Don't dwell unless audience asks.
Say: "The AI evaluates every deployment like a seasoned architect would."

Speaker Notes for Slide 8: How It Works
---
Demystify the process. Emphasize it's a conversation, not a form.
Say: "This is what makes it different from traditional IaC tools. You don't need to know Bicep, Terraform, or ARM template syntax."

Speaker Notes for Slide 9: Demo
---
If live demo:
  - Ensure font size is large (Ctrl+= three times).
  - Have terminal and Copilot Chat visible.
  - Type slowly so audience can read.
  - Highlight the three outputs: architecture diagram, security analysis, cost estimate.
  
If pre-recorded backup:
  - Play video.
  - Pause at key moments (security gate, cost, architecture).
  - Talk through what you're seeing.

Key moments to narrate during demo:
  - "One sentence" — emphasize the input is minimal.
  - "It asks clarifying questions" — show how it's a conversation.
  - "Architecture diagram" — this is auto-generated, not hand-drawn.
  - "Security gate PASSED" — this is the most important part.
  - "Cost estimate" — executives care about this.

Speaker Notes for Slide 10: ROI
---
Wrap up with business outcomes.
Say: "This isn't just about speed. It's about safety, predictability, and giving your engineering team superpowers."
End with a call to action: "Questions?" or "Let me show you how to get started."
-->
