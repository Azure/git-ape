# SLZ Platform Build Reference

Supports Build mode in `SKILL.md`. Sources: [SLZ overview](https://learn.microsoft.com/azure/azure-sovereign-clouds/public/overview-sovereign-landing-zone) and the Sovereignty Baseline policy portfolio. Re-check Learn on every run.

## Management Group Hierarchy

```text
{prefix}                       (SLZ root, under pilot parent by default)
├── {prefix}-platform
│   ├── {prefix}-identity
│   ├── {prefix}-connectivity
│   └── {prefix}-management
├── {prefix}-landingzones
│   ├── {prefix}-corp
│   ├── {prefix}-online
│   ├── {prefix}-confidential-corp
│   └── {prefix}-confidential-online
├── {prefix}-sandbox
└── {prefix}-decommissioned
```

The Confidential Corp and Confidential Online groups are the SLZ additions over a standard Azure landing zone. Identity, networking and billing design are unchanged from Azure landing zones.

## Policy Assignment Matrix

| Scope | Initiative | Key parameters |
|-------|------------|----------------|
| SLZ root | Sovereignty Baseline - Global | `parAllowedLocations`, `parPolicyEffect` |
| Confidential Corp, Confidential Online | Sovereignty Baseline - Confidential | `parAllowedLocationsForConfidentialComputing`, `parPolicyEffect`, allowed resource types |

Look up initiative definition IDs with `az policy set-definition list` at run time. Confidential scopes are exempt from `parAllowedLocations` and use the confidential location list.

## Region Defaults

| Request | Resolved |
|---------|----------|
| `{region}` only | `allowedLocations = [region]` |
| Confidential computing | Verify availability in the region first; ask if unavailable |
| Policy effect | `Audit` first, promote to `Deny` after reviewing compliance |

## Required Permissions

* Management Group Contributor and Resource Policy Contributor at the parent, or Owner at the parent
* Tenant-scope deployment needs elevated access to be granted deliberately by a tenant administrator, and should be revoked afterwards

## Rollout Order

1. Pilot parent management group, `Audit` effect
2. Place one non-production subscription per archetype and review compliance
3. Promote selected policies to `Deny` through a reviewed change
4. Move production subscriptions

## Not Automated

* Customer Lockbox enablement (tenant owner attestation, SO-2)
* Subscription vending and billing
* Legal or jurisdictional sign-off
