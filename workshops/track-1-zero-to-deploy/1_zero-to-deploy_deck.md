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
<!-- Speaker notes (Slide 1 — Hero). Welcome the room and frame the session: this is a 30-minute hands-on intro for enterprise teams. By the end of the session every attendee will have deployed real Azure infrastructure using one English sentence. No prior ARM, Bicep, or Terraform knowledge is required. Before starting, confirm everyone has GitHub Codespaces, Dev Containers, or VS Code open, and that Copilot is signed in. -->

<div class="hero-grid">
<div>
<div class="eyebrow">Git-Ape - Track 1 - Zero to Deploy</div>

# Deploy Azure Infrastructure

## With a Single Sentence

### A 30-minute hands-on intro for enterprise teams

<div class="badge-row"><div class="badge">No cloud expertise needed</div><div class="badge">Runs in your browser</div><div class="badge">Hands-on lab</div></div>
</div>
<div class="hero-card center">

![w:84](../../website/static/img/logo.png)

### AI-powered cloud deployment

<div class="pill">6 slides</div><div class="pill">30 minutes</div><div class="pill">Beginner friendly</div>
</div>
</div>

---

<!-- _class: gradient -->
<!-- Speaker notes (Slide 2 — What Is Git-Ape?). Lead with the value: Git-Ape turns plain English into production-ready Azure infrastructure. It is built on GitHub Copilot, so it lives inside the tools engineers already use — VS Code or the browser. On every deployment three things happen automatically: a security review, a real-pricing cost estimate, and an architecture diagram. Emphasise that no cloud expertise is required by the requester — this is designed for application developers, not infrastructure specialists. Pause for any quick questions before moving on. -->

# What Is Git-Ape?

## Deploy Azure infrastructure with a sentence

<div class="columns">
<div>

### The idea

- An **AI assistant** that turns plain English into production-ready Azure infrastructure
- Built on **GitHub Copilot** - works in VS Code or the browser
- Handles **security, cost estimation, and architecture** automatically
- **No cloud expertise required** for the requester

</div>
<div class="panel">

### From sentence to deployment

<div class="flow-tight">
<div class="flow-box"><h3>Say</h3></div>
<div class="arrow">&rarr;</div>
<div class="flow-box"><h3>Plan</h3></div>
<div class="arrow">&rarr;</div>
<div class="flow-box"><h3>Gate</h3></div>
<div class="arrow">&rarr;</div>
<div class="flow-box"><h3>Ship</h3></div>
</div>

<p class="note center">Cost estimate and architecture diagram come for free.</p>

</div>
</div>

---

<!-- _class: light -->
<!-- Speaker notes (Slide 3 — How It Works). This is the most important slide for the early wow moment. Git-Ape is a conversation, not a wizard. Walk through the four steps in order. Stress that step two, the clarifying questions, is the secret to producing correct templates without forcing the requester to know Azure. The sample conversation on the right shows exactly what attendees will type in Lab 2. Remind attendees that three artifacts always come back regardless of whether they deploy: security report, cost estimate, and architecture diagram. Deployment itself is opt-in — they can stop at the artifacts. -->

# How It Works

## A conversation, not a configuration file

<div class="columns">
<div>

### Four steps, in plain English

1. **You describe** what you need
2. **Git-Ape asks** clarifying questions - region, environment, project name
3. **Git-Ape generates** the template, security report, and cost estimate
4. **You confirm** - it deploys, or you keep the artifacts without deploying

</div>
<div class="panel">

### Sample conversation

```text
@git-ape deploy a Python function
app for the inventory project in dev
```

<p class="mini">&rarr; Region? <strong>eastus</strong></p>
<p class="mini">&rarr; Storage SKU? <strong>Standard_LRS</strong></p>
<p class="mini">&rarr; Enable monitoring? <strong>Yes</strong></p>

<div class="badge-row"><div class="badge">Security pass</div><div class="badge">Cost ~$0.40/mo</div><div class="badge">Diagram</div></div>

<p class="note">Use your own words. No forms. No wizards.</p>

</div>
</div>

---

