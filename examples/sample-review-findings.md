# Example: Consolidated Adversarial Review Findings

> **Funnel position:** Stage 4 (Adversarial Review) — output of `/sdd:review`
> **Prerequisite:** A completed PR/FAQ spec → see [sample-prfaq.md](sample-prfaq.md)
> **Next step:** Address findings, then decompose via `/sdd:decompose` and implement via `/sdd:start`
> **Later:** After implementation → close with evidence via `/sdd:close` → see [sample-closure-comment.md](sample-closure-comment.md)

This example shows the output of a synthesized adversarial review from 3 reviewer perspectives, applied to the "Collaborative Session Notes" spec.

---

## Adversarial Review: Collaborative Session Notes (PROJ-042)

**Spec reviewed:** `docs/specs/collaborative-session-notes.md`
**Review method:** Option D (In-Session Subagents)
**Date:** 2026-02-15

---

### Critical (Must Address Before Implementation)

**C1. No conflict resolution strategy specified** *(Challenger)*
The spec mentions CRDT-based sync but doesn't define how conflicts are resolved when two users edit the same line simultaneously. CRDTs guarantee eventual consistency but the user experience of conflict resolution matters. What does the user see? Does last-write-win? Are conflicting edits shown side-by-side?

**Recommendation:** Add a "Conflict Resolution" section to the spec defining the UX for simultaneous edits. Consider showing both versions with a merge prompt.

---

**C2. Action item extraction accuracy threshold is undefined** *(Challenger)*
The spec says "~85% accuracy in testing" but doesn't define: What constitutes a false positive vs false negative? What's the minimum acceptable accuracy? At what point do we remove the confirmation step?

**Recommendation:** Define precision and recall targets separately. A false positive (creating a wrong action item) is worse than a false negative (missing one). Target: 95% precision, 80% recall before removing confirmation.

---

**C3. No authentication for shared session links** *(Security)*
The spec says "share the link with participants" but doesn't specify authentication. If session links are unguessable URLs (like Google Docs), anyone with the link can join. If they require workspace authentication, the friction increases.

**Recommendation:** Require workspace authentication by default. Add an option for "guest access with view-only" for cross-org sessions, behind a workspace setting.

---

### Important (Should Address)

**I1. Data retention policy needs GDPR consideration** *(Security)*
90-day default retention is mentioned, but: Can individual users request deletion of their contributions? What about action items that were created from session notes -- are those deleted too? How does this interact with the project tracker's own retention?

**Recommendation:** Add data lineage tracking. When a session note is deleted, linked action items are flagged (not auto-deleted, since they're now in the tracker's domain).

---

**I2. The "zero new tools" claim is misleading** *(Devil's Advocate)*
The spec positions this as "no new tools to learn" but introduces new syntax (`AI:`, `@person`, `DECIDED:`, `?`). While optional, users who don't learn the syntax won't get the core value. This is a new tool wearing a familiar interface.

**Recommendation:** Either: (a) make extraction work without any syntax (pure NLP), or (b) be honest in the messaging that there's a 2-minute learning curve for the syntax. Option (a) is harder but more aligned with the press release promise.

---

**I3. No offline-first architecture described** *(Challenger)*
The spec mentions "offline edits sync when connection restored" but doesn't describe the local-first architecture needed. Is the full CRDT state stored locally? What's the maximum offline session length? What happens if two users are both offline and editing?

**Recommendation:** Specify the local storage mechanism and maximum offline divergence time. Consider a simpler approach: queue edits locally, apply on reconnect, show a "syncing..." indicator.

---

**I4. Competitor differentiation is weak** *(Devil's Advocate)*
The FAQ says "none integrate with project trackers" but this is factually checkable and may be wrong by launch. Notion's API, Linear's own session features, and Loom's action item extraction could close this gap quickly.

**Recommendation:** Reframe differentiation around the real-time extraction during the session (not after), which is genuinely harder for competitors to replicate.

---

### Consider (Nice to Have)

**N1. Session templates for different meeting types** *(Devil's Advocate)*
A standup has different structure than a design review. Pre-structured templates could reduce the "blank page" problem and improve extraction accuracy.

---

**N2. Analytics on session effectiveness** *(Challenger)*
Track: % of action items completed within 7 days, average session duration, action item extraction accuracy over time. This data would inform product decisions and prove ROI to users.

---

**N3. Rate limiting for real-time sync** *(Security)*
Consider rate limiting updates per user per second to prevent accidental or malicious flooding of the sync channel.

---

## Summary

| Severity | Count | Key Theme |
|----------|-------|-----------|
| Critical | 3 | Conflict resolution UX, accuracy metrics, authentication |
| Important | 4 | GDPR, messaging honesty, offline architecture, differentiation |
| Consider | 3 | Templates, analytics, rate limiting |

**Overall assessment:** The spec is strong on the customer problem and solution framing. The main gaps are in the technical specification of edge cases (conflicts, offline, accuracy thresholds) and security architecture (authentication, data retention). These should be addressed before implementation begins.

**Recommended next step:** Address all 3 Critical items and I1 (GDPR). Then proceed to implementation with `exec:tdd` -- the edge cases identified here make a test-first approach essential.
