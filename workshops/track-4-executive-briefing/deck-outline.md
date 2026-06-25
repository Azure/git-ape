# Track 4: Deck Outline

> 10 slides | 10 minutes | Audience: CTOs, CIOs, engineering leads

---

## Slide 1: The Challenge

**Headline:** Cloud Deployment Is Your Biggest Bottleneck

**Content:**

- 73% of engineering teams wait days for infrastructure changes (internal survey proxy)
- Shadow IT: developers create resources through the portal without governance
- Security incidents from misconfigured cloud resources cost an average of $4.35M per breach (IBM Cost of a Data Breach 2023)
- Monthly bill surprises because cost estimation requires specialized knowledge

**Visual:** Icons representing Wait Time, Shadow IT, Security Risk, Cost Surprise.

---

## Slide 2: What If Deployment Was This Easy?

**Headline:** One Sentence. Production-Ready Infrastructure.

**Content:**
Show the input and output:

**Input:**
> "Deploy a web app with SQL database for the inventory app in production"

**Output (in 2 minutes):**

- Complete infrastructure template (7 resources)
- Security analysis: PASSED (12 checks)
- Cost estimate: $92/month
- Architecture diagram
- Deployed and tested

**Speaker note:** Pause here. Let the simplicity sink in.

---

## Slide 3: Built-In Security Guardrails

**Headline:** Security Is Not Optional — It's Enforced

**Content:**

- **Blocking security gate** — deployment physically stops if Critical/High issues exist
- Managed identities everywhere — no passwords, no connection strings, no shared keys
- HTTPS-only, TLS 1.2+, FTP disabled
- Azure AD authentication for databases (no SQL passwords)
- Key Vault for all secrets
- OIDC federated identity for CI/CD (zero stored credentials)

**Visual:** Gate diagram: Template → Security Analysis → PASS (green arrow to deploy) | BLOCK (red stop sign).

---

## Slide 4: Cost Transparency

**Headline:** Know What You Pay Before You Deploy

**Content:**

- Real-time cost estimates using the Azure Retail Prices API
- Per-resource monthly breakdown
- Dev vs production SKU comparison
- Cost shown at PR level — reviewers see the price before approving

**Visual:** Cost breakdown table showing resources and monthly estimates.

---

## Slide 5: Compliance and Governance

**Headline:** CIS, NIST, and Custom Policy Assessment — Automated

**Content:**

- Templates assessed against CIS Azure Foundations v3.0 and NIST SP 800-53
- Per-resource compliance score
- Audit trail of every deployment decision
- Drift detection catches unauthorized changes
- Policy recommendations with enforcement options (audit or deny)

**Visual:** Compliance dashboard mockup showing pass/partial/fail counts.

---

## Slide 6: Architecture Quality

**Headline:** AI-Powered Well-Architected Framework Review

**Content:**
The AI Principal Architect evaluates every deployment across 5 pillars:

1. **Security** — identity, encryption, access control
2. **Reliability** — redundancy, health monitoring, backup
3. **Performance** — right-sizing, auto-scaling
4. **Cost Optimization** — appropriate tiers, no waste
5. **Operational Excellence** — monitoring, IaC, runbooks

**Visual:** Radar chart with 5 WAF pillar scores.

---

## Slide 7: Developer Self-Service with Guardrails

**Headline:** Your Engineers Deploy. Your Standards Are Enforced.

**Content:**

- Engineers describe what they need in plain English
- Git-Ape enforces your organization's security baseline automatically
- CAF-compliant naming — no inconsistent resource names
- PR-based approvals — human review before any deployment
- CI/CD integration — plan on PR, deploy on merge, destroy on request

**Visual:** Two-column comparison: "Before Git-Ape" (ticket → wait → manual review → deploy → hope) vs "With Git-Ape" (describe → auto-validate → approve → deploy → verified).

---

## Slide 8: ROI

**Headline:** Faster, Safer, Cheaper

| Metric | Before | With Git-Ape |
|--------|--------|-------------|
| Time to deploy | Days (ticket queue) | Minutes (self-service) |
| Security review | Manual, often skipped | Automatic, always enforced |
| Cost estimation | Spreadsheet (after deploy) | Real-time (before deploy) |
| Architecture quality | Ad hoc review | WAF-assessed every time |
| Compliance | Quarterly audit | Continuous assessment |
| Secrets in CI/CD | Service principal JSON | Zero (OIDC) |

---

## Slide 9: Open Source

**Headline:** Free, Open, Community-Driven

**Content:**

- Apache 2.0 licensed — use, modify, contribute
- Built on GitHub Copilot and Azure
- Growing community of contributors
- Workshop program for all skill levels (30 min to 90 min)
- Conference workshops at GitHub Universe, MS Build, DevOps Days

---

## Slide 10: Next Steps

**Headline:** Try It Today

**Content:**

1. Set up your environment — Codespaces (no install), Dev Containers, or local VS Code
2. Type one sentence to `@git-ape`
3. See the result in 2 minutes

**For your organization:**

- Schedule an internal workshop (30 minutes)
- Assess fit for your team's deployment workflow
- Contact us for sandbox subscription setup

**Visual:** QR code to the Git-Ape repository.
