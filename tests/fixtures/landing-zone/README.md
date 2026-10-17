# Landing Zone Discovery — Test Fixtures

Sanitized, deterministic `.azure/landing-zone-context.json` shapes for use in skill evals and downstream consumer tests.

| Fixture | Topology | Management groups | Platform subs | Policies | Shared services | Use for |
|---------|----------|-------------------|---------------|----------|------------------|---------|
| [flat-tenant.json](./flat-tenant.json) | `flat` | Tenant Root only | none | none | none | Solo dev / hobby tenant. Verifies the "no LZ but discovery ran" code path. |
| [hub-spoke-tenant.json](./hub-spoke-tenant.json) | `hub-spoke` | Platform + Landing Zones | connectivity / identity / management | 2 deny + 1 audit | LA / ACR / KV | Enterprise ALZ. Verifies platform-subscription warnings, policy gates, shared-service wiring. |
| [skipped-network.json](./skipped-network.json) | `unknown` | none | none | none | none | Discovery ran with `--skip-network` or network discovery failed. Verifies consumers treat `unknown` conservatively. |

All UUIDs, emails, and resource names are synthetic placeholders.
