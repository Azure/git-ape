## Workshop Content Update Required

Feature changes have been merged to `main` that may impact workshop content.

### Change Summary

**Changed:** {{SUMMARY}}
**Commit:** {{COMMIT_SHA}}

### Files Changed

```
{{FILE_LIST}}
```

### Impacted Workshop Tracks

{{TRACKS}}

### Workshop Content Locations

Read these files to understand the current workshop content:

- `workshops/README.md` — Program overview and track selector
- `workshops/track-1-zero-to-deploy/` — Beginner track (30 min, 3 labs)
- `workshops/track-2-deploy-like-a-pro/` — Intermediate track (60 min, 5 labs)
- `workshops/track-3-platform-engineering/` — Advanced track (90 min, 6 labs)
- `workshops/track-4-executive-briefing/` — Executive track (20 min, deck + demo)
- `workshops/shared/glossary.md` — Terms, agents, and skills reference

### Instructions

1. **Read the changed source files** listed above to understand what was added or modified.
2. **Read the existing workshop content** for the impacted tracks.
3. **Determine the impact:**
   - If an agent name, skill name, or command changed → update all references in labs.
   - If a new agent or skill was added → add coverage in the relevant track labs and update the glossary.
   - If a workflow changed → update Track 3 CI/CD labs to reflect the new behavior.
   - If behavior changed (e.g., new security check, new output format) → update the expected output examples in labs.
4. **Make minimal, targeted changes.** Do not rewrite entire labs unless necessary.
5. **Preserve lab timing.** Each lab must still be completable in its stated duration.
6. **Maintain the no-Azure fallback path.** Every lab must remain meaningful without Azure access.
7. **Update `workshops/shared/glossary.md`** if new terms, agents, or skills were introduced.
8. **Update deck outlines** (`deck-outline.md`) if the change affects the presentation narrative.

### Acceptance Criteria

- [ ] All impacted labs updated to reflect the feature changes
- [ ] Lab timing still realistic (30/60/90/20 min per track)
- [ ] No broken cross-references between labs
- [ ] Glossary updated if new agents/skills/terms introduced
- [ ] No-Azure fallback path preserved in all labs
- [ ] Deck outlines updated if presentation narrative affected
