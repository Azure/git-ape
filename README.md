![Git-Ape APE logo](docs/APE.png)

# Git-Ape

> [!WARNING]
> EXPERIMENTAL PROJECT: Git-Ape is in active development and is not production-ready.
> Use it for local development, demos, sandbox subscriptions, and learning only.


**📖 Documentation:** [azure.github.io/git-ape](https://azure.github.io/git-ape/)

Git-Ape is a **platform engineering framework** built on GitHub Copilot. It provides a structured, multi-agent system for planning, validating, and deploying Azure infrastructure — with security gates, cost analysis, and CI/CD pipeline integration built in.

## What It Is

Git-Ape packages a set of Copilot agents and skills focused on Azure infrastructure work.

- It helps you gather deployment requirements.
- It generates ARM templates and supporting deployment artifacts.
- It runs security, preflight, and cost checks before deployment.
- It supports onboarding and post-deployment validation.

## What It Does

Git-Ape is designed around a simple deployment flow:

1. Collect the inputs for the resources you want.
2. Generate and review the template, naming, cost, and security results.
3. Ask for confirmation before anything changes in Azure.
4. Deploy and run follow-up validation.

Common tasks it supports:

- Deploying Azure application stacks such as Function Apps, Web Apps, Storage, SQL, Cosmos DB, and Container Apps.
- Bootstrapping repository onboarding for OIDC, RBAC, GitHub environments, and secrets.
- Saving deployment artifacts under `.azure/deployments/` for audit and reuse.
- Detecting configuration drift between Azure and stored deployment state (agentic workflow — coming soon).
- 
## Git-Ape in action

A short demo video of the onboarding and deploy experience using Git-Ape.

[![Watch the video](https://img.youtube.com/vi/Td6rv_RGArQ/maxresdefault.jpg)](https://www.youtube.com/watch?v=Td6rv_RGArQ)


## Get Started

### Prerequisite
- Only tested with BASH shells (git-bash for windows)
- Run `/prereq-check` in Copilot Chat to verify all required tools (`az`, `gh`, `jq`, `git`) and auth sessions

### 1. Install the plugin

Recommended:

```bash
copilot plugin marketplace add Azure/git-ape
copilot plugin install git-ape@git-ape
```

Verify the installation:

```bash
copilot plugin list   # Should show: git-ape@git-ape
```

Manual option:

1. Clone this repository.
2. Open it in VS Code with GitHub Copilot enabled.
3. Confirm the agents appear in chat.

### 2. Configure Azure access

1. Install Azure CLI and sign in with `az login`.
2. Configure the Azure MCP server in VS Code.
3. Verify the required Azure services are enabled.

Setup details are in [docs/AZURE_MCP_SETUP.md](docs/AZURE_MCP_SETUP.md).

### 3. Use the agents

Start with one of these prompts in Copilot Chat:

- `@git-ape deploy a Python function app`
- `@git-ape deploy a web app with SQL database`
- `@Git-Ape Onboarding set up this repo for Azure deployments`

### 4. Tear Down
Use @git-ape to clean up afterwards by using:
- `@git-ape destroy Python function app`

## Where To Go Next

- [docs/EXAMPLES.md](docs/EXAMPLES.md): Longer end-to-end examples and sample conversations.
- [docs/AZURE_MCP_SETUP.md](docs/AZURE_MCP_SETUP.md): Azure MCP server configuration for VS Code.
- [docs/DEPLOYMENT_STATE.md](docs/DEPLOYMENT_STATE.md): How deployment artifacts are stored and reused.
- [docs/ONBOARDING.md](docs/ONBOARDING.md): Repository onboarding, OIDC, RBAC, and GitHub environment setup.
- [docs/CODESPACES.md](docs/CODESPACES.md): GitHub Codespaces and dev container setup.

## Architecture

`@git-ape` is the central orchestrator. It coordinates a deployment pipeline of specialized subagents, enforces security gates, invokes skills, and manages deployment state. It does not deploy anything without explicit user confirmation.

### Agent & Skill Orchestration

```mermaid
graph TD
    GA["<b>@git-ape</b><br/>Main Orchestrator Agent<br/><i>Coordinates deployment stages, enforces security gates,<br/>delegates to subagents, invokes skills</i>"]

    GA --> DP
    GA --> AD
    GA --> UT

    subgraph DP ["Deployment Pipeline"]
        RG["<b>Requirements Gatherer</b><br/>Interview user<br/>CAF naming<br/>SKU validation"]
        TG["<b>Template Generator</b><br/>ARM template<br/>Architecture diagram<br/>Cost estimate"]
        SG{{"Security Gate<br/>(BLOCKING)"}}
        WR["WAF Review<br/>(Principal Architect)"]
        UC{{"User Confirmation"}}
        RD["<b>Resource Deployer</b><br/>az deployment<br/>Monitor & retry<br/>Integration tests"]

        RG --> TG --> SG --> WR --> UC --> RD
    end

    subgraph AD ["Advisory"]
        PA["<b>Principal Architect</b><br/>WAF 5-pillar review<br/>Trade-off analysis"]
    end

    subgraph UT ["Utility"]
        IE["<b>IaC Exporter</b><br/>Import live resources"]
        OB["<b>Git-Ape Onboarding</b><br/>OIDC + RBAC<br/>GitHub envs & secrets"]
    end
```

### Skills

Skills are invoked by agents at specific stages. Each skill handles one focused task.

| Phase | Skill | Purpose |
|-------|-------|---------|
| **Pre-Deploy** | `/azure-naming-research` | CAF abbreviation lookup, naming constraint validation |
| | `/azure-resource-availability` | SKU restrictions, version support, API compatibility, quota |
| | `/azure-security-analyzer` | Per-resource security assessment with blocking gate |
| | `/azure-deployment-preflight` | What-if analysis and permission checks before deploy |
| | `/azure-role-selector` | Least-privilege RBAC role recommendations |
| | `/azure-cost-estimator` | Real-time cost estimation via Azure Retail Prices API |
| | `/prereq-check` | Verify required CLI tools and auth sessions are ready |
| **Post-Deploy** | `/azure-integration-tester` | Post-deployment health checks and endpoint tests |
| | `/azure-resource-visualizer` | Generate Mermaid diagrams from live Azure resources |
| **Operations** | `/azure-drift-detector` | Detect config drift between live Azure and stored state |
| | `/git-ape-onboarding` | Guided setup for OIDC, RBAC, environments, and secrets |

### Deployment Flow

```mermaid
graph TD
    U["User prompt:<br/><i>deploy a Python function app</i>"]

    U --> S1

    S1["<b>Stage 1: Requirements</b><br/>Requirements Gatherer interviews user"]
    SK1["/azure-naming-research<br/>/azure-resource-availability"]

    S1 -. skills .-> SK1
    S1 --> S2

    S2["<b>Stage 2: Template & Analysis</b><br/>Template Generator produces ARM +<br/>architecture + cost + security report"]
    SK2["/azure-security-analyzer<br/>/azure-deployment-preflight<br/>/azure-cost-estimator<br/>/azure-role-selector"]

    S2 -. skills .-> SK2
    S2 --> GATE

    GATE{{"Security Gate"}}
    GATE -- "BLOCKED" --> FIX["Fix loop"] --> S2
    GATE -- "PASSED" --> WAF

    WAF["<b>Stage 2.75: WAF Review</b><br/>Principal Architect scores 5 pillars"]
    WAF --> CONFIRM

    CONFIRM{{"User confirms / PR approved"}}
    CONFIRM --> S3

    S3["<b>Stage 3: Deploy</b><br/>Resource Deployer runs az deployment"]
    S3 --> S4

    S4["<b>Stage 4: Validate</b><br/>Health checks, endpoint tests, diagram"]
    SK4["/azure-integration-tester<br/>/azure-resource-visualizer"]

    S4 -. skills .-> SK4
```

### Execution Modes

Git-Ape works in two modes — same agents and skills, different execution context.

```mermaid
graph LR
    subgraph Interactive ["Interactive Mode (VS Code / Chat)"]
        direction TB
        I1["User ↔ @git-ape"]
        I2["Real-time Q&A"]
        I3["az login session"]
        I4["Interactive confirmation"]
        I5["Direct deployment"]
        I6["@git-ape destroy {id}"]
    end

    subgraph Headless ["Headless Mode (Coding Agent / Actions)"]
        direction TB
        H1["Issue → Agent on branch"]
        H2["Parse requirements from body"]
        H3["OIDC auth via Actions"]
        H4["Commit artifacts to PR"]
        H5["git-ape-plan.yml (PR)"]
        H6["git-ape-deploy.yml (merge)"]
        H7["git-ape-destroy.yml (merge)"]
    end
```

**Interactive** — you talk to `@git-ape` in VS Code Copilot Chat, authenticate via `az login`, and approve each step in real time.

**Headless** — the Copilot Coding Agent picks up a GitHub issue, generates the template on a branch, opens a PR, and the CI/CD workflows (`git-ape-plan`, `git-ape-deploy`, `git-ape-destroy`) handle validation, deployment, and teardown via OIDC.

### CI/CD Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `git-ape-plan.yml` | PR with template changes | Validate, what-if, post plan as PR comment |
| `git-ape-deploy.yml` | Merge to main or `/deploy` comment | Execute ARM deployment |
| `git-ape-destroy.yml` | Merge PR with `destroy-requested` | Delete resource group |
| `git-ape-verify.yml` | Manual dispatch | Verify OIDC, RBAC, pipeline health |

> **Note:** Drift detection and TTL-based cleanup were previously handled by scheduled workflows (`git-ape-drift.yml`, `git-ape-ttl-reaper.yml`). These are being replaced by agentic workflows — coming soon.

## Included Components

Git-Ape is packaged as a Copilot CLI plugin with agents and skills under `.github/`:

```
plugin.json                          # Plugin manifest
.github/
├── agents/
│   ├── git-ape.agent.md             # Main orchestrator
│   ├── git-ape-onboarding.agent.md  # Onboarding agent
│   ├── azure-requirements-gatherer.agent.md
│   ├── azure-template-generator.agent.md
│   ├── azure-resource-deployer.agent.md
│   ├── azure-principal-architect.agent.md
│   └── azure-iac-exporter.agent.md
├── skills/
│   ├── git-ape-onboarding/          # OIDC, RBAC, env setup
│   ├── azure-naming-research/       # CAF naming
│   ├── azure-resource-availability/ # SKU & quota checks
│   ├── azure-security-analyzer/     # Security assessment
│   ├── azure-deployment-preflight/  # What-if analysis
│   ├── azure-role-selector/         # RBAC recommendations
│   ├── azure-cost-estimator/        # Cost estimation
│   ├── azure-drift-detector/        # Drift detection
│   ├── azure-integration-tester/    # Post-deploy tests
│   └── azure-resource-visualizer/   # Architecture diagrams
└── workflows/
    ├── git-ape-plan.yml
    ├── git-ape-deploy.yml
    ├── git-ape-destroy.yml
    └── git-ape-verify.yml
```

See [plugin.json](plugin.json) and [.github/plugin/marketplace.json](.github/plugin/marketplace.json) for packaging details.

## License

MIT License. See [LICENSE](LICENSE).
