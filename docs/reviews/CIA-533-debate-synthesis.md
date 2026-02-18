# Debate Synthesis: CIA-533 — Permission Mode Detection + Ralph Wiggum Auto-Trigger

**Review date:** 2026-02-18
**Personas:** Security Skeptic, Performance Pragmatist, Architectural Purist, UX Advocate
**Rounds:** 1 (Independent review only — Round 2 cross-examination outputs were not supplied)

> **Synthesis note:** Round 2 cross-examination files were not present on disk or provided inline.
> This synthesis is therefore based solely on Round 1 independent reviews plus a direct codebase
> scan of the affected files. The Debate Value Assessment and Position Changes sections are marked
> N/A accordingly. The quality score CI is widened by one additional band (+0.2) to account for
> the absence of cross-examination consensus signal.

---

## Executive Summary

All four reviewers independently reached the same verdict — Revise before implementation — but for
partially overlapping, partially distinct reasons. Two critical structural defects dominate the
panel: (1) the proposed env-var communication channel between session-start.sh and
ccc-stop-handler.sh cannot work because the two scripts run in separate process trees with no
shared environment, and (2) the gate override mechanism targets shell variables (`GATE1_ENABLED`,
`GATE2_ENABLED`, `GATE3_ENABLED`) that are set in the stop handler but never tested in the gate
decision logic — making the entire bypass a no-op against the actual gate check, which reads
`.awaitingGate` from `.ccc-state.json`. Beyond these structural breaks, three substantive design
concerns drew majority or unanimous agreement: persistent file-based bypass with no authentication,
conflation of Claude Code's file-permission safety model with CCC's workflow ceremony, and silent
override of explicit user preferences. The codebase scan confirms all three structural bugs; they
are not speculative. The spec requires significant redesign of the bypass persistence mechanism, the
gate interaction model, and the preference schema before implementation should begin.

---

## Codebase Context

**Files examined:**
- `/Users/cianosullivan/Repositories/claude-command-centre/hooks/session-start.sh`
- `/Users/cianosullivan/Repositories/claude-command-centre/hooks/stop.sh`
- `/Users/cianosullivan/Repositories/claude-command-centre/hooks/scripts/ccc-stop-handler.sh`
- `/Users/cianosullivan/Repositories/claude-command-centre/examples/sample-preferences.yaml`

**Confirmed prior art and structural facts:**

1. **Gate mechanism (ccc-stop-handler.sh, line 188):** The gate check is `if [[ -n "$AWAITING_GATE" ]]`
   where `AWAITING_GATE` is read from `.ccc-state.json` (line 146). The variables `GATE1_ENABLED`,
   `GATE2_ENABLED`, `GATE3_ENABLED` are populated from preferences (lines 72-74, 98-100) but are
   never tested anywhere in the script. Overriding them is a confirmed no-op.

2. **Process isolation (session-start.sh vs ccc-stop-handler.sh):** session-start.sh runs as a
   SessionStart hook; ccc-stop-handler.sh runs as a separate Stop hook invocation. Claude Code does
   not pass env vars between hook invocations — they are independent subprocesses. Any `export` in
   session-start.sh has zero effect on ccc-stop-handler.sh.

3. **Two stop hooks coexist:** stop.sh (simple hygiene checklist, no gate logic) and
   ccc-stop-handler.sh (the autonomous loop driver). The spec's reference to "ccc-stop-handler.sh"
   is correct for gate logic, but the spec must be clear which stop hook it modifies and how both
   interact with bypass state.

4. **Preference schema (sample-preferences.yaml):** No `mode.*` namespace exists. The existing
   namespaces are: `gates.*`, `execution.*`, `prompts.*`, `cowork.*`, `replan.*`, `style.*`,
   `planning.*`, `eval.*`, `session.*`, `review.*`, `scoring.*`, `circuit_breaker.*`. The Autonomous
   preset is already described in the `gates.*` section comment (`Autonomous: all false — zero gates`).

