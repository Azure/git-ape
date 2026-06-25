# Git-Ape Workshop Program

> AI-Powered Cloud Deployment for Everyone

Learn to deploy Azure infrastructure using natural language through Git-Ape's multi-agent system. Choose the track that matches your role and experience level.

## Choose Your Track

| Track | Audience | Duration | Azure Required? | What You Learn |
|-------|----------|----------|-----------------|----------------|
| [Track 1: Zero to Deploy](track-1-zero-to-deploy/) | Beginners, non-technical users | 30 min | No | Deploy Azure infra with a single sentence |
| [Track 2: Deploy Like a Pro](track-2-deploy-like-a-pro/) | Engineers, developers | 60 min | Yes (sandbox) | Security gates, cost estimation, architecture review, drift detection |
| [Track 3: Platform Engineering](track-3-platform-engineering/) | DevOps, SRE, platform engineers | 110 min | Yes (sandbox) | CI/CD pipelines, headless mode, multi-environment, policy compliance, drift operations, agent evaluation |
| [Track 4: Executive Briefing](track-4-executive-briefing/) | Engineering leads, executives | 20 min | No (guided demo) | Governance, cost visibility, compliance, ROI |

## Quick Start

1. Set up your [development environment](shared/environment-setup.md) (Codespaces, Dev Containers, or local VS Code).
2. Pick a track from the table above.
3. Follow the labs in order.

## Prerequisites

See [shared/prerequisites.md](shared/prerequisites.md) for tool requirements common to all tracks.

## Content Philosophy

- **80% hands-on, 20% slides.** You learn by doing.
- **Environment-agnostic.** Every track works in Codespaces, local Dev Containers, or plain VS Code. Container-based setups (Options A and B) include all tools pre-installed.
- **Modular.** Complete one track or all four. Each stands alone.

## Delivery Modes

This content adapts to multiple formats:

| Mode | How It Works |
|------|-------------|
| **Live instructor-led** | Instructor drives the deck, attendees follow labs in their development environment |
| **Self-paced** | Written lab guides with step-by-step instructions |
| **Hybrid** | 5-10 min instructor intro, self-paced labs, instructor wrap-up |

## For Facilitators

See [FACILITATOR-GUIDE.md](FACILITATOR-GUIDE.md) for timing, setup checklists, talking points, and delivery tips.

## Deck auto-generation

Workshop decks are rebuilt automatically by `.github/workflows/git-ape-deck-build.yml` whenever a `deck.md` file, a shared SVG, an agent/skill, or a core Git-Ape workflow changes on `main`. The workflow opens a PR (branch `auto/deck-rebuild`) with the rebuilt HTML / PDF / PPTX and inline slide screenshots so reviewers can spot regressions before merge. See [AUTO-GENERATION.md](AUTO-GENERATION.md) for triggers, idempotency guarantees, opt-out, and debugging.

## Recent customer-quality deepening (2026-05-29)

See [CHANGELOG-2026-05-29.md](CHANGELOG-2026-05-29.md) for the full record of the 4-phase deepening pass: comprehensive prereqs (incl. identity model, OIDC subject template detection, AADSTS700213 prevention), all 14 labs deepened against agent behaviour, evidence-capture infrastructure, and customer-readiness checklist. Includes what was verified vs what needs a facilitator dry-run.

## Contributing

Found an issue or want to improve a lab? Open a PR. All workshop content lives in the `workshops/` directory as Markdown files.
