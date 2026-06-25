# Track 3: Deck Outline

> 8 slides | 10 minutes | Audience: DevOps, SRE, and platform engineers

---

## Slide 1: CI/CD Architecture

**Headline:** PR-Based Deployments with Zero Secrets

**Content (4 workflows):**

1. `git-ape-plan.yml` — Validates template on PR, posts plan as comment
2. `git-ape-deploy.yml` — Deploys on merge to main (or `/deploy` comment)
3. `git-ape-destroy.yml` — Tears down resources when `metadata.json` → `destroy-requested`
4. `git-ape-verify.yml` — Manual OIDC/RBAC verification

**Visual:** Pipeline flow diagram: PR → plan → approve → merge → deploy → test → state committed.

---

## Slide 2: Headless Mode

**Headline:** GitHub Issue → Deployed Infrastructure

**Content:**

1. File an issue describing what you need
2. Copilot Coding Agent generates ARM template on a branch
3. PR opened automatically with architecture diagram
4. `git-ape-plan.yml` validates and posts plan
5. Human reviews and approves
6. Deploy on merge — results posted as PR comment

**Visual:** Issue → branch → PR → plan comment → approve → deploy → result comment.

---

## Slide 3: Multi-Environment Strategy

**Headline:** Dev → Staging → Prod with Isolation

**Content:**

- Separate Azure subscriptions per environment
- Environment-specific parameter files
- GitHub environments with protection rules
- OIDC credentials scoped per environment
- Promotion requires PR approval at each stage

---

## Slide 4: Policy and Compliance

**Headline:** CIS, NIST, and Custom Policy Assessment

**Content:**

- Azure Policy compliance checking before deployment
- Frameworks: CIS Azure Foundations v3.0, NIST SP 800-53 Rev 5
- Advisory gate (non-blocking) — surfaces findings without halting
- Per-resource policy recommendations
- Audit vs Deny enforcement modes

---

## Slide 5: IaC Export

**Headline:** Bring Existing Resources Under Management

**Content:**

- Export live Azure resources to ARM templates
- Reverse-engineer existing infrastructure
- Bring legacy deployments under Git-Ape management
- Compare exported template against live state

---

## Slide 6: Lifecycle Management

**Headline:** Create → Deploy → Monitor → Teardown

**Content:**

- Complete lifecycle tracked in `.azure/deployments/`
- State: `planning` → `deployed` → `drift-detected` → `reconciled` → `destroyed`
- Teardown via PR: set `metadata.json` → `destroy-requested` → merge → auto-delete
- Audit trail preserved even after destruction

---

## Slide 7: Lab Roadmap

| Lab | Duration | What You Do |
|-----|----------|-------------|
| 1. CI/CD Pipeline | 20 min | PR-based plan → deploy workflow |
| 2. Headless Mode | 15 min | Issue → auto-PR → deploy |
| 3. Multi-Environment | 15 min | Dev/staging promotion |
| 4. Policy Compliance | 15 min | CIS/NIST assessment |
| 5. IaC Export | 10 min | Export existing resources |
| 6. Destroy Lifecycle | 5 min | PR-based teardown |

---

## Slide 8: Let's Go

**Headline:** Open Your Development Environment and Verify Onboarding

**Content:**

- Ensure OIDC and GitHub environments are configured (Track 2 Lab 1)
- Verify with `git-ape-verify.yml`
- Start with Lab 1

**Prerequisite:** Completed Track 2 or equivalent Git-Ape experience.
