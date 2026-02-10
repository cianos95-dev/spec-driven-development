# Example: Completed PR/FAQ (Feature Template)

> **Funnel position:** Stage 3 (PR/FAQ Draft) — output of `/sdd:write-prfaq`
> **Next step:** Send to adversarial review via `/sdd:review` → see [sample-review-findings.md](sample-review-findings.md)
> **Later:** After implementation and verification → see [sample-closure-comment.md](sample-closure-comment.md)

This is an example of a filled-out PR/FAQ using the `prfaq-feature` template. It demonstrates the Working Backwards methodology applied to a real feature.

---

```yaml
---
linear: PROJ-042
exec: tdd
status: ready
---
```

# Collaborative Session Notes

## Press Release

**Collaborative Session Notes: Real-time shared notes that keep distributed teams aligned during live sessions**

*Q2 2026*

**Summary:** Collaborative Session Notes lets team members co-edit structured notes during live working sessions, with automatic action item extraction and integration with the project tracker. It is designed for remote-first teams who lose context between synchronous meetings.

**Problem:** Distributed teams run 3-5 collaborative sessions per week, but notes are scattered across personal documents, chat threads, and memory. 68% of action items from meetings are never captured in the project tracker, leading to repeated discussions and dropped commitments. Teams waste an estimated 4 hours per week reconstructing context from previous sessions.

**Solution:** During any live session, team members open a shared note that auto-structures content into decisions, action items, and open questions. When the session ends, action items are automatically created as issues in the connected project tracker with the right assignees and priorities. A session summary is posted to the team channel.

**Spokesperson Quote:** "We built this because we kept solving the same problems twice. Every session should build on the last, not start from scratch." -- Engineering Lead

**Getting Started:** Start a new session from the dashboard. Share the link with participants. Notes sync in real-time. When done, click "Close Session" to trigger action item extraction.

**Customer Quote:** "I used to spend 20 minutes after every meeting typing up notes and creating tickets. Now it just happens. The action items show up in Linear before I've even closed the tab." -- Sarah, Product Manager at a 15-person startup

**Next Step:** Enable Collaborative Session Notes in your workspace settings.

---

## FAQ

### External (Customer-Facing)

**Q1: Who is this for?**
Remote-first teams of 3-20 people who run regular collaborative working sessions (standups, design reviews, planning meetings, pair programming debriefs).

**Q2: How does it work?**
Open a session note, share the link, and start typing. The system recognizes action items (lines starting with "AI:" or "@person"), decisions (lines starting with "DECIDED:"), and open questions (lines starting with "?"). At session end, these are extracted and routed automatically.

**Q3: What do I need to get started?**
A workspace with at least one connected project tracker (Linear, Jira, or Asana). No additional setup required.

**Q4: What are the limitations?**
Maximum 10 concurrent editors per session. Notes are plain text with markdown support -- no rich media embedding. Action item extraction works best in English.

**Q5: How is my data handled?**
Session notes are stored encrypted at rest. Only workspace members can access notes. Notes are retained for 90 days by default (configurable). No data is shared with third parties.

**Q6: What happens if my connection drops mid-session?**
Your edits are cached locally and synced when you reconnect. No data is lost. Other participants see your cursor go inactive.

### Internal (Business/Technical)

**Q7: Why build this now?**
User research shows "context loss between sessions" is the #1 pain point for our target users. Three competitors launched basic meeting note features in Q1 2026, but none integrate with project trackers.

**Q8: What resources does this require?**
~3 weeks of implementation. Dependencies: real-time sync infrastructure (already built for another feature), project tracker API integrations (already available via MCP).

**Q9: What are the key risks?**
Real-time sync at scale (>5 users) may have latency issues. Mitigation: CRDT-based sync with conflict resolution tested up to 20 concurrent users. Action item extraction accuracy is ~85% in testing. Mitigation: users can correct before confirming.

**Q10: How will we measure success?**
- 60% of active teams create at least 1 session note per week within 30 days
- Action item capture rate increases from 32% to 80% (measured by tracker issue creation)
- Net Promoter Score for meeting workflow improves by 15 points

**Q11: What alternatives did we consider?**
(a) Integrate with existing tools (Google Docs, Notion) -- rejected because none auto-extract to project trackers. (b) Build async-only summaries -- rejected because real-time co-editing is the core need. (c) AI-generated notes from recordings -- deferred to v2 because it requires audio infrastructure.

**Q12: What is the research basis?**
Studies on distributed team coordination show that structured capture during (not after) meetings improves action item follow-through by 2.3x (Smith et al., 2024). CRDT-based real-time editing is proven at scale by prior art in collaborative editors.

---

## Pre-Mortem

_Imagine it is 6 months after launch and this feature has failed. What went wrong?_

| Failure Mode | Likelihood | Impact | Mitigation |
|-------------|-----------|--------|------------|
| Users don't adopt because it's "yet another tool" | High | High | Integrate into existing session flow (one-click from calendar). Zero-friction onboarding. |
| Action item extraction is too inaccurate, eroding trust | Med | High | Ship with manual confirmation step. Improve model with user feedback loop. Set accuracy threshold at 90% before removing confirmation. |
| Real-time sync breaks with >5 users causing data loss | Low | High | CRDT-based architecture with local-first caching. Extensive load testing before launch. Graceful degradation to turn-based editing. |

---

## Inversion Analysis

_How would we guarantee this feature fails?_

1. Require users to learn a new syntax and workflow before they can take any notes
2. Only extract action items after the session ends, when context is already fading
3. Create issues in the tracker without letting users review or edit them first

_Therefore, we must ensure:_

1. Notes work as plain text immediately -- structured extraction is automatic and optional
2. Action items are identified in real-time as they're typed, not after the session
3. Users always see and confirm extracted items before they're created in the tracker

---

## Acceptance Criteria

- [ ] Real-time co-editing works with up to 10 concurrent users with <500ms sync latency
- [ ] Action items (AI: or @person patterns) are highlighted in real-time as typed
- [ ] "Close Session" extracts decisions, action items, and open questions
- [ ] Extracted action items create issues in connected project tracker with correct assignee
- [ ] Session summary posted to configured communication channel
- [ ] Users can edit/delete extracted items before confirming creation
- [ ] Offline edits sync correctly when connection is restored

## Out of Scope

- Audio/video recording and transcription (deferred to v2)
- Rich media embedding (images, files) in session notes
- Cross-workspace session sharing
- Automated session scheduling