5. **No bypass detection logic in current codebase:** Neither session-start.sh nor
   ccc-stop-handler.sh contain any permission-mode detection, process-tree inspection, or bypass
   state handling. This is net-new code with no prior art to build on.

---

## Reconciled Findings

### UNANIMOUS (all 4 agree)

| # | Finding | Severity | Spec Section | Key Evidence |
|---|---------|----------|--------------|--------------|
| U1 | Env var export from session-start.sh cannot reach ccc-stop-handler.sh — separate process invocations share no environment | Critical | Communication mechanism | Confirmed by codebase: hooks are independent subprocesses; no shared env across invocations |
| U2 | `GATE*_ENABLED` override is a no-op — the actual gate check reads `.awaitingGate` from `.ccc-state.json`, not these variables | Critical | Gate override mechanism | ccc-stop-handler.sh line 188 vs lines 72-74; variables set, never tested |
| U3 | Process-tree detection (`ps -o args= -p $PPID`) is platform-fragile and spoofable | Important | Detection layer | `ps -o args=` truncates at 132 chars on Linux; Claude Code command line is 2,070 chars; trivially spoofed |
| U4 | Silent override of explicit user gate preferences violates least surprise | Important | Preference interaction | Users who set `gates.spec_approval: true` would have that decision reversed without notification |

### MAJORITY (3/4 agree)

| # | Finding | Severity | Dissenter | Dissent Reason |
|---|---------|----------|-----------|----------------|
| M1 | `mode.bypass: true` in `.ccc-preferences.yaml` is a persistent, unauthenticated kill switch for all safety gates | Critical | Security Skeptic, Architectural Purist, UX Advocate | Performance Pragmatist — did not raise authentication concern directly; focused on the broken persistence mechanism rather than its security properties. Implicit agreement via "must use filesystem-based persistence" but did not flag auth absence |
| M2 | No audit trail when bypass mode activates | Important | Security Skeptic, Architectural Purist, UX Advocate | Performance Pragmatist — did not surface audit trail as a distinct concern |
| M3 | `CCC_BYPASS_MODE=true` env var leaks to child processes and subagents via process inheritance | Important | Security Skeptic, UX Advocate, Performance Pragmatist (implicitly — flagged env var persistence as broken and recommended state file instead) | Architectural Purist — flagged env var as structurally broken for cross-hook communication but did not separately raise the child-process leakage concern |
| M4 | `mode.bypass` introduces a new namespace with no other occupants when `gates.*` with `preset: autonomous` already expresses the same concept | Important | Architectural Purist, UX Advocate, Security Skeptic | Performance Pragmatist — did not address schema design; focused on runtime mechanics |
| M5 | Bypass + `exec:checkpoint` silently removes human review checkpoints with no user notification | Important | Security Skeptic, UX Advocate, Architectural Purist | Performance Pragmatist — not raised as distinct concern |

### SPLIT (2/2 — genuine disagreement)

| # | Finding | Side A (Personas) | Side A Argument | Side B (Personas) | Side B Argument |
|---|---------|-------------------|-----------------|-------------------|-----------------|
| S1 | Severity of persistent file-based bypass | Security Skeptic, UX Advocate | Critical — worse than `--dangerously-skip-permissions` because it is sticky across sessions, not per-invocation; violates user autonomy at rest | Performance Pragmatist, Architectural Purist (implicit) | Important — the mechanism is broken (no-op per U1+U2), so the security risk is theoretical until fixed; the structural defects are the immediate concern |

### MINORITY (1/4 — unique concern)

