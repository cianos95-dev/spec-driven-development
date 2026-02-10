# Example: Issue Closure Comments

> **Funnel position:** Stage 7.5 (Issue Closure) — output of `/sdd:close`
> **Prerequisite:** Implementation complete (Stage 6) and verification passing (Stage 7)
> **Earlier stages:** Spec via `/sdd:write-prfaq` → see [sample-prfaq.md](sample-prfaq.md) | Review via `/sdd:review` → see [sample-review-findings.md](sample-review-findings.md)

These examples show what good closure comments look like under different closure rules.

---

## Example 1: Auto-Close (agent assignee + single PR + merged + deploy green)

> **Issue:** PROJ-042 — Implement Collaborative Session Notes
> **Action:** Auto-closed by agent

---

**Completed: Collaborative Session Notes**

**Deliverables:**
- PR [#127](https://github.com/~~owner/~~repo/pull/127) merged to main
- Production deployment verified: [preview URL]

**What was delivered:**
- Real-time co-editing with CRDT sync (tested up to 10 concurrent users)
- Action item extraction with `AI:` and `@person` pattern recognition
- "Close Session" flow with confirmation step before tracker issue creation
- Session summary auto-posted to configured channel

**Verification:**
- All 7 acceptance criteria passing
- 42 tests added (unit + integration), all green
- TypeScript strict mode, zero lint warnings
- Preview deployment manually verified

**Labels updated:** `spec:implementing` → `spec:complete`

---

## Example 2: Propose Closure (multi-PR issue)

> **Issue:** PROJ-038 — Refactor Authentication System
> **Action:** Proposing closure, awaiting human confirmation

---

**Proposing closure: Authentication Refactor**

This issue was implemented across 3 PRs:
1. PR [#121](https://github.com/~~owner/~~repo/pull/121) — JWT token generation (merged)
2. PR [#123](https://github.com/~~owner/~~repo/pull/123) — Refresh token rotation (merged)
3. PR [#125](https://github.com/~~owner/~~repo/pull/125) — Token revocation endpoint (merged)

All PRs merged and deployed. 28 tests added. Production verified.

**Shall I close this issue?** All acceptance criteria appear met, but flagging for review since this was a multi-PR effort.

---

## Example 3: Propose Closure (no PR linked — research/planning issue)

> **Issue:** PROJ-035 — Evaluate CRDT Libraries for Real-time Sync
> **Action:** Proposing closure with deliverable summary

---

**Proposing closure: CRDT Library Evaluation**

**Deliverables:**
- Evaluation document: `docs/specs/crdt-evaluation.md` (committed in [abc123](https://github.com/~~owner/~~repo/commit/abc123))
- Compared 4 libraries: Yjs, Automerge, Diamond Types, Loro
- Recommendation: Yjs (best TypeScript support, largest community, proven at scale)
- Decision rationale documented in spec

No implementation PR — this was a research/evaluation issue. The recommendation feeds into PROJ-042 (Collaborative Session Notes).

**Shall I close this issue?**

---

## Example 4: Never Auto-Close (human-assigned issue)

> **Issue:** PROJ-040 — Decide on pricing tier structure
> **Action:** Status comment only (no closure attempt)

---

**Status update: Pricing Tier Structure**

Related implementation work is complete:
- Billing infrastructure deployed (PR [#130](https://github.com/~~owner/~~repo/pull/130))
- Stripe integration tested in staging
- Feature flag `pricing-v2` ready to enable

This issue is assigned to you and involves a business decision, so I'm not proposing closure. The technical prerequisites are in place whenever you're ready to finalize the pricing structure.
