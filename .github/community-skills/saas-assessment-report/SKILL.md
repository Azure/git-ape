---
name: saas-assessment-report
metadata:
  author: dawright22
description: "Orchestrates a comprehensive SaaS platform assessment against WAF, CAF, CIS, NIST, PCI-DSS, HIPAA, SOC 2, FedRAMP, and SaaS maturity frameworks. Generates a print-ready HTML report (save as PDF from browser). Use when the user wants to assess a SaaS repo, generate a compliance report, or audit an Azure SaaS platform."
argument-hint: "Path to the repo to assess, or 'current' for the active workspace"
user-invocable: true
last_updated: "2026-08-28"
---

# SaaS Assessment Report Skill

## Purpose

Runs a full-spectrum assessment of a SaaS application repository and produces a single print-ready HTML report that can be saved as PDF. This skill **orchestrates existing skills** — it does not duplicate their logic.

## When to Use

- User asks to "assess", "audit", "review", or "score" a SaaS repo
- User wants a compliance report (NIST, CIS, PCI, HIPAA, SOC 2, FedRAMP)
- User wants a WAF/CAF assessment of their SaaS platform
- User asks for a "readiness report" or "go-live checklist"

## Workflow

### Phase 1: Discovery (read-only)

Scan the repository to build an inventory:

1. **Infrastructure** — Find IaC files (Bicep, ARM, Terraform) under `infra/`, `.azure/`, or root
2. **Application code** — Identify language, framework, Dockerfile, package manifests
3. **Existing docs** — Check for prior skill outputs in `docs/` (tenant-isolation-model.md, security-and-compliance.md, scale-and-sre.md, etc.)
4. **CI/CD** — Check `.github/workflows/`, `azure-pipelines.yml`, or similar
5. **Config** — Environment variables, Key Vault references, connection strings

### Phase 2: Run Assessments

Invoke each skill/agent and collect structured results. **Use existing doc artifacts if they exist** — don't re-run a skill if its output is already in the repo and still current.

| # | Skill / Agent | Assessment Area | Output Key |
|---|---------------|-----------------|------------|
| 1 | `azure-principal-architect` | WAF 5-pillar review | `waf` |
| 2 | `isv-landing-zone-foundation` | CAF landing zone alignment | `caf` |
| 3 | `tenant-isolation-models` | Isolation model evaluation | `isolation` |
| 4 | `multi-tenant_SaaS` | SaaS architecture maturity | `saas_maturity` |
| 5 | `security-and-compliance` | Security controls & threat model | `security` |
| 6 | `scale-and-sre` | SRE readiness & observability | `sre` |
| 7 | `tenant-lifecycle-automation` | Lifecycle automation | `lifecycle` |
| 8 | `fulfillment-and-metering` | Marketplace billing | `billing` |
| 9 | `deployment-blueprints` | Deployment topology | `topology` |
| 10 | `marketplace-onboarding` | Marketplace readiness | `marketplace` |
| 11 | `azure-security-analyzer` | Per-resource IaC security | `iac_security` |
| 12 | `azure-policy-advisor` | Azure Policy compliance | `policy` |
| 13 | `azure-compliance` | CIS/NIST/FedRAMP controls | `compliance` |
| 14 | `azure-cost-estimator` | Cost estimate | `cost` |

### Phase 3: Score & Classify

Score each area 1–5 using evidence from the repo. Classify every finding:

| Severity | Meaning | Timeline |
|----------|---------|----------|
| 🔴 Critical | Blocks production, unacceptable risk | Fix before deploy |
| 🟠 High | Should fix before GA | 30 days |
| 🟡 Medium | Address post-launch | 60–90 days |
| 🟢 Low | Nice-to-have improvement | Backlog |

### Phase 3.5: Generate Recommended Architecture Diagram

Based on assessment findings, generate a **recommended reference architecture diagram** (Mermaid) reflecting current state plus remediation recommendations.

**Inputs:** IaC templates, app code structure, existing docs (tenant-isolation-model.md, deployment-blueprints.md, security-and-compliance.md), discovered Azure services.

**Diagram must include:**
- All Azure services discovered in the repo (App Service, Cosmos DB, Storage, Key Vault, OpenAI, Front Door, etc.)
- Multi-tenant architecture boundaries (shared compute, isolated data)
- Network topology (VNet, subnets, private endpoints, Front Door/WAF)
- Identity and access flow (Entra ID B2C, managed identities, RBAC)
- Data flow direction arrows (ingestion → processing → storage → output)
- Observability stack (App Insights, Log Analytics)
- SaaS control plane vs. data plane separation
- Marketplace integration points (landing page, webhook, fulfillment API)

