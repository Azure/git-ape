# Eval Framework

## Investigation Summary

We evaluated the following approaches for behavioral testing of Git-Ape agents and skills:

### Options Considered

| Approach | Fit | Notes |
|----------|-----|-------|
| [openai/evals](https://github.com/openai/evals) | Partial | Designed for LLM completion evaluation. Supports tool-using agents via Completion Function Protocol. However, it's Python-heavy, tightly coupled to OpenAI models, and requires maintaining eval YAML definitions separate from the Markdown-based agent definitions we use. |
| Custom eval harness (Node.js) | Good | Lightweight, can parse our existing SKILL.md/agent.md files directly. Scenarios defined as JSON. Can mock tool responses and verify skill invocation order. Matches our existing Node.js tooling. |
| Deferred (manual testing) | Baseline | Current state. No automated behavioral testing. |

### Decision

**Custom eval harness** — a lightweight Node.js-based eval framework that:

1. Defines scenarios as JSON files describing user intent and expected behavior.
2. Validates that the correct skills are referenced for a given intent.
3. Verifies skill output format against mock inputs.
4. Can be extended to use LLM-as-judge for free-form output evaluation later.

**Rationale:**

- `openai/evals` is model-specific and requires Python infrastructure we don't have.
- Our agents and skills are Markdown-based — a custom harness can parse them directly.
- Starting simple with deterministic checks (skill invocation order, output format) provides immediate value without LLM API costs.
- The harness can later integrate LLM-based evaluation if needed.

## Scenario Format

Eval scenarios are defined in `evals/scenarios/` as JSON files:

```json
{
  "id": "deploy-function-app",
  "description": "User requests a Function App deployment",
  "intent": "Deploy a Python Function App with Storage and App Insights in East US",
  "expected_skill_sequence": [
    "prereq-check",
    "azure-naming-research",
    "azure-resource-availability",
    "azure-cost-estimator",
    "azure-security-analyzer",
    "azure-deployment-preflight",
    "azure-integration-tester"
  ],
  "expected_agent": "Git-Ape",
  "expected_sub_agents": [
    "Azure Requirements Gatherer",
    "Azure Template Generator",
    "Azure Resource Deployer"
  ]
}
```

## Running Evals

```bash
node evals/run-eval.js
```

## Next Steps

- [ ] Add more scenarios covering edge cases (multi-region, existing resources, drift detection).
- [ ] Add mock Azure CLI response fixtures for skill output format testing.
- [ ] Investigate LLM-as-judge for evaluating free-form agent responses.
- [ ] Integrate eval runs into CI (non-blocking, advisory).
