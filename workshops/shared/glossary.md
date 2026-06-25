# Glossary

> Key terms used across all workshop tracks.

| Term | Definition |
|------|-----------|
| **ARM template** | Azure Resource Manager template. A JSON file that defines Azure infrastructure declaratively. Git-Ape generates these automatically from natural language. |
| **CAF** | Cloud Adoption Framework. Microsoft's guidance for cloud adoption, including naming conventions, governance, and security baselines. |
| **Codespaces** | GitHub's cloud-hosted development environment. Runs a full VS Code instance in your browser with pre-configured tools. |
| **Copilot Chat** | GitHub Copilot's conversational interface. Git-Ape agents and skills are invoked through Copilot Chat. |
| **Dev container** | A Docker-based development environment defined by a `devcontainer.json` file. Ensures consistent tooling across machines. Works in both GitHub Codespaces and local VS Code with the Dev Containers extension. |
| **Drift** | Configuration differences between what is defined in code (IaC) and what is actually deployed in Azure. Caused by manual Portal changes, policy remediations, or unauthorized modifications. |
| **Federated credential** | An OIDC trust relationship between GitHub and Azure AD. Allows GitHub Actions to authenticate without storing secrets. |
| **IaC** | Infrastructure as Code. Managing cloud resources through code files rather than manual portal clicks. |
| **Managed identity** | An Azure AD identity automatically managed by Azure. Used instead of passwords or connection strings for service-to-service authentication. |
| **MCP** | Model Context Protocol. A standard for connecting AI models to external tools and data sources. Azure MCP Server connects Copilot to Azure APIs. |
| **OIDC** | OpenID Connect. A protocol used for federated authentication between GitHub Actions and Azure, eliminating the need for stored secrets. |
| **RBAC** | Role-Based Access Control. Azure's authorization system that assigns permissions through roles (e.g., Contributor, Owner, Reader). |
| **SARIF** | Static Analysis Results Interchange Format. A standard format for security scan results used by GitHub code scanning. |
| **Security gate** | Git-Ape's blocking validation step. Deployment cannot proceed if Critical or High severity security findings exist. |
| **SKU** | Stock Keeping Unit. Azure's way of identifying pricing tiers and capability levels for resources (e.g., Basic, Standard, Premium). |
| **State file** | A JSON file (`state.json`) that records what was deployed, including resource IDs, deployment outputs, and execution results. Used for drift detection and teardown. |
| **WAF** | Well-Architected Framework. Microsoft's framework for evaluating cloud architectures across five pillars: Security, Reliability, Performance, Cost Optimization, and Operational Excellence. |
| **What-if analysis** | A preview of what an ARM deployment would change (create, modify, delete) without actually making changes. |

## Git-Ape Agents

| Agent | What It Does |
|-------|-------------|
| **@git-ape** | Main orchestrator. Coordinates the full deployment workflow: gather requirements, generate template, validate security, deploy, test. |
| **@azure-principal-architect** | Reviews deployments against the WAF five pillars. Provides architecture recommendations and trade-off analysis. |
| **@azure-policy-advisor** | Assesses ARM templates against Azure Policy frameworks (CIS, NIST). Recommends policy assignments. |
| **@azure-iac-exporter** | Exports existing Azure resources to ARM templates. Brings live infrastructure under IaC management. |
| **@git-ape-onboarding** | Sets up OIDC, RBAC, GitHub environments, and secrets for CI/CD pipeline integration. |

## Git-Ape Skills

| Skill | What It Does |
|-------|-------------|
| `/prereq-check` | Validates CLI tools, versions, and active authentication sessions. |
| `/azure-naming-research` | Looks up CAF abbreviations and naming constraints for Azure resource types. |
| `/azure-security-analyzer` | Runs per-resource security assessment with severity ratings. |
| `/azure-cost-estimator` | Estimates monthly costs using the Azure Retail Prices API. |
| `/azure-deployment-preflight` | Runs what-if analysis and permission checks before deployment. |
| `/azure-drift-detector` | Detects configuration drift between deployed resources and stored state. |
| `/azure-integration-tester` | Runs post-deployment health checks on deployed resources. |
| `/azure-role-selector` | Recommends least-privilege RBAC roles for identities and resources. |
| `/azure-policy-advisor` | Assesses templates against compliance frameworks and recommends policies. |
| `/azure-resource-visualizer` | Generates Mermaid architecture diagrams from deployed resource groups. |
| `/git-ape-onboarding` | Guided setup of OIDC, RBAC, GitHub environments, and secrets. |