| # | Finding | Persona | Severity | Why Others Disagree or Did Not Raise |
|---|---------|---------|----------|--------------------------------------|
| N1 | `CLAUDE_CODE_PERMISSION_MODE` env var creates dead code and speculative coupling | Security Skeptic | Consider | No other persona raised this; it is a forward-compatibility hedge that adds no runtime risk |
| N2 | 22 yq + 26 jq calls = 48 subprocess spawns per stop event is existing tech debt (adding 1 more acceptable) | Performance Pragmatist | Consider | No other persona raised subprocess overhead; Performance Pragmatist flagged it but rated it acceptable |
| N3 | Race condition between bypass detection at session start and state file creation timing | Performance Pragmatist | Consider | No other persona raised timing; the race window is narrow and consequence is a missed auto-trigger (not a safety violation) |
| N4 | Detection cost (~15ms) is acceptable against 300ms budget; reorder: env var first (0ms), preferences (8ms), process tree (2ms) | Performance Pragmatist | Consider | Performance optimisation advice; no other persona engaged with detection latency |
| N5 | Tembo sandbox scenario needs differentiated UX — informational messages wasted on non-human sessions | UX Advocate | Important | No other persona addressed the Tembo/CI machine audience; UX Advocate is correct that a human-facing message has no value in headless execution |
| N6 | "Bypass mode" term overloaded across 3 distinct concepts | UX Advocate | Consider | Naming concern not raised by others; valid but lower priority than structural defects |
| N7 | `mode.bypass` invisible to `/ccc:config` — no discoverability path | UX Advocate | Important | Architectural Purist raised schema namespace concern (M4) but did not specifically flag the config command discoverability gap |

---

## Position Changes (Round 1 to Round 2)

N/A — Round 2 cross-examination outputs were not provided. Position change analysis cannot be performed.

---

## Disagreement Deep-Dives

### S1: Severity of Persistent File-Based Bypass

**Side A (Security Skeptic, UX Advocate):** The `mode.bypass: true` preference is Critical because
it is a durable, session-persistent state change. Unlike `--dangerously-skip-permissions` which
requires the user to consciously pass a flag on each invocation, a file-based bypass silently
persists across all future sessions until manually reversed. The user may forget it is active. In
combination with `exec:checkpoint`, this silently eliminates human review checkpoints — a safety
property the user likely expects to be inviolable regardless of permission mode. The absence of any
authentication or acknowledgment step before writing this preference means any process with write
access to the project root can permanently disable CCC's gates.

**Side B (Performance Pragmatist, Architectural Purist, implicit):** The structural defects (U1 and
U2) make the bypass mechanism a no-op in the current spec — env vars do not propagate across hook
boundaries, and the gate variables being overridden are never tested. Until the mechanism is fixed
to actually work (e.g., writing bypass state to `.ccc-state.json` and reading it in the gate
check), the security risk is theoretical. The implementation priority should be fixing the broken
communication channel first; the authentication and audit concerns are valid but secondary to making
the feature work at all.

**Synthesis note:** This is resolvable by design sequence, not by choosing a winner. The correct
order is: (1) fix the mechanism to actually work via `.ccc-state.json`, then (2) add the audit
trail and acknowledgment step that Side A requires. Both sides agree on the end state; they disagree
on whether to rate the current spec's risk as Critical (broken but dangerous if fixed naively) or
Important (broken, so not yet dangerous). Synthesized severity: Critical — because the spec is the
blueprint, and the blueprint must be designed securely before implementation.

---

## Escalation List (Requires Human Decision)

| # | Issue | Why Escalated | Personas Requesting Escalation | Suggested Decision Framework |
|---|-------|---------------|-------------------------------|------------------------------|
| E1 | Should bypass mode auto-activation be opt-in or opt-out? | The spec proposes auto-triggering bypass when `--dangerously-skip-permissions` is detected. Security Skeptic and UX Advocate argue this conflates two orthogonal concerns (file safety vs. workflow ceremony). The question is whether a user who accepts file risk should automatically accept reduced workflow ceremony — or whether these must remain independent choices | Security Skeptic (I1), UX Advocate (C2, C3) | Decide: (a) auto-trigger with explicit opt-out preference, (b) no auto-trigger — detection only surfaces a prompt asking the user to choose, or (c) remove auto-trigger entirely and rely on the existing `gates.*` Autonomous preset |
| E2 | Should `mode.bypass` exist at all, or should the spec extend the existing `gates.*` preset system? | Architectural Purist and UX Advocate argue `mode.bypass` is redundant with `preset: autonomous` already described in the gates schema comment. Adding a parallel bypass key creates two ways to achieve the same state. The decision requires a schema policy call | Architectural Purist (I1), UX Advocate (I2) | Decide: (a) add `preset` key to `gates.*` as a first-class field and deprecate/remove `mode.bypass`, or (b) keep `mode.bypass` as a runtime override distinct from the static preset |

