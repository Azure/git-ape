---
name: csd-assessment-report
description: "Assesses ISV readiness for Microsoft Solutions Partner with Certified Software Designations (CSD). Evaluates Marketplace readiness, technical interoperability, customer success metrics, and Industry AI alignment. Generates a print-ready HTML report (save as PDF). Use when assessing CSD readiness for Azure, Business Applications, Modern Work, Security, or Industry AI designations."
argument-hint: "Path to the repo to assess, target designation (azure, bizapps, modernwork, security, industry-ai), or 'current' for active workspace"
user-invocable: true
last_updated: "2026-08-28"
---

# Certified Software Designation (CSD) Assessment Skill

## Purpose

Evaluates an ISV's SaaS solution and repository against Microsoft's **Solutions Partner with Certified Software Designations** program requirements. Produces a readiness report with clear scoring, gap analysis, and actionable next steps for each qualification pillar.

## Source Documentation

- [Introduction to CSD](https://learn.microsoft.com/en-us/partner-center/referrals/solutions-partner-certified-software-designations-introduction)
- [Solution Area Requirements](https://learn.microsoft.com/en-us/partner-center/referrals/solutions-partner-certified-software-solution-area)
- [Industry AI Requirements](https://learn.microsoft.com/en-us/partner-center/referrals/solutions-partner-certified-software-industry-ai)
- [Azure Technical Audit](https://aka.ms/Certifiedsoftware_audit_Azure)
- [Industry AI Playbook](https://assetsprod.microsoft.com/en-us/solutions-partner-with-certified-software-industry-ai-playbook.pdf)

## When to Use

- ISV asks "am I ready for certified software?"
- Partner wants to assess CSD qualification gaps
- Pre-audit readiness check before scheduling Partner Center technical audit
- Planning roadmap to achieve a certified software designation

## Designation Pathways

### Solution Area Designations

| Designation | Technical Requirement | Marketplace Requirement |
|---|---|---|
| **Azure** | Technical audit: Data Ops, AI/ML Integration, Customer Deployed Services, Control Plane/DevOps | Azure IP co-sell eligible |
| **Business Applications** | Technical audit: feature overlap, operational excellence, data handling | Business Applications co-sell eligible |
| **Modern Work** | Microsoft 365 App Compliance Program certification | Listed in Marketplace (transactability not required) |
| **Security** | Sentinel Content Hub publishing or MISA membership | Azure IP co-sell eligible |

### Industry AI Designations

| Designation | Industries |
|---|---|
| **Industry AI** | Healthcare, Retail, Financial Services, Manufacturing, Sustainability, Energy, Telecom/Media, Government, Education, Defense & Intelligence, Non-Profit |

Industry AI requires the solution area technical audit **plus** an AI Pattern audit (Copilot Agents, Fabric Solutions, or AI Model/Service).

## Assessment Framework

### Pillar 1: Microsoft Marketplace Readiness

Evaluate the solution's Marketplace presence and transactability:

| Check | Azure | BizApps | Modern Work | Security | Industry AI |
|---|---|---|---|---|---|
| Offer published in Marketplace | Required | Required | Required | Required | Required |
| Transactable offer (SaaS, VM, Container, Managed App) | Required | Not yet required | Not yet required | Required | Required |
| IP co-sell eligible | Required | BizApps co-sell | N/A | Required | Required |
| Offer listing quality (description, screenshots, videos) | Best practice | Best practice | Best practice | Best practice | Best practice |
| Plans and pricing configured | Required | Required | Listed | Required | Required |

**What to check in the repo:**
- `marketplace.json`, `plugin.json`, or Partner Center config references
- Marketplace offer metadata in docs (offer ID, plans, pricing)
- Landing page and webhook endpoints for SaaS fulfillment
- Fulfillment API integration code
- Co-sell materials (solution one-pager, reference architecture)

### Pillar 2: Azure Technical Audit (Ver 2.2)

Based on **Azure_Technical_Audit_Certification_Requirements Ver 2.2**. The audit has two sections: **General Requirements** (all solutions) and **Workflow Category Requirements** (pick one category).

#### Section 1: General Requirements (ALL solutions must pass)

| Req ID | Requirement | Evidence Needed | What to Check in Repo |
|---|---|---|---|
| **1.1** | **Architecture Design** — Reference architecture diagram showing solution details and end-customer integration points. Must follow Partner Center diagram requirements. Granularity at Azure service level with direction of operation. | PDF/PNG diagram | Architecture diagrams in `docs/`, Mermaid diagrams, reference architecture files |
| **1.2** | **Deployed Architecture Review** — Pre-recorded demo or live session showing deployed components in Azure Portal matching the architecture diagram. MP4 format, 720p+, <10min, <500MB. | Screen recording or live session | Demo videos, deployment scripts that prove running infrastructure |
| **1.3** | **WAF Review** — Complete Azure Well-Architected Review self-assessment. **Minimum score: Moderate** for Reliability, Security, and Operational Excellence. SaaS solutions should also complete the WAF SaaS workload assessment. Alternative: WARA/WASA results. | WAF assessment results | Existing WAF assessment docs, `docs/scale-and-sre.md`, `docs/security-and-compliance.md` |
| **1.4** | **Azure Advisor Score** — **Minimum: Moderate** for Reliability, Security, and Operational Excellence for production subscriptions. Export CSV/PDF from Azure Advisor overview. | Screenshot/CSV/PDF of Advisor score | Azure Advisor export files, remediation tracking docs |
| **1.5** | **Cloud Security Posture Management (CSPM)** — Score from CSPM platform (e.g., Microsoft Defender for Cloud Secure Score) from last 30 days. **No critical impact recommendations** allowed. Alternative: active security certification. | CSPM score screenshot or active certification | Defender for Cloud config, security cert docs |

**Accepted security certifications for 1.5 alternative:**
- FedRAMP Moderate or High
- SOC 2 or 3
- ISO 27001
- HITRUST CSF
- SWIFT CSCF
- CMMC 2.0 Level 2 or Level 3

#### Section 2: Workflow Category Requirements (complete ONE category)

Partners must identify which **single** workflow category best fits their solution and complete all sub-requirements within it.

##### Workflow Category Selection Guide

| Category | Select If Your Solution... |
|---|---|
| **2.1 Data Operations & Management** | Works with end customer data, data services, storage, management, or processing as a primary function |
| **2.2 AI/ML Integration** | Provides AI interoperability or interaction with end customer data or compute (e.g., copilot services, analytics with ML). **Also requires completing 2.1 Data Ops** |
| **2.3 Customer Deployed Services** | Deploys components (VMs, containers, agents, managed apps) into end customer's Azure environment |
| **2.4 Control Plane, Orchestration & DevOps** | Provisions, modifies, or orchestrates end customer Azure resources for scalability, performance, resilience, or deployment automation |

##### 2.1 Data Operations & Management

| Req ID | Requirement | Attestation Format |
|---|---|---|
| **2.1-1** | **End customer data ingestion** — Support ingestion from customer-owned sources (Azure services, on-prem, file uploads, REST endpoints) | Yes-Explain / Yes-Evidence / No-Explain |
| **2.1-2** | **Data processing handled within Azure** — All processing, transformation, operations on Azure-hosted services (partner or customer tenant). No core processing on other clouds or on-prem. | Yes-Explain / Yes-Evidence / No-Explain |
| **2.1-3** | **End customer data residency within Azure** — All collected data stored within Azure. Must comply with applicable data residency laws. | Yes-Explain / Yes-Evidence / No-Explain |
| **2.1-4** | **Data access, transport, and handling** — Secure, access-controlled ingestion with encryption in transit (HTTPS/TLS) and at rest. Customer must be able to revoke access. | Yes-Explain / Yes-Evidence / No-Explain |
| **2.1-5** | **Data use within AI/ML model generation** — If using customer data for model training: shared models must scrub PII; private models must be in secure customer-specific storage. | Yes-Explain / Yes-Evidence / N/A / No-Explain |

**Recommended:** Complete Microsoft Responsible AI Impact Assessment.

**What to check in repo:** Data ingestion code, data layer architecture, encryption config (TLS settings, encryption-at-rest), RBAC/access control, data residency configuration, PII handling.

##### 2.2 AI/ML Integration

**Dual requirement:** Must ALSO complete all of Section 2.1 Data Operations.

| Req ID | Requirement | Attestation Format |
|---|---|---|
| **2.2-1** | **End customer Azure service interoperation** — AI/ML must interoperate with customer-owned Azure services. Models may be self-hosted in customer tenant, partner tenant, or via Azure AI services. | Yes-Explain / Yes-Evidence / No-Explain |
| **2.2-2** | **Data Operations section must be met** — All 2.1 requirements must also be satisfied. | Reference 2.1 attestations |
| **2.2-3** | **Model operations must occur on Azure** — All ML operations (training, inference, augmentation) within Azure-hosted services. No offloading to non-Azure platforms. | Yes-Explain / Yes-Evidence / No-Explain |
| **2.2-4** | **End customer AI/ML enhancements** — Must add value beyond native Azure AI services. Cannot be a simple pass-through/wrapper for Azure OpenAI. Must show domain-specific tuning, enriched UX, workflow integration, or proprietary logic. | Yes-Explain / Yes-Evidence / No-Explain |
| **2.2-5** | **Responsible AI Impact Assessment** (Recommended) — Complete Microsoft Responsible AI Impact Assessment. | Recommended |

**What to check in repo:** AI service integration code, model deployment configs, Azure OpenAI / Cognitive Services usage, custom model logic, value-add beyond native Azure AI, RAG patterns, fine-tuning configs.

##### 2.3 Customer Deployed Services

| Req ID | Requirement | Attestation Format |
|---|---|---|
| **2.3-1** | **End customer environment deployment and execution** — Deploy and execute components (VMs, containers, agents, managed apps) within customer's Azure environment. May extend to on-prem/edge. Hybrid models (SaaS control plane + customer-deployed) in scope. | Yes-Explain / Yes-Evidence / No-Explain |
| **2.3-2** | **Azure-Centric Operations** — Azure must be foundational platform. Additional on-prem/edge components must be coordinated with/managed by Azure services. | Yes-Explain / Yes-Evidence / No-Explain |
| **2.3-3** | **Secure and Controlled Access to End Customer Resources** — Encrypted communication, identity-based authorization (Entra ID, managed identities, scoped service principals), customer-initiated revocation, least privilege, zero trust. Strict separation of duties for SaaS control planes. | Yes-Explain / Yes-Evidence / No-Explain |

**What to check in repo:** Deployment templates (ARM/Bicep), container configs, agent deployment code, managed identity usage, RBAC assignments, access revocation mechanisms, hybrid architecture docs.

##### 2.4 Control Plane, Orchestration & DevOps

| Req ID | Requirement | Attestation Format |
|---|---|---|
| **2.4-1** | **End customer Azure resource interoperation** — Perform control plane operations (provision, modify, orchestrate) on customer Azure resources. Includes scaling, deploying via ARM/Bicep, configuring container services, automating DevOps workflows. | Yes-Explain / Yes-Evidence / No-Explain |
| **2.4-2** | **Azure-based operational execution** — Orchestration/DevOps logic executes within Azure (Functions, Logic Apps, VMs, AKS, SaaS in partner tenant). Cross-tenant communication within Azure boundaries. | Yes-Explain / Yes-Evidence / No-Explain |
| **2.4-3** | **Secure access to end customer Azure resources** — Identity-based controls (Entra ID, managed identities, scoped service principals), encrypted connections, role-based separation between prod/non-prod. Customer-initiated revocation. No persistent/overly-broad permissions. | Yes-Explain / Yes-Evidence / No-Explain |
| **2.4-4** | **Governance and policy compliance** — Operate within customer's Azure governance model (management groups, subscriptions, resource groups). Honor existing Azure Policy. Default new policies to "Audit" effect, not "Deny". | Yes-Explain / Yes-Evidence / No-Explain |
| **2.4-5** | **Operational transparency** — Log all orchestration/control actions (triggers, actors, results, errors). Accessible to customer via portal/API/export. **Minimum 90-day retention** recommended. | Yes-Explain / Yes-Evidence / No-Explain |

**What to check in repo:** CI/CD pipelines, IaC templates, deployment scripts, Azure Policy configs, RBAC assignments, logging/audit trail implementation, log retention config, operational dashboards.

#### Addendum: Co-located Partners

Partners with physical presence in Azure Data Centers (not using Azure servers/hardware) must complete a modified set:

| Req ID | Requirement |
|---|---|
| **CL.1** | Architecture Design (same as 1.1) |
| **CL.2** | WAF Review — Reliability, Security, Ops Excellence, minimum Moderate |
| **CL.3** | Security certification required (FedRAMP, SOC 2/3, ISO 27001, HITRUST, SWIFT CSCF, CMMC 2.0) |
| **CL.4** | Data processing within Azure or partner co-located services |
| **CL.5** | Data residency within Azure or partner co-located infrastructure |
| **CL.6** | Secure data access/transport with encryption and customer revocation |
| **CL.7** | AI/ML data use safeguards (PII scrubbing for shared models, secure storage for private) |

#### Other Designation Technical Audits

##### Modern Work

| Check | Evidence |
|---|---|
| M365 App Compliance Program certification | Certification ID, compliance documentation |
| Teams app manifest and validation | teams-manifest.json, app package |
| Graph API integration | Graph SDK usage, permissions config |

##### Security

| Check | Evidence |
|---|---|
| Sentinel Content Hub solution published | Solution package, data connectors |
| MISA membership (if not Sentinel) | MISA enrollment confirmation |

##### Industry AI (additional requirements — per July 2026 Updated Patterns Playbook)

Partners must pass the solution area technical audit (above) **plus** demonstrate one of three AI patterns. **Solutions must not leverage outside models when transacting through Marketplace.** All solutions must independently align with the Microsoft Responsible AI Standard.

###### Pattern 1: Copilot Agents

| Aspect | Requirement | Evidence |
|---|---|---|
| **Development Platform** | Must use at least one: **Copilot Studio**, **Azure AI Foundry**, or **Azure OpenAI Service** with any supported catalog model | Screenshots of platform usage |
| **Data Storage** | Must use at least one: **OneLake**, Azure data services (Cosmos DB, SQL, Synapse Analytics, PostgreSQL, Blob Storage, ADLS Gen2), **Microsoft Graph**, OneDrive, **Dataverse**, or SharePoint | Architecture diagram showing data sources |
| **Experience Canvas** | Deploy as: standalone embedded copilot in websites/apps, **Teams agent (M365 Agents)**, or **extension to Microsoft Copilots** | Demo of deployment pattern |
| **Required Evidence** | Industry-specific prompts and responses, AI Agent Platform usage proof, demonstration of experience patterns | Prompts/responses, platform screenshots, demo video |

**What to check in repo:** Copilot Studio config, Azure AI Foundry project files, Azure OpenAI deployment, data connector code (Cosmos DB/SQL/Graph SDKs), Teams app manifest, agent deployment config.

###### Pattern 2: Fabric Solutions

| Aspect | Requirement | Evidence |
|---|---|---|
| **Storage** | **OneLake must be the primary analytical storage layer** | OneLake configuration, data pipeline code |
| **Services** | Must use **at least 2 core Fabric services**: Data Factory, Data Engineering, Data Science, Data Warehouse, Power BI, Real-Time Analytics, **Fabric IQ** | Architecture diagram showing Fabric services |
| **Fabric IQ** (if applicable) | Industry ontology providers, customer-specific semantic overlays, Fabric IQ + Foundry agent chaining, data agent, or autonomous operations | Fabric IQ configuration, ontology definitions |
| **Non-Fabric Azure** | May include non-Fabric Azure data services only if explicitly required; majority must be on Fabric | Service inventory |
| **AI Foundation** | If used as foundation for AI capabilities, must demonstrate Fabric data being leveraged for Industry AI use cases | Demo of AI use case |
| **Required Evidence** | Use of Fabric services and/or Fabric APIs, OneLake usage proof | Fabric workspace screenshots, API usage |

**What to check in repo:** Fabric workspace configs, OneLake references, Data Factory pipelines, Power BI reports, Fabric IQ setup, lakehouse/warehouse definitions.

###### Pattern 3: AI Model or Service (hosted on Microsoft Foundry)

| Aspect | Requirement | Evidence |
|---|---|---|
| **Hosting** | Must be hosted and managed on **Microsoft Foundry** (preferred) | Foundry portal screenshots, deployment config |
| **Custom Models** | Build custom LLM, SLM, or fine-tuned models from general-purpose ones. **Publish in Microsoft Foundry Catalog** | Model catalog listing, fine-tuning config |
| **Azure AI Services** | Build on: Microsoft Foundry, Azure AI Search, AI Translator, AI Speech, AI Vision, AI Language, Azure Machine Learning, AI Document Intelligence | Architecture diagram showing services |
| **Foundry IQ** (if applicable) | Publish partner knowledgebase as MCP in Foundry IQ, partner embedding + ranking models in Foundry agentic RAG, direct integration with search indexes | Foundry IQ config, MCP setup |
| **Required Evidence** | Inferencing/fine-tuning via Foundry, solution architecture showing Foundry + Azure AI services, model deployment screenshots, industry-specific prompts/responses | Architecture docs, portal screenshots, demo |

**What to check in repo:** Foundry project config, model deployment scripts, fine-tuning pipelines, Azure AI service integrations (Search, Speech, Vision, Language, Doc Intelligence), MCP configurations, model catalog references.

### Pillar 3: Customer Success

Evaluate commercial performance and customer satisfaction metrics.

#### Partner Performance Criteria (trailing 12 months — meet ONE)

| Metric | Azure / Security | Business Applications | Modern Work | Industry AI |
|---|---|---|---|---|
| **Marketplace Billed Sales (MBS)** | $4M USD | $1M USD | $100K USD | $1M USD |
| **Net-new customer adds** | 12 customers > $10K each | N/A | N/A | 12 customers > $10K each |
| **Marketplace transactions** | 30 txns, 8 unique customers (min $100 each) | N/A | N/A | 30 txns, 8 unique customers |
| **Azure Consumption (MACC)** | $30M USD + 5 txns | N/A | N/A | $30M USD + 5 txns |
| **Azure Consumption (MACC) top tier** | $200M USD + 1 IP co-sell listing | N/A | N/A | $200M USD + 1 IP co-sell listing |
| **BizApps PIR** | N/A | $4M USD | N/A | N/A |
| **Teams Apps MAU** | N/A | N/A | 50,000 MAU | N/A |

#### Solution Satisfaction Criteria (meet ONE)

| Metric | Threshold |
|---|---|
| **Marketplace rating** | >= 4.5 average with >= 15 ratings |
| **Customer evidence artifacts** | >= 2 referenceable case studies / customer artifacts for **enterprise customers** (>1000 employees). Security designation: case studies don't need to be publicly referenceable but may require customer validation. |

**What to check in the repo:**
- Customer case studies in docs/
- Marketplace rating references
- Usage telemetry and metering implementation (for tracking MBS/transactions)
- Metering API integration for overage billing

### Pillar 4: Industry AI Alignment (if targeting Industry AI)

| Check | Evidence |
|---|---|
| Solution aligns to >= 1 Microsoft Industry Cloud customer scenario | Industry scenario mapping document |
| Case studies demonstrate industry-specific AI usage | Industry-tagged customer evidence |
| AI capabilities use Microsoft AI stack | Azure OpenAI, Copilot SDK, Fabric, Azure ML references in code |

## Scoring Methodology

### Per-Pillar Readiness

| Score | Status | Meaning |
|---|---|---|
| 🟢 **Ready** | All requirements met | Can schedule audit |
| 🟡 **Partial** | Some requirements met, gaps identified | 30-60 day remediation path |
| 🔴 **Not Ready** | Major requirements missing | 90+ day roadmap needed |
| ⬜ **N/A** | Pillar doesn't apply to target designation | Skip |

### Overall CSD Readiness Score

| Level | Criteria |
|---|---|
| **Audit-Ready** | All pillars 🟢 Ready — schedule the Partner Center audit |
| **Near-Ready** | No 🔴 pillars, at least one 🟡 — close gaps then schedule |
| **Planning Phase** | One or more 🔴 pillars — build roadmap, target 90-day milestone |

## Workflow

### Phase 1: Discovery

1. **Identify target designation(s)** — Ask user which CSD pathway (Azure, BizApps, Modern Work, Security, Industry AI)
2. **Scan repository** — IaC, app code, CI/CD, docs, marketplace config
3. **Check existing skill outputs** — Reuse SaaS skill docs if present (tenant-isolation-model.md, security-and-compliance.md, fulfillment-and-metering.md, marketplace-onboarding.md)

### Phase 2: Assess Each Pillar

Invoke existing skills where applicable:

| Pillar | Skills to Invoke |
|---|---|
| Marketplace Readiness | `marketplace-onboarding`, `fulfillment-and-metering`, `onboard-to-marketplace` |
| Technical (Azure) | `azure-security-analyzer`, `azure-policy-advisor`, `multi-tenant_SaaS`, `tenant-isolation-models`, `deployment-blueprints` |
| Technical (AI) | Check for Azure OpenAI / Copilot SDK / Fabric usage in codebase |
| Customer Success | `fulfillment-and-metering` (metering implementation), marketplace docs |
| Industry AI | Industry scenario mapping, AI pattern identification |

### Phase 3: Score & Gap Analysis

For each pillar, produce:
1. **Current state** — what exists in the repo with file path evidence
2. **Readiness score** — 🟢 Ready / 🟡 Partial / 🔴 Not Ready
3. **Gaps** — specific missing items with severity
4. **Actions** — what to do, with effort estimate (S/M/L) and priority

### Phase 3.5: Generate Recommended Architecture Diagram

Based on the assessment findings, generate a **Partner Center–compliant reference architecture diagram** (Mermaid) that the partner can use for audit requirement 1.1 and as a co-sell asset.

**Inputs:** IaC templates, app code structure, existing docs, discovered Azure services, workflow category selection.

**Diagram must include:**
- All Azure services discovered in the repo (App Service, Cosmos DB, Storage, Key Vault, OpenAI, etc.)
- End-customer integration/interoperation points with direction of data flow
- Tenant boundary separation (partner tenant vs. customer tenant)
- Network topology (VNet, private endpoints, Front Door/WAF)
- Identity flow (Entra ID, managed identities, service principals)
- Data flow direction arrows (ingestion → processing → storage → output)

**Tailor to the selected workflow category:**

| Category | Diagram Emphasis |
|---|---|
| **2.1 Data Ops** | Data ingestion sources, processing pipeline, storage locations, encryption points, customer data residency boundary |
| **2.2 AI/ML** | AI/ML model hosting, Azure OpenAI / Cognitive Services integration, training vs. inference paths, RAG pipeline, customer data flow into models |
| **2.3 Customer Deployed** | Components deployed into customer tenant (VMs, containers, agents), SaaS control plane in partner tenant, hybrid coordination flow |
| **2.4 Control Plane/DevOps** | Orchestration engine, ARM/Bicep deployment flow, CI/CD pipeline, cross-tenant communication, governance policy integration |

**For Industry AI solutions, additionally show:**
- AI pattern (Copilot Agent / Fabric / AI Model) and its platform components
- Industry-specific data sources and scenario mapping
- Microsoft AI service integration points (Copilot Studio, Foundry, Fabric, Azure AI)

**Skills to invoke:**
- `azure-resource-visualizer` — if live Azure resources exist, generate from deployed state
- `deployment-blueprints` — match to the closest SaaS reference topology
- `azure-principal-architect` — WAF-aligned architecture review of the diagram

**Output:** Mermaid diagram embedded in the report + exported as standalone PNG/SVG for Partner Center submission. Save to `.azure/assessments/architecture-diagram-YYYY-MM-DD.md`.

### Phase 4: Generate Report

Build a **self-contained HTML file** using the `web-artifacts-builder` Clawpilot theme with `@media print` CSS for PDF output.

#### Report Sections

1. **Cover Page** — Solution name, target designation(s), assessment date, overall readiness
2. **Executive Summary** — Overall readiness level, top blockers, recommended timeline
3. **Designation Roadmap** — Visual timeline showing path to audit-ready status
4. **Pillar 1: Marketplace Readiness** — Checklist with status per item
5. **Pillar 2: Technical Interoperability** — Per-category audit readiness with evidence
6. **Recommended Architecture Diagram** — Mermaid diagram tailored to workflow category, showing Azure services, customer integration points, data flows, tenant boundaries, and identity. Suitable for Partner Center submission (req 1.1) and co-sell materials.
7. **Pillar 3: Customer Success** — Metrics status, gap to threshold, metering implementation
7. **Pillar 4: Industry AI Alignment** — (if applicable) Scenario mapping, AI pattern evidence
8. **Action Plan** — Prioritized next steps grouped by timeline:
   - **Immediate** (0-30 days) — Blockers and quick wins
   - **Short-term** (30-60 days) — Technical gaps
   - **Medium-term** (60-90 days) — Customer success & evidence gathering
9. **Audit Artifact Checklist** — Per v2.2, list each required artifact with status:
   - Architecture diagram (PDF/PNG, Partner Center format)
   - Deployed architecture demo (MP4, 720p+, <10min)
   - WAF Review results (Reliability, Security, Ops Excellence — Moderate minimum)
   - Azure Advisor score export (CSV/PDF — Moderate minimum)
   - CSPM score or security certification (no critical recommendations)
   - Workflow category attestations (all sub-requirements for chosen category)
   - Responsible AI Impact Assessment (recommended)
10. **Appendix** — Full findings, file references, links to Microsoft documentation

### Phase 5: Save & Convert

1. Save HTML to `.azure/assessments/csd-readiness-YYYY-MM-DD.html`
2. Auto-convert to PDF if Edge/Chrome headless available:
   ```bash
   msedge --headless --print-to-pdf=report.pdf --no-margins report.html
   ```
3. Otherwise: **Open HTML in browser → Print → Save as PDF**

## Print-Optimized CSS Requirements

```css
@media print {
  body { font-size: 11pt; color: #000; background: #fff; }
  .no-print { display: none; }
  h1, h2, h3 { page-break-after: avoid; }
  table, figure, .card { page-break-inside: avoid; }
  .page-break { page-break-before: always; }
  @page { margin: 0.75in; size: letter; }
  @page :first { margin-top: 0; }
}
```

## Example Invocation

```
@git-ape /csd-assessment-report current --designation azure
@git-ape /csd-assessment-report . --designation industry-ai --industry healthcare
@git-ape /csd-assessment-report https://github.com/org/saas-app --designation azure,security
```
