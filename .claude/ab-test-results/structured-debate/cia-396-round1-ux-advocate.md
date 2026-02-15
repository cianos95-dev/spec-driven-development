# Round 1 Review — UX Advocate (Green)

**Spec:** CIA-396 — Prototype tool capture hooks for spec conformance
**Reviewer:** UX Advocate
**Date:** 2026-02-15

## Review Lens

User journey, error experience, cognitive load, discoverability, mental models.

---

## Critical Findings

### C1: Invisible Feedback Loop

**Severity:** HIGH

PostToolUse hook fires AFTER every write, but the spec does not specify how conformance results are communicated to the user (human or agent). Without feedback, the hook is a black box:

- Agent writes a file → hook checks conformance → ???
- Does the agent see: "✓ Change aligned with criterion 3"?
- Or: "⚠ Change does not match any acceptance criteria"?
- Or: Nothing (silent logging only)?

If feedback is absent or unclear, the agent cannot adjust behavior. The hook becomes audit-only, not corrective.

**User journey impact:**
1. Agent writes code
2. Hook silently logs non-conformance
3. Agent continues, unaware of drift
4. Human reviews logs later and finds 50% of writes were non-conformant
5. Human must manually review and fix — wasted effort

**Mitigation:**
1. Define hook output format visible to agent:
   ```
   [SDD Conformance] ✓ Change matched criterion 2: "Implement authentication"
   [SDD Conformance] ⚠ Change did not match any criteria (possible drift)
   ```
2. Surface high-confidence drift warnings as stderr (agent sees them immediately)
3. Document feedback loop: agent sees conformance status → adjusts next write

---

### C2: No Error Recovery Path

**Severity:** HIGH

If conformance checking fails (e.g., spec parsing error, malformed criterion, git diff timeout), what happens?
- Does the hook fail loudly (block the write)?
- Fail silently (allow write, log error)?
- Skip conformance check (allow write, warn)?

Without a defined error recovery path, users will hit cryptic failures with no guidance on how to fix them.

Example bad experience:
```
[SDD] ERROR: Failed to parse acceptance criteria
Tool execution blocked. Session halted.
```
User has no idea what went wrong or how to fix it.

**Mitigation:**
1. Fail SOFT by default (log error, allow write, warn user)
2. Fail HARD only in strict mode (`SDD_STRICT_MODE=true`)
3. Provide actionable error messages:
   ```
   [SDD Conformance] ERROR: Could not parse spec at .sdd-spec.md
   Reason: Markdown parsing failed at line 42
   Action: Fix spec syntax or set SDD_SPEC_PATH to valid spec
   Note: Write allowed, conformance check skipped
   ```

---

### C3: False Positive Punishment

**Severity:** MEDIUM-HIGH

The spec gates adoption on "<10% false positives," but does not consider the user experience of false positives:

- Agent writes valid code that aligns with spec intent
- Hook flags it as non-conformant (false positive)
- Agent sees warning, wastes time investigating
- Agent learns to ignore warnings (alert fatigue)

If false positives are frequent (even below 10%), the hook becomes noise rather than signal. Users will disable it or ignore its output.

**Mitigation:**
1. Tune confidence thresholds to prioritize precision over recall (better to miss real drift than to flag false drift)
2. Allow users to suppress specific criteria that produce false positives
3. Provide feedback mechanism: "Was this warning helpful? [Y/N]" to measure perceived accuracy (not just technical accuracy)

---

## Important Findings

### I1: Cognitive Overload

**Severity:** MEDIUM

If the hook produces conformance feedback on EVERY write, and a typical session has 50 writes, the agent receives 50 conformance messages. Even if 90% are positive ("✓ Matched criterion X"), the sheer volume is overwhelming.

**User journey:**
1. Agent writes 10 files to implement a feature
2. Receives 10 conformance messages
3. Agent's context window fills with conformance noise
4. Important messages (errors, warnings) are buried in the log

**Mitigation:**
1. Only surface HIGH-CONFIDENCE drift warnings (suppress "probably OK" results)
2. Batch feedback: "Last 5 writes: 4 matched criteria, 1 possible drift"
3. Or make feedback opt-in: agent can check conformance status with `/sdd:conformance-status` command instead of seeing every result inline