---

## Severity Calibration

| Finding | Lowest Rating | Highest Rating | Synthesized Rating | Condition for Re-evaluation |
|---------|--------------|----------------|--------------------|-----------------------------|
| Persistent file-based bypass (S1) | Important (Performance Pragmatist implicit) | Critical (Security Skeptic, UX Advocate) | Critical | Downgrade to Important only if the redesign adds explicit user acknowledgment and audit trail at write time |
| Process-tree detection fragility (U3) | Consider (Performance Pragmatist — acceptable fallback) | Important (Security Skeptic — spoofable; UX Advocate — fires unconditionally) | Important | Downgrade to Consider if detection is replaced with a non-spoofable mechanism (e.g., checking a flag written by the Claude Code launcher itself) |
| No audit trail (M2) | Consider (UX Advocate — N4) | Important (Security Skeptic — I2) | Important | Downgrade to Consider if bypass events are written to the existing tool-log JSONL and surfaced in `/ccc:score` output |

---

## Quality Score

| Dimension | Score (1-5) | Confidence | Notes |
|-----------|-------------|------------|-------|
| Completeness | 2.0 | Low | Two critical mechanisms (env var bridge, gate variable override) are structurally broken; hook interaction matrix missing |
| Clarity | 2.5 | Medium | Intent is clear; implementation path contains confirmed no-ops that would not be caught without codebase inspection |
| Feasibility | 2.0 | Low | Core communication mechanism does not work as specified; requires architectural redesign |
| Security posture | 1.5 | Low | Persistent unauthenticated bypass, no audit trail, env var child-process leakage, spoofable detection |
| Scalability | 3.5 | Medium | Detection cost (~15ms) is acceptable; subprocess overhead is pre-existing debt |
| User experience | 2.0 | Low | Silent override of explicit preferences, no opt-out for auto-detection, no discoverability path |
| **Overall** | **2.25** | **CI: 1.65-2.85** | |

**Confidence interval methodology:** Base CI +/-0.3. Widened +0.1 for S1 (one SPLIT finding).
Widened +0.2 each for E1 and E2 (two escalations) = +0.4. Widened +0.2 for absent Round 2
cross-examination. Total widening: +0.7. No narrowing (zero unanimous findings beyond the 2nd).
Final CI: 2.25 +/-0.60, rounded to 1.65-2.85.

---

## Debate Value Assessment

**Did Round 2 (cross-examination) add value beyond Round 1 (independent review)?**

- **Position changes:** N/A — Round 2 not conducted
- **New insights from cross-examination:** N/A
- **Severity recalibrations:** N/A
- **Findings that would have been missed without debate:** N/A

**Value verdict:** NOT ASSESSED — Round 2 outputs were not provided. However, the Round 1
independent reviews show a high degree of natural convergence on the two structural defects (U1, U2)
and three design concerns (U3, U4, M1). The SPLIT (S1) and the two escalations (E1, E2) are the
areas where cross-examination would have added the most value — specifically, whether Performance
Pragmatist's "fix the mechanism first, worry about security properties second" view would have
shifted under challenge from Security Skeptic's "the blueprint must be designed securely" argument.

---

## Recommendation

**REVISE**

The spec contains two confirmed structural bugs that make the feature a no-op as written, plus three
design decisions that require human policy calls before implementation. The revision must address all
items in the Critical and Important rows of the decision record below. The two escalations (E1, E2)
must be resolved by the spec author before any implementation begins.