**Annotate with assessment findings:**
- 🟢 Components that passed assessment checks
- 🟡 Components with gaps (show what's missing)
- 🔴 Components with critical issues (highlight remediation needed)

**Skills to invoke:**
- `azure-resource-visualizer` — if live Azure resources exist, generate from deployed state
- `deployment-blueprints` — match to closest SaaS reference topology phase
- `azure-principal-architect` — WAF-aligned review of the architecture

**Output:** Mermaid diagram embedded in the report + saved as standalone file at `.azure/assessments/architecture-diagram-YYYY-MM-DD.md`.

### Phase 4: Generate Report

Build a **self-contained HTML file** using the `web-artifacts-builder` Clawpilot theme. The HTML must include `@media print` styles for clean PDF output.

#### Report Sections

1. **Cover Page** — Repo name, assessment date, assessor, overall score
2. **Executive Summary** — Composite score (1–100), top 5 critical gaps, top 5 strengths, 30/60/90 day priorities
3. **WAF Scorecard** — Radar chart + per-pillar detail
4. **CAF Compliance** — Naming, landing zone, governance, identity baseline
5. **Recommended Architecture Diagram** — Mermaid diagram showing current Azure services, multi-tenant boundaries, network topology, identity flow, data flow, and SaaS control/data plane separation. Annotated with assessment findings (🟢/🟡/🔴).
6. **SaaS Maturity** — Isolation, lifecycle, billing, marketplace, topology
6. **Regulatory Compliance Matrix** — Cross-framework table:

```
| Control ID | Description | NIST | CIS | PCI | HIPAA | SOC2 | FedRAMP | Status | Evidence |
```

7. **Security Deep-Dive** — Controls matrix, threat model summary, isolation test coverage
8. **SRE Readiness** — SLO/SLI, observability, autoscaling, DR, noisy-neighbor
9. **Cost Analysis** — Per-resource estimate, optimization recommendations
10. **Action Plan** — 30/60/90 day roadmap with owners and effort (S/M/L)
11. **Appendix** — Full findings list, file references, methodology notes

#### Regulatory Frameworks to Map

| Framework | Focus | Key Controls |
|-----------|-------|-------------|
| **CIS Azure Foundations v2.1** | Azure-specific hardening | IAM, networking, storage, database, logging, VM |
| **NIST 800-53 Rev 5 (Moderate)** | Federal baseline | AC, AU, CM, IA, IR, SC, SI families |
| **PCI DSS v4.0** | Payment card data | CDE scope, encryption, access, logging, pen testing |
| **HIPAA / HITRUST** | Health data (PHI) | Encryption, access controls, BAA, breach notification |
| **SOC 2 Type II** | Trust services | Security, availability, processing integrity, confidentiality, privacy |
| **FedRAMP (Moderate)** | Government cloud | FIPS 140-2, continuous monitoring, POA&M |
| **ISO 27001:2022** | InfoSec management | Annex A controls (organizational, people, physical, technological) |
| **Azure Well-Architected** | Cloud architecture | Security, reliability, performance, cost, ops |
| **Azure CAF** | Cloud adoption | Naming, governance, landing zones, identity |

### Phase 5: Save & Convert

1. Save HTML to `.azure/assessments/saas-assessment-YYYY-MM-DD.html`
2. Tell user: **Open the HTML in a browser → Print → Save as PDF**
3. If `pandoc` or headless Chrome is available, auto-convert:
   ```bash
   # Option A: Chrome headless (best fidelity)
   chrome --headless --print-to-pdf=report.pdf --no-margins report.html

   # Option B: Edge headless
   msedge --headless --print-to-pdf=report.pdf --no-margins report.html

   # Option C: pandoc (simpler, less styling)
   pandoc report.html -o report.pdf --pdf-engine=wkhtmltopdf
   ```

## Print-Optimized CSS Requirements

The HTML report MUST include these print styles:

```css
@media print {
  body { font-size: 11pt; color: #000; background: #fff; }
  .no-print { display: none; }
  h1, h2, h3 { page-break-after: avoid; }
  table, figure, .card { page-break-inside: avoid; }
  .page-break { page-break-before: always; }
  @page { margin: 0.75in; size: letter; }
  @page :first { margin-top: 0; } /* Cover page */
}
```

## Scoring Methodology

### Per-Framework Score (1–5)

| Score | Meaning |
|-------|---------|
| 1 | Not addressed — no evidence in repo |
| 2 | Minimal — some awareness, major gaps |
| 3 | Partial — key controls present, gaps remain |
| 4 | Strong — most controls in place, minor improvements needed |
| 5 | Exemplary — comprehensive implementation, tested |

### Composite Score (1–100)

Weighted average across all frameworks:

| Category | Weight | Components |
|----------|--------|------------|
| WAF | 25% | Average of 5 pillar scores × 4 |
| CAF | 10% | Naming + landing zone + governance |
| SaaS Maturity | 20% | Isolation + lifecycle + billing + marketplace |
| Regulatory | 25% | Average of applicable framework scores × 4 |
| SRE | 10% | SLO + observability + scaling + DR |
| Cost | 10% | Right-sizing + optimization |

## Example Invocation

```
@git-ape /saas-assessment-report current
@git-ape /saas-assessment-report https://github.com/org/saas-app
@git-ape /saas-assessment-report . --frameworks waf,nist,cis,pci
```