---

### I2: Unclear Mental Model

**Severity:** MEDIUM

Users (both human and agent) need a mental model of when conformance checking happens and what it affects. The spec does not provide this:

- Does the hook block writes if conformance fails? (No, but not stated)
- Does it affect CI/CD? (Unknown)
- Is it advisory or enforcing? (Advisory by default, but not explicit)

Without a clear mental model, users will make incorrect assumptions and be surprised by behavior.

**Mitigation:**
1. Add a "How This Works" section to documentation:
   - "PostToolUse hook checks conformance after every write"
   - "Results are logged for audit, but writes are NEVER blocked"
   - "Use strict mode to block non-conformant writes (not recommended)"
2. Provide visual diagram of hook execution flow

---

### I3: No Discoverability

**Severity:** MEDIUM

If conformance checking is enabled via a hook, how does a new user discover it exists?
- Hooks are invisible unless you read `.claude/settings.json`
- No `/sdd:conformance` command mentioned in the spec
- No documentation link

A user who clones the project will not know conformance checking is active until they see unexpected output or check logs.

**Mitigation:**
1. Add SessionStart message: "[SDD] Spec conformance checking enabled (see logs/.sdd-conformance-log.jsonl)"
2. Document in project README: "This project uses SDD spec conformance hooks"
3. Provide `/sdd:conformance-status` command to view recent conformance results

---

## Consider

### S1: Agent vs Human User

The spec does not clarify who the primary user is:
- If agent: optimize for inline feedback, low noise, high signal
- If human: optimize for audit logs, batch reports, post-session review

These have different UX needs. An agent wants immediate feedback to adjust behavior. A human wants a summary after the session.

**Recommendation:** Design for agent as primary user (inline feedback), with human as secondary user (audit logs). Agent corrects drift in real-time, human reviews logs only if issues persist.

---

### S2: Onboarding Experience

A user enabling this feature for the first time will not know what to expect. Provide a dry-run mode:
```bash
SDD_CONFORMANCE_DRY_RUN=true
```
Logs conformance results without affecting behavior. User can review false positive rate before enabling for real.

---

### S3: Feedback on Success

Users are more likely to trust a system that tells them when things go RIGHT, not just when things go wrong. Consider positive feedback:
```
[SDD Conformance] ✓ 45/50 writes matched acceptance criteria this session
```

Reinforces that the hook is working and provides value.

---

## What the Spec Gets Right

1. **Explicit risk awareness** — "May over-constrain agent creativity" shows consideration for user impact.

2. **Decision gate** — "Adopt, modify, or reject" acknowledges this might not work for all users. Allows opt-out.

3. **Measurable validation** — "10-issue sample tested" means real-world usage before rollout.

4. **False positive threshold** — Recognizes that too many false positives ruin UX.

---

## Quality Score

| Dimension | Score (1-5) | Rationale |
|-----------|-------------|-----------|
| **User Journey** | 2 | No feedback loop defined, unclear how users discover or interact with feature |
| **Error Experience** | 2 | No error recovery path, no actionable error messages |
| **Cognitive Load** | 2 | 50 conformance messages per session is overwhelming |
| **Discoverability** | 2 | Hooks are invisible, no onboarding documentation |
| **Mental Model** | 3 | Basic intent is clear, but details (blocking vs advisory) are not |

**Overall:** 2.2 / 5.0

---

## Recommendation

**REVISE**

The spec focuses on technical implementation but ignores user experience. As written, the hook will be confusing and noisy, even if technically correct.

**Required changes:**
1. Define hook output format and feedback loop (what does the agent see?)
2. Define error recovery path (fail soft vs hard, actionable error messages)
3. Add conformance status command (`/sdd:conformance-status`) for discoverability
4. Add SessionStart message announcing conformance checking is active
5. Tune feedback volume (only surface high-confidence drift, suppress noise)

**UX principle:** A tool that produces correct results but is unusable is worse than no tool at all. Invest in feedback design, not just conformance logic.

**Positive note:** The 10-issue sample test will surface UX issues empirically. If users find the hook annoying or confusing during testing, the decision gate allows rejection or modification.
