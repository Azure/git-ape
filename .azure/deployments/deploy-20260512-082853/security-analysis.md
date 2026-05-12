# Security Analysis: `deploy-20260512-082853`

## Security Gate: 🟢 PASSED

All 🔴 Critical and 🟠 High checks pass. Deployment may proceed.

---

## Function App (`func-pyapi-dev-eastus`)

| Check | Severity | Status | Evidence | Notes |
|-------|----------|--------|----------|-------|
| HTTPS-only | 🔴 Critical | ✅ Applied | `properties.httpsOnly: true` | Explicitly set in template |
| Minimum TLS 1.2 | 🔴 Critical | ✅ Applied | `siteConfig.minTlsVersion: "1.2"` | Explicitly set |
| FTP disabled | 🟠 High | ✅ Applied | `siteConfig.ftpsState: "Disabled"` | No FTP/FTPS access |
| Managed identity | 🟠 High | ✅ Applied | `identity.type: "SystemAssigned"` | System-assigned MI enabled |
| Identity-based storage | 🟠 High | ✅ Applied | `AzureWebJobsStorage__accountName` app setting | No connection string used |
| HTTP/2 enabled | 🟡 Medium | ✅ Applied | `siteConfig.http20Enabled: true` | Performance + security |
| Run from package | 🟡 Medium | ✅ Applied | `WEBSITE_RUN_FROM_PACKAGE: "1"` | Read-only filesystem protection |

## Storage Account (`stpyapidev{unique}`)

| Check | Severity | Status | Evidence | Notes |
|-------|----------|--------|----------|-------|
| HTTPS-only traffic | 🔴 Critical | ✅ Applied | `properties.supportsHttpsTrafficOnly: true` | Explicitly set |
| Minimum TLS 1.2 | 🔴 Critical | ✅ Applied | `properties.minimumTlsVersion: "TLS1_2"` | Explicitly set |
| Shared key access disabled | 🟠 High | ✅ Applied | `properties.allowSharedKeyAccess: false` | Forces AAD/RBAC only |
| No public blob access | 🟠 High | ✅ Applied | `properties.allowBlobPublicAccess: false` | No anonymous access |
| Default to OAuth | 🟡 Medium | ✅ Applied | `properties.defaultToOAuthAuthentication: true` | Portal defaults to AAD |
| Encryption at rest (SSE) | 🟡 Medium | 🔄 Platform Default | Not in template | Azure encrypts all storage at rest with platform-managed keys automatically |
| Network rules | 🟡 Medium | ⚠️ Not applied | `networkAcls.defaultAction: "Allow"` | Open to all networks — consider restricting for prod |

## App Service Plan (`asp-pyapi-dev-eastus`)

| Check | Severity | Status | Evidence | Notes |
|-------|----------|--------|----------|-------|
| Linux OS | 🟡 Medium | ✅ Applied | `properties.reserved: true`, `kind: "linux"` | Required for Python runtime |

## Application Insights (`appi-pyapi-dev-eastus`)

| Check | Severity | Status | Evidence | Notes |
|-------|----------|--------|----------|-------|
| Workspace-based | 🟡 Medium | ✅ Applied | `properties.WorkspaceResourceId` references Log Analytics | Not classic (deprecated) mode |

## RBAC Role Assignments

| Check | Severity | Status | Evidence | Notes |
|-------|----------|--------|----------|-------|
| Storage Blob Data Owner | 🟠 High | ✅ Applied | Role `b7e6dc6d-...` assigned to Function App MI | Least-privilege for blob access |
| Storage Account Contributor | 🟠 High | ✅ Applied | Role `17d1049b-...` assigned to Function App MI | Required for AzureWebJobsStorage identity-based access |

## Recommendations (non-blocking)

| # | Finding | Severity | Recommendation |
|---|---------|----------|----------------|
| 1 | Storage network open | 🟡 Medium | For prod: set `networkAcls.defaultAction: "Deny"` and add VNet integration |
| 2 | No IP restrictions on Function App | 🟡 Medium | For prod: configure `ipSecurityRestrictions` |
| 3 | No custom domain / WAF | ℹ️ Info | Consider Azure Front Door for production APIs |
