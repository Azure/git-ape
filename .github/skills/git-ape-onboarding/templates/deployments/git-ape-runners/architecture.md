# Architecture — Git-Ape self-hosted runners

This deployment provisions the private GitHub Actions runner that runs **future
Git-Ape workflows** — i.e. Git-Ape deploying Git-Ape. It is a single
subscription-scoped **Azure Deployment Stack** (`template.json`), so it gets an
architecture diagram, cost estimate, managed deploy, and single-command destroy
like any other Git-Ape deployment.

## Resource topology

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontSize':'13px'}}}%%
flowchart TB
    subgraph SUB["Subscription scope — Deployment Stack: git-ape-runners"]
      RG["Resource Group<br/>rg-git-ape-runners"]
      subgraph INNER["Nested inner-scope deployment (rg-git-ape-runners)"]
        UAMI["User-Assigned Managed Identity<br/>id-git-ape-runner"]
        ACR["Container Registry (Basic)<br/>holds git-ape-runner:latest"]
        KV["Key Vault (RBAC)<br/>secret: github-pat"]
        ENV["ACA Managed Environment<br/>git-ape-runner-env"]
        JOB["ACA Job (Event/KEDA github-runner)<br/>ephemeral runners, scale-to-zero"]
        RA1(["roleAssignment: AcrPull<br/>UAMI → ACR"])
        RA2(["roleAssignment: Key Vault Secrets User<br/>UAMI → KV"])
      end
    end

    RG --> INNER
    UAMI -. AcrPull .-> ACR
    UAMI -. Secrets User .-> KV
    RA1 --- UAMI
    RA1 --- ACR
    RA2 --- UAMI
    RA2 --- KV
    JOB -->|environmentId| ENV
    JOB -->|image pull via identity| ACR
    JOB -->|secret ref via identity| KV
    JOB -->|registers ephemeral runners| GH["GitHub Actions<br/>label: git-ape-runner"]
```

## Bootstrap ordering (self-hosting)

Git-Ape workflows run on `${{ vars.GIT_APE_RUNNER_LABEL || 'ubuntu-latest' }}`.
The **first** deploy of this stack can't run on the private runner (it doesn't
exist yet), so it runs on a public runner or locally. Once it's up and
`GIT_APE_RUNNER_LABEL` is set, every later Git-Ape run — **including updates to
this runner stack itself** — executes on the private runner it created.

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontSize':'13px'}}}%%
sequenceDiagram
    participant U as Operator / Onboarding
    participant GA as Git-Ape (stack deploy)
    participant AZ as Azure (rg-git-ape-runners)
    participant GH as GitHub Actions

    U->>GA: 1. Deploy git-ape-runners (on ubuntu-latest / local)
    GA->>AZ: az stack sub create — RG, UAMI, ACR, KV, ACA job
    U->>AZ: 2. az acr build (push git-ape-runner:latest)
    U->>AZ: 3. az keyvault secret set --name github-pat
    AZ->>GH: 4. Job registers ephemeral runner (label git-ape-runner)
    U->>GH: 5. gh variable set GIT_APE_RUNNER_LABEL=git-ape-runner
    Note over GA,GH: 6. All later Git-Ape deploys run on the private runner
```

## Secrets

The GitHub PAT is **never** in git, ARM parameters, or deployment history. The
stack creates an empty Key Vault; the PAT is written post-deploy with
`az keyvault secret set`. The ACA Job reads it at runtime through a Key Vault
secret reference (`keyVaultUrl` + user-assigned `identity`), which requires the
in-template **Key Vault Secrets User** role assignment.

## Destroy

`/azure-stack-destroy git-ape-runners` (or the `git-ape-destroy.yml` flow) runs
`az stack sub delete --action-on-unmanage deleteAll`, removing the RG, ACA job,
environment, ACR, identity, role assignments, and Key Vault in one call, then
purges the soft-deleted Key Vault (purge protection is intentionally off).