**Mandatory pre-implementation actions (in order):**

1. Resolve E1: decide on opt-in vs opt-out auto-activation.
2. Resolve E2: decide on `mode.bypass` vs extending `gates.*` preset system.
3. Redesign the bypass persistence mechanism to use `.ccc-state.json` (not env vars).
4. Redesign the gate override to write to `.awaitingGate: null` (or equivalent) in `.ccc-state.json`
   (not to `GATE*_ENABLED` shell variables, which are never tested in the gate check).
5. Add audit trail: write a bypass activation record to the session tool-log JSONL.
6. Add explicit user acknowledgment step before writing bypass state to preferences.
7. Replace process-tree detection with a non-truncating, non-spoofable mechanism or remove it.
8. Define the full hook interaction matrix: how do both stop.sh and ccc-stop-handler.sh behave
   when bypass state is active?

---

## Review Decision Record

**Issue:** CIA-533 | **Review date:** 2026-02-18 | **Option:** F (Structured Debate)
**Reviewers:** Security Skeptic, Performance Pragmatist, Architectural Purist, UX Advocate
**Recommendation:** REVISE

| ID | Severity | Finding | Reviewer | Decision | Response |
|----|----------|---------|----------|----------|----------|
| C1 | Critical | Env var export from session-start.sh cannot reach ccc-stop-handler.sh — separate processes, no shared environment | Architectural Purist, Performance Pragmatist, Security Skeptic, UX Advocate | | |
| C2 | Critical | `GATE*_ENABLED` override is a no-op — gate check reads `.awaitingGate` from state file, not these variables | Architectural Purist, Security Skeptic | | |
| C3 | Critical | `mode.bypass: true` is a persistent, unauthenticated kill switch for all safety gates with no acknowledgment | Security Skeptic, UX Advocate, Architectural Purist | | |
| I1 | Important | Process-tree detection (`ps -o args= -p $PPID`) truncates on Linux and is trivially spoofable | All 4 personas | | |
| I2 | Important | Silent override of explicit user gate preferences with no notification or opt-out | Security Skeptic, UX Advocate, Architectural Purist | | |
| I3 | Important | No audit trail when bypass mode activates | Security Skeptic, UX Advocate, Architectural Purist | | |
| I4 | Important | `CCC_BYPASS_MODE=true` env var export leaks to child processes and subagents via process inheritance | Security Skeptic, UX Advocate | | |
| I5 | Important | `mode.bypass` namespace is redundant with existing `gates.*` Autonomous preset — two ways to express the same state | Architectural Purist, UX Advocate | | |
| I6 | Important | Bypass + `exec:checkpoint` silently removes human review checkpoints | Security Skeptic, UX Advocate | | |
| I7 | Important | Spec modifies only ccc-stop-handler.sh — no interaction matrix for stop.sh and all other hooks | Architectural Purist | | |
| N1 | Consider | Tembo/CI sandbox scenario needs differentiated UX — informational messages wasted on non-human sessions | UX Advocate | | |
| N2 | Consider | `mode.bypass` not surfaced by `/ccc:config` — no discoverability path for the new preference key | UX Advocate | | |
| N3 | Consider | `CLAUDE_CODE_PERMISSION_MODE` env var creates dead code if future Claude Code version never ships this var | Security Skeptic | | |
| N4 | Consider | Race condition between bypass detection at session start and state file creation timing | Performance Pragmatist | | |
| N5 | Consider | "Bypass mode" term overloaded — maps imprecisely across file-permission safety, workflow ceremony, and gate suppression | UX Advocate | | |

**Decision values:** `agreed` (will address) | `override` (disagree, see Response) | `deferred` (valid, tracked as new issue) | `rejected` (not applicable)
**Response required for:** override, deferred (with issue link), rejected
**Gate 2 passes when:** All Critical + Important rows (C1-C3, I1-I7) have a Decision value
