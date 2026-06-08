# Customer-Readiness Checklist

> Complete this checklist BEFORE any customer-facing workshop delivery. Each item maps to a real failure mode the workshop has hit in practice.

## Step 1: Environment prerequisites verified

- [ ] Run `bash workshops/shared/check-track-<N>-prereqs.sh` for each track being delivered. All checks PASS or documented WARN.
- [ ] Sandbox Azure subscription is Enabled (`az account show --query state -o tsv`)
- [ ] Sandbox has Contributor + UAA roles for the facilitator (Lab 1 onboarding needs both)
- [ ] Resource providers pre-registered: Microsoft.Web, Microsoft.Storage, Microsoft.Insights, Microsoft.Sql, Microsoft.KeyVault, Microsoft.App, Microsoft.OperationalInsights, Microsoft.ContainerRegistry
- [ ] Region quota OK for eastus, westus2, southeastasia
- [ ] GitHub repo "Allow GH Actions to create and approve pull requests" is ENABLED
- [ ] GitHub repo default branch is `main`
- [ ] Tenant allows user app registration creation (or pre-created app reg as fallback)

## Step 2: Deck assets current

- [ ] Decks render cleanly: `node scripts/render-workshop-decks.js`
- [ ] Visual verification PNGs produced: `node scripts/verify-workshop-decks.js`
- [ ] Any visual regressions reviewed and fixed

## Step 3: Lab evidence current

- [ ] Full end-to-end dry run completed on a fresh sandbox in the last 30 days
- [ ] Lab transcript files present in each track's `evidence/` dir
- [ ] `bash scripts/verify-lab-evidence.sh <lab>` returns OK, or drift is reviewed and accepted
- [ ] Screenshots in `workshops/shared/evidence/screenshots/` populated; UPN/sub-name redacted; legible at projector resolution

## Step 4: Source-code parity

- [ ] Agent / skill / workflow changes since last dry-run reviewed for lab impact
- [ ] Any `workshop-sync` Issue from `git-ape-workshop-sync.yml` is closed (or concerns addressed)
- [ ] Deck content reflects the current set of agents and skills

## Step 5: Backup paths

- [ ] Pre-recorded demo videos available at `workshops/shared/recordings/` (T4 always)
- [ ] Pre-onboarded backup repo available for attendees whose Lab 1 OIDC setup fails
- [ ] Backup sandbox sub identified (in case primary hits quota mid-session)

## Step 6: Facilitator readiness

- [ ] Facilitator has run the demo script at least once recently (timing, transitions)
- [ ] Facilitator can answer the "Common questions" section of each guided-demo-script
- [ ] Facilitator knows where to find: prereqs.md, identity-model.md, troubleshooting.md, FACILITATOR-GUIDE.md
- [ ] Facilitator knows the L16 lesson (repo setting for GH Actions PR creation) if attendees ask about CI/CD

## Sign-off

| Item | Reviewer | Date | Notes |
|---|---|---|---|
| Steps 1-2 (env + decks) | | | |
| Step 3 (lab evidence) | | | |
| Steps 4-6 (parity + backup + readiness) | | | |

When all items above are checked, the workshop is **customer-ready**.

## Continuous improvement

After every customer delivery, capture:

- Any new failure mode hit -> add to `workshops/shared/troubleshooting.md`
- Any agent/skill behaviour that surprised an attendee -> add to the relevant lab's "Common failure modes" or "Anti-patterns" section
- Any prereq we should have caught -> add to `prerequisites.md` and the per-track check script

The goal is that every customer delivery makes the next one a little less risky.