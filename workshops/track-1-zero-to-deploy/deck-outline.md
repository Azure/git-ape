# Track 1: Deck Outline

> 5 slides | 5 minutes | Audience: Beginners and non-technical users

Use this outline to create the PowerPoint or Google Slides deck for Track 1.

---

## Slide 1: What Is Git-Ape?

**Headline:** Deploy Azure Infrastructure with a Sentence

**Content:**
- Git-Ape is an AI assistant that turns plain English into production-ready cloud infrastructure
- Built on GitHub Copilot — works right in your editor or browser
- Handles security, cost estimation, and architecture documentation automatically
- No cloud expertise required

**Visual:** Simple flow diagram:

```
"Deploy a function app" → [Git-Ape] → Security ✅ → Cost 💰 → Deploy 🚀
```

**Speaker note:** Keep this high-level. The audience may not know what ARM templates or IaC are. Focus on the outcome: you describe what you need, and it gets built.

---

## Slide 2: How It Works

**Headline:** A Conversation, Not a Configuration File

**Content (4-step flow):**
1. **You describe** what you need in plain English
2. **Git-Ape asks** a few clarifying questions (region, environment, project name)
3. **Git-Ape generates** the infrastructure template, security report, and cost estimate
4. **You confirm** and it deploys (or you review the artifacts without deploying)

**Visual:** Screenshot of a Copilot Chat conversation with `@git-ape deploy a Python function app`.

**Speaker note:** Emphasize this is a real conversation — not a form or wizard. You can use your own words.

---

## Slide 3: What You Build Today

**Headline:** A Python Function App on Azure

**Content:**
- Serverless function app (runs code without managing servers)
- Storage account (file storage)
- Application Insights (monitoring)
- All connected with managed identity (no passwords stored anywhere)

**Visual:** Simple architecture diagram (Mermaid-style):

```
Function App ──→ Storage Account
     │
     └──→ Application Insights
```

**Speaker note:** Explain "serverless" simply — you upload code, Azure runs it when needed, you only pay for what you use. Estimated cost: under $1/month for light use.

---

## Slide 4: Let's Go!

**Headline:** Set Up Your Environment

**Content:**
- Choose your setup: Codespaces (browser), Dev Containers (local Docker), or VS Code local
- Container-based options include all tools pre-installed — nothing to download
- Follow along with the lab guide

**Visual:** QR code or short link to the environment setup guide.

**Speaker note:** Give attendees 2-3 minutes to set up. Codespaces is the fastest option (~30 seconds if cached). Local Dev Containers take a few minutes to build. Local VS Code users should have tools pre-installed.

---

## Slide 5: Recap and Next Steps

**Headline:** What You Just Did

**Content:**
- Deployed Azure infrastructure using one sentence
- Got an automatic security review (with a blocking gate)
- Saw a cost estimate using real Azure pricing
- Generated an architecture diagram

**Next steps:**
- Track 2: Deploy multi-resource architectures with security deep dives (60 min)
- Track 3: CI/CD pipelines, headless mode, policy compliance (90 min)
- Explore the [Git-Ape documentation](https://github.com/Azure/git-ape)

**Speaker note:** If time allows, ask "Who would like to try deploying something different?" and let a volunteer describe a resource in their own words.