<!-- _class: gradient -->
<!-- Speaker notes (Slide 4 — What You'll Build Today). Today's lab deploys a Python Function App with a Storage Account and Application Insights. Highlight that every connection uses managed identity — zero secrets in code, zero connection strings, zero shared keys. Estimated cost is well under one dollar a month for light use; Storage at LRS is the largest line item. The architecture diagram on the right is generated automatically by Git-Ape — attendees will see this exact pattern emerge from their own prompt in Lab 2. -->

# What You'll Build Today

## A Python Function App on Azure

<div class="columns">
<div>

### Resources

- **Function App** - serverless, runs your code on demand
- **Storage Account** - backing storage (blob + queue)
- **Application Insights** - built-in monitoring & logs
- **Managed identity** - no passwords stored anywhere

<div class="badge-row"><div class="badge">Serverless</div><div class="badge">~$1/month light use</div><div class="badge">Identity-based auth</div></div>

</div>
<div class="panel">

### Architecture

<img src="../shared/img/arch-functionapp-t1.svg" alt="Function App architecture: HTTP trigger flows into the Function App, which writes to Storage and emits telemetry to Application Insights, all secured with managed identity" style="width:100%;height:auto;display:block;" />


</div>
</div>

---

<!-- _class: gradient -->
<!-- Speaker notes (Slide 5 — Let's Go). Three environment options. All produce the same outcome. Codespaces is fastest for first-time attendees — no install, runs entirely in the browser. Dev Containers is the best fit for engineers who already use VS Code with Docker and want a fully local environment. VS Code Local works for experienced users who already have the prerequisites installed. Give the room two to three minutes to launch their environment and help any stragglers. Then point them to Lab 1: Setup in the lab guide. -->

# Let's Go!

## Set up your environment in 2 minutes

<div class="option-row">
<div class="option">
<span class="opt-name">GitHub Codespaces</span>
<p>Browser only<br/>~30s if cached<br/>Zero install</p>
<div class="opt-meta">Recommended for first-time users</div>
</div>
<div class="option">
<span class="opt-name">Dev Containers</span>
<p>VS Code + Docker<br/>Tools pre-installed<br/>Local environment</p>
<div class="opt-meta">Best for offline use</div>
</div>
<div class="option">
<span class="opt-name">VS Code Local</span>
<p>Your machine<br/>Install tools manually<br/>Full control</p>
<div class="opt-meta">For experienced users</div>
</div>
</div>

<p class="note center">Container-based options ship with Azure CLI, Bicep, GitHub CLI, Node, Python, .NET, and every Git-Ape skill pre-installed. Open the lab guide and start with <strong>Lab 1: Setup</strong>.</p>

---

<!-- _class: light -->
<!-- Speaker notes (Slide 6 — Recap & Next Steps). Quick recap: in thirty minutes attendees deployed Azure infrastructure with one sentence, got an automatic security review with a blocking gate, saw a real-pricing cost estimate, and generated an architecture diagram. No ARM templates were written by hand. No portal clicks. This is the value proposition in concrete form. Point engineers and developers to Track 2 for multi-resource architectures and a security deep dive. Point DevOps and platform engineers to Track 3 for CI/CD, headless mode, and policy compliance. Finally, share the GitHub repository for documentation and community. Open the floor to questions or a volunteer demo if time permits. -->

# Recap & Next Steps

## What you just did

<div class="columns">
<div class="panel">

### In 30 minutes you

- Deployed Azure infrastructure with **one sentence**
- Got an automatic **security review** with a blocking gate
- Saw a **cost estimate** from real Azure pricing
- Generated an **architecture diagram**

<div class="badge-row"><div class="badge">No ARM templates written</div><div class="badge">No portal clicks</div></div>

</div>
<div>

### Where to go next

<div class="next-card">
<h3>Track 2 - Deploy Like a Pro</h3>
<p>Multi-resource architectures, security deep dive (60 min)</p>
</div>

<div class="next-card">
<h3>Track 3 - Platform Engineering</h3>
<p>CI/CD, headless mode, policy compliance (90 min)</p>
</div>

<div class="next-card">
<h3>Documentation</h3>
<p>github.com/Azure/git-ape</p>
</div>

</div>
</div>
