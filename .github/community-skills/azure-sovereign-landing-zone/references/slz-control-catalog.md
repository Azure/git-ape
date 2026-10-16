# SLZ Control Catalog

Source: Sovereignty Baseline policy initiatives (Microsoft Cloud for Sovereignty policy portfolio) as used by the Sovereign Landing Zone. Verify against current Learn pages each run; record the check date.

## Archetypes (landing-zone management groups)

| Archetype | Description | Baseline applied |
|-----------|-------------|------------------|
| corp | Non-internet facing, non-confidential | Global |
| online | Internet facing, non-confidential | Global |
| confidential-corp | Non-internet facing, confidential | Global + Confidential |
| confidential-online | Internet facing, confidential | Global + Confidential |

Confidential scopes are exempt from `parAllowedLocations` and use `parAllowedLocationsForConfidentialComputing`. Policy effect is controlled by `parPolicyEffect`.

## Controls

| ID | Objective | Scope | Evidence class | Template check | Platform/operational check |
|----|-----------|-------|----------------|----------------|----------------------------|
| SO-1 | Customer data stored/processed only in approved geopolitical regions | All archetypes (Global; confidential uses its own list) | Template + Platform | Regional resources and their data destinations in allowlist; global resources need disposition | Baseline allowed-locations policy assigned, enforced, compliant |
| SO-2 | Customer approves operator access to data | All | Operational | None (do not infer) | Customer Lockbox enabled for tenant; record scope/owner |
| SO-3 | Customer-defined sensitive data accessible only encrypted to operators (CMK) | Confidential scopes | Template + Platform | CMK configured on supported data services (exact property per resource type via `/azure-rest-api-reference`) | CMK policy group `SO.3` assigned/enforced/compliant |
| SO-4 | Customer exclusive control of key access; Azure Confidential Computing | Confidential scopes | Template + Platform + Operational | Confidential-computing-backed resources only; key store and key access model; attested key release where required | `SO.4` policy group state; key-access ownership attestation |
| SO-5 | Assurance VM image supply chain is unaltered (Trusted Launch) | All (Global) | Template + Platform | VM `securityProfile.securityType` and related settings per API reference | `SO.5` policy group state |

Notes:

- SO-3 baseline restricts confidential scopes to resource types backed by confidential computing or not processing customer data. The allow-list lives in the assignment (`allowedResourceTypes`); extending it is a customer decision recorded as an exception, not a skill default.
- SO-4: `securityType = ConfidentialVM`, secure boot and vTPM alone do **not** prove customer-exclusive key control. Assess CMK, key store, identity/access and attestation separately.
- Never encode VM SKU families as permanent rules. Validate SKU/image/region/feature combinations live.

## Location Semantics

| Class | Examples | Rule |
|-------|----------|------|
| Regional | Storage, Key Vault, VMs, SQL, App Service, Log Analytics | `location` in allowlist; also check replication (GRS/GZRS secondary regions), backups, geo-replicas, paired regions |
| Global / control plane | Front Door, DNS zones, Traffic Manager, Entra-linked | Requires documented disposition or exception |
| Data destination | Diagnostic settings, export rules, Event Hub/Storage targets | Destination region must be in allowlist or approved via central-logging disposition |
| Unknown type | Anything not classified | `Unknown` (blocks if mandatory) |

Resource-group location is metadata, not residency proof.

## Optional Organizational Overlay (NOT SLZ requirements)

Private endpoints, `publicNetworkAccess = Disabled`, no public IPs on corp archetypes, centralized in-region logging. Label as "organizational profile" in any report; owned by `/azure-security-analyzer`.

## Status Semantics

`Passed` evidence present and correct; `Failed` property present and wrong or required property absent for a Template control; `Unknown` cannot be verified (blocks if mandatory); `NotApplicable` control out of scope for archetype/classification (state why); `ExceptionAccepted` valid, unexpired exception on file.
