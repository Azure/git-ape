---
source: https://learn.microsoft.com/azure/governance/policy/
snapshot: 2026-06-04
refresh_command: "az rest --method get --uri 'https://learn.microsoft.com/api/contentbrowser/search/azure?moniker=azure&locale=en-us&category=Documentation&products=azure-policy' 2>/dev/null || echo 'Manual: visit https://learn.microsoft.com/azure/governance/policy/ and verify links below resolve.'"
---

# Microsoft Learn — Azure Policy reference pages

Authoritative entry points for Azure Policy content on Microsoft Learn. Use these URLs with `microsoft_docs_fetch` when the model needs concrete content from a specific page rather than a search query.

| Content | URL |
|---------|-----|
| All built-in policies (canonical list, by category) | `https://learn.microsoft.com/azure/governance/policy/samples/built-in-policies` |
| Built-in initiatives (regulatory + custom frameworks) | `https://learn.microsoft.com/azure/governance/policy/samples/built-in-initiatives` |
| Regulatory compliance concepts | `https://learn.microsoft.com/azure/governance/policy/concepts/regulatory-compliance` |
| Policy assignment via ARM template | `https://learn.microsoft.com/azure/governance/policy/assign-policy-template` |
| Policy effects reference (Audit, Deny, DeployIfNotExists, etc.) | `https://learn.microsoft.com/azure/governance/policy/concepts/effect-basics` |
| Compliance framework details: CIS Azure Foundations | `https://learn.microsoft.com/azure/governance/policy/samples/cis-azure-1-3-0` |
| Compliance framework details: NIST SP 800-53 Rev 5 | `https://learn.microsoft.com/azure/governance/policy/samples/nist-sp-800-53-r5` |
| Compliance framework details: FedRAMP Moderate | `https://learn.microsoft.com/azure/governance/policy/samples/fedramp-moderate` |
| Compliance framework details: PCI DSS 4.0 | `https://learn.microsoft.com/azure/governance/policy/samples/pci-dss-4` |

## When to fetch which page

- **`built-in-policies`** — when you need the canonical list of all built-in policies grouped by Azure service category (Storage, App Service, etc.) and the per-resource-type priorities in `per-resource-policy-priorities.md` don't cover the resource type the user has in their template.
- **`built-in-initiatives`** — when the user mentions a compliance framework not pre-mapped in this skill, or when verifying that an initiative definition ID is current.
- **Framework-specific pages (`cis-azure-1-3-0`, `nist-sp-800-53-r5`, etc.)** — when the user asks for evidence trail mapping (which policies cover which controls) for a specific framework.
- **`assign-policy-template`** — when emitting ARM-template assignment JSON in Part 2 of the report.
- **`effect-basics`** — when the user asks why a specific policy uses Audit vs Deny vs DeployIfNotExists.

## Search-first pattern

For ad-hoc queries, prefer `microsoft_docs_search` first (broader coverage, recency) and reach for `microsoft_docs_fetch` against these specific URLs only when search results point at one of them or you need the full structured page content. See Step 4 of `SKILL.md` for the search query templates.
