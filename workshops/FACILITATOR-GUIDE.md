# Facilitator Guide

> Instructor playbook for delivering Git-Ape workshops.

## Pre-Workshop Setup

### 2 Weeks Before

- [ ] Confirm the track(s) being delivered
- [ ] Verify attendee Copilot access (Individual, Business, or Enterprise)
- [ ] Prepare Azure sandbox subscription(s) if delivering Tracks 2-3
- [ ] Test all labs end-to-end in each supported environment (Codespaces, Dev Containers, or local VS Code)
- [ ] If using Codespaces, create a pre-built Codespace for faster attendee launch times

### 1 Day Before

- [ ] Verify Azure subscription is active and has quota for the target region
- [ ] Run `/prereq-check` in a fresh development environment
- [ ] Test `az login --use-device-code` flow
- [ ] Prepare backup plan (pre-recorded demo, screenshots)
- [ ] Share the [environment setup guide](shared/environment-setup.md) with attendees

### Day Of

- [ ] Open your instructor development environment 15 minutes early
- [ ] Increase font size: `Ctrl+=` three times
- [ ] Open Copilot Chat panel and verify it responds
- [ ] Keep the troubleshooting guide open in a separate tab

## Per-Track Timing

### Track 1: Zero to Deploy (30 min)

| Time | Activity | Facilitator Action |
|------|----------|--------------------|
| 0:00-0:05 | Deck (6 slides) | Present slides, keep it high-level |
| 0:05-0:08 | Lab 1: Setup | Give attendees 3 min to set up their environment. Help stragglers. |
| 0:08-0:23 | Lab 2: First Deploy | Demo first, then let attendees follow. Pause at security gate. |
| 0:23-0:28 | Lab 3: Explore Results | Walk through artifacts. Ask "what surprised you?" |
| 0:28-0:30 | Wrap-up | Recap, point to Track 2, collect feedback |

**Pacing tips:**

- Lab 2 is the core. If running short on time, abbreviate Lab 3.
- Pause after the security gate output — this is the "wow moment" for beginners.
- If the environment is slow to build, fill time by showing the architecture diagram on your screen.

### Track 2: Deploy Like a Pro (60 min)

| Time | Activity | Facilitator Action |
|------|----------|--------------------|
| 0:00-0:10 | Deck (9 slides) | Present architecture, security-first approach |
| 0:10-0:20 | Lab 1: Onboarding | Guide through OIDC setup. This is the most complex lab. |
| 0:20-0:35 | Lab 2: Web App + SQL | Multi-resource deploy. Let it run while explaining outputs. |
| 0:35-0:45 | Lab 3: Security Deep Dive | **Key lab.** Demo the break → block → fix cycle. |
| 0:45-0:55 | Lab 4: Cost & Architecture | Cost comparison and WAF review. Faster-paced. |
| 0:55-0:60 | Lab 5: Drift + Wrap-up | Quick drift demo, then recap and feedback. |

**Pacing tips:**

- Lab 3 is the highlight. Spend extra time here if needed.
- If Lab 1 takes too long (OIDC setup issues), skip Lab 5 and focus on Labs 2-4.
- Have a pre-onboarded repo as backup if OIDC setup fails.

### Track 3: Platform Engineering (90 min)

| Time | Activity | Facilitator Action |
|------|----------|--------------------|
| 0:00-0:10 | Deck (9 slides) | CI/CD architecture, headless mode overview |
| 0:10-0:30 | Lab 1: CI/CD Pipeline | PR-based workflow. This takes the longest. |
| 0:30-0:45 | Lab 2: Headless Mode | Issue → auto-PR. Use alternative path if agent isn't available. |
| 0:45-1:00 | Lab 3: Multi-Environment | Parameter files and promotion. |
| 1:00-1:15 | Lab 4: Policy Compliance | CIS assessment. Review-focused, less hands-on. |
| 1:15-1:25 | Lab 5: IaC Export | Export existing resources. Quick demo. |
| 1:25-1:30 | Lab 6: Destroy + Wrap-up | Teardown lifecycle, final recap. |

**Pacing tips:**

- Labs 1-2 are the core value for this audience. Protect their time.
- Lab 4 can be shortened to a demo if running behind.
- Labs 5-6 can be combined into a 10-minute demo if time is tight.

### Track 4: Executive Briefing (20 min)

| Time | Activity | Facilitator Action |
|------|----------|--------------------|
| 0:00-0:10 | Deck (11 slides) | Problem → solution → security → cost → compliance → ROI |
| 0:10-0:20 | Guided Demo | Follow the demo script. Emphasize security gate and cost estimate. |

**Pacing tips:**

- This audience wants outcomes, not technical details.
- Keep the demo smooth. Practice 2-3 times beforehand.
- Have the pre-recorded video ready as backup.

## Talking Points by Audience

### For Technical Attendees (Tracks 1-3)

- "Git-Ape generates real ARM templates — you can inspect and modify them."
- "The security gate is a blocking control, not just a report."
- "OIDC means zero stored secrets. No service principal JSON blobs."
- "Drift detection catches portal changes and policy remediations."

### For Non-Technical Attendees (Track 1, 4)

- "You describe what you need in plain English. No code required."
- "It checks security automatically — like spell-check for cloud infrastructure."
- "You see the cost before you deploy — like a price tag before checkout."
- "Everything is documented automatically for your audit trail."

## Delivery Mode Adaptation

### Virtual (Zoom, Teams)

- Share your screen for demos
- Use breakout rooms for labs (one facilitator per 10-15 attendees)
- Post the [environment setup guide](shared/environment-setup.md) link in chat at the start
- Use polls for "are you done with this step?" checkpoints

### In-Person

- Project your development environment on the main screen
- Walk the room during labs to help with setup issues
- Print QR codes for the environment setup link and feedback survey
- Have a second screen showing the lab guide

### Self-Paced (Async)

- Lab guides are self-contained — attendees follow the Markdown
- Add a Discussions thread for Q&A
- Consider recording a 5-minute video introduction per track
- Include estimated completion time at the top of each lab

## Post-Workshop

### Feedback Survey (Include in Final Slide)

Link to a short survey (Google Forms, Microsoft Forms, or GitHub Discussion):

1. Which track did you complete? (1/2/3/4)
2. How long did it take? (shorter/about right/longer than expected)
3. Were the instructions clear? (1-5 scale)
4. What was the most valuable part?
5. What would you improve?
6. Would you recommend this workshop? (NPS: 0-10)

### After the Session

- [ ] Review survey responses
- [ ] File GitHub issues for any content problems found
- [ ] Update lab timing if feedback suggests adjustments
- [ ] Share results with the marketing team (for program summary metrics)

---

## Deck maintenance

You do not need to rebuild the decks by hand. Edit `<N>_<name>_deck.md` in any track folder, push to `main`, and `.github/workflows/git-ape-deck-build.yml` will open a PR with the rebuilt HTML / PDF / PPTX plus inline screenshots for review. See [`AUTO-GENERATION.md`](AUTO-GENERATION.md) for the full mechanism, triggers, and how to opt out for a one-off manual edit.
