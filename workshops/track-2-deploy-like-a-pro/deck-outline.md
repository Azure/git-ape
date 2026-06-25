# Track 2: Deck Outline

> 8 slides | 10 minutes | Audience: Engineers and developers

---

## Slide 1: Git-Ape Architecture

**Headline:** 8 Agents, 33 Skills, 4 Workflows

**Content:**

- Orchestrator agent (`@git-ape`) coordinates the full pipeline
- Specialized sub-agents: Requirements Gatherer, Template Generator, Resource Deployer
- Advisory agents: Principal Architect (WAF), Policy Advisor (CIS/NIST)
- Utility agents: IaC Exporter, Onboarding
- Skills invoked at each stage: naming, security, cost, integration testing

**Visual:** Agent architecture diagram showing the orchestration flow.

---

## Slide 2: Security-First Approach

**Headline:** Deployment Stops If Security Fails

**Content:**

- **Blocking security gate** — Critical/High findings prevent deployment
- Managed identities everywhere (no connection strings, no shared keys)
- HTTPS-only, TLS 1.2+, FTP disabled, AAD-only SQL auth
- Key Vault references for all secrets
- OIDC federated identity in CI/CD (zero stored secrets)

**Visual:** Security gate flow: Template → Analyze → PASS (deploy) or BLOCK (fix first).

---

## Slide 3: CAF Naming Conventions

**Headline:** Every Resource Named Correctly, Automatically

**Content:**

- Cloud Adoption Framework (CAF) naming enforced
- Pattern: `{type}-{project}-{env}-{region}`
- Examples: `func-orderapi-dev-eastus`, `kv-orderapi-prod-eus`
- Validated against length, character set, and uniqueness constraints
- Naming conflicts detected before deployment

---

## Slide 4: Cost Transparency

**Headline:** See What You Pay Before You Deploy

**Content:**

- Azure Retail Prices API (real pricing, not estimates)
- Per-resource monthly cost breakdown
- Compare dev vs prod SKU costs
- No billing surprises

---

## Slide 5: What You Build Today

**Headline:** Web App + SQL Database + Key Vault

**Content (architecture):**

- App Service Plan + Web App (managed identity)
- SQL Server + SQL Database (AAD-only auth)
- Key Vault (secrets management)
- Application Insights (monitoring)
- All connected via managed identity chain — zero connection strings

---

## Slide 6: Lab Roadmap

| Lab | Duration | What You Do |
|-----|----------|-------------|
| 1. Onboarding | 10 min | OIDC + RBAC + GitHub environments |
| 2. Web App + SQL | 15 min | Multi-resource deployment |
| 3. Security Deep Dive | 10 min | Break security → gate blocks → fix |
| 4. Cost & Architecture | 10 min | Cost estimate + WAF review |
| 5. Drift Detection | 5 min | Manual drift → detect → reconcile |

---

## Slide 7: The "Aha Moment" (Lab 3 Preview)

**Headline:** What Happens When You Break Security?

**Content:**

1. You enable shared key access on a storage account (a security anti-pattern)
2. Git-Ape's security analyzer catches it: `🔴 SECURITY GATE: BLOCKED`
3. Deployment is prevented until you fix it
4. You disable shared keys → re-run → `🟢 SECURITY GATE: PASSED`

**Speaker note:** This is the most impactful lab. Engineers see that security isn't just a report — it actually stops bad deployments.

---

## Slide 8: Let's Go

**Headline:** Open Your Development Environment and Sign In to Azure

**Content:**

1. Set up your environment ([environment setup guide](../shared/environment-setup.md))
2. Run `az login` (or `az login --use-device-code` in Codespaces)
3. Start with Lab 1

**Visual:** QR code or link to environment setup guide.
