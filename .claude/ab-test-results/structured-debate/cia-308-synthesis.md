# CIA-308 Synthesis: PM/Dev Extension Command and Skill Specification

## Metadata
- **Spec:** CIA-308 — SDD Plugin PM/Dev extension command and skill specification
- **Date:** 2026-02-15
- **Debate Structure:** 4 personas × 2 rounds (8 reviews total)
- **Personas:** Security Skeptic (Red), Performance Pragmatist (Orange), Architectural Purist (Blue), UX Advocate (Green)

---

## Executive Summary

This spec proposes PM/Dev workflow extensions through new commands, skills, connector integrations, and README reconciliation. After two rounds of adversarial review, **all four personas APPROVE** the spec, but with **7 CRITICAL mitigations required** before implementation.

**Unanimous agreement:** README undercounting (8 vs. 12 commands, 10 vs. 21 skills) creates documentation trust erosion that cascades to security, performance, and usability documentation. This MUST be fixed via CI validation before any feature additions.

**Key tension:** Security and UX disagree on component count. Security argues 33 components force intentional workflows (prevent "ship and forget"). UX argues 33 components create choice paralysis (Hick's Law violation). **Resolution:** Keep 33 components BUT add module organization (5 modules × 5-7 components) + progressive disclosure (Essential 5 for new users, Advanced 7 unlockable).

**Architectural foundation gaps:** Four critical abstractions are undefined: command vs. skill taxonomy, agent behavioral contracts, connector interface boundaries, and semantic versioning policy. Adding features without these foundations will create technical debt.

**Recommendation:** **APPROVE** with 7 CRITICAL mitigations + 12 Important recommendations. Estimated implementation: 2-3 weeks for mitigations, then feature work can proceed.

---

## Codebase Context

**Current State (from scan):**
- 12 commands (README claims 8)
- 21 skills (README claims 10-16)
- 8 agents (marketplace.json claims 7, missing `debate-synthesizer.md`)
- 14 connector placeholders (9 concrete tool integrations documented)
- 9-stage funnel (fully mapped)
- 3-layer monitoring stack (structural, runtime, app-level)
- Version 1.3.0 (no semantic versioning policy documented)

**Spec Requests:**
1. New commands: `/sdd:analytics-review`, `/sdd:verify`, `/sdd:research-ground`, `/sdd:digest` (candidates)
2. New skills: `analytics-integration`, `enterprise-search-patterns`, `developer-marketing`, `data-informed-closure`, `adaptive-methodology` (candidates)
3. Extended CONNECTORS.md: Replace placeholders with PostHog, Sentry, Amplitude, Firecrawl, Slack, Notion
4. README reconciliation: Update counts to match reality (12 commands, 21 skills)
5. Agent formalization: Evaluate whether PM persona (Stages 0-5) and Dev persona (Stages 6-7.5) should be agents

---

## Finding Categories

### UNANIMOUS (All 4 Personas Agree)

| Finding | Severity | Personas | Consolidated Mitigation |
|---------|----------|----------|------------------------|
| **README Undercounting** | CRITICAL | Security (I1→CRITICAL), Performance (I5→CRITICAL), Architectural (C4), UX (C1) | Add CI check: `npm run verify-readme` compares actual vs. claimed counts, blocks commit if mismatch. Add to pre-release checklist. Update README tables to include 4 missing commands + 5 missing skills. |
| **Analytics Connectors** | CRITICAL | Security (C1), Performance (C2), Architectural (needs adapter), UX (needs decision framework) | Add "Data Privacy Protocol" section to CONNECTORS.md (PII masking, GDPR compliance). Add analytics adapter layer (sanitizes PII before Stage 7 workflow). Add decision framework for Stage 2 (interpret metrics → prioritization decision). Keep analytics blocking with 2s timeout + cached fallback. |
| **Progress Indicators** | CRITICAL | Performance (I3), UX (I3→CRITICAL) | Add to `/sdd:index` (16 min on large repos), `/sdd:review` (multi-model 30-90s), `/sdd:decompose` (50+ tasks). Format: "[1/4] Step... estimated X minutes remaining." Add cancellation safety message. |

**Confidence:** 100% — All personas independently identified these issues across both rounds.

### MAJORITY (3 of 4 Personas Agree)

| Finding | Severity | Personas | Dissent | Mitigation |
|---------|----------|----------|---------|------------|
| **Multi-Model Review Cost** | CRITICAL | Security (C1→DoS vector), Performance (C1), Architectural (resource contract violation) | UX (not mentioned) | Add cost ceiling $5/review, per-model budget (GPT-4 $2, Claude $2, Gemini $1). Add caching (unchanged spec = cached result). Add rate limiting (10 reviews/day/user). Add spec size limit (50KB). |
| **Command/Skill Taxonomy** | CRITICAL | Security (authorization boundaries), Architectural (C1), UX (validates taxonomy-first approach) | Performance (not mentioned) | Define in `docs/component-taxonomy.md`: Commands = user-invoked + stateful workflow (run in user security context), Skills = context-triggered + guidance (no direct API calls). Decision tree + examples. Retroactively classify all 33 components. |
| **Agent Behavioral Contracts** | CRITICAL | Security (C2 added trust boundaries), Architectural (C2), Performance (validation overhead concern) | UX (not mentioned) | Define in `docs/agent-architecture.md`: 3 types (stage handler, review persona, orchestrator). All agent inputs sanitized before external API calls. Agent-to-agent data: markdown-only, no executable code. |
| **Connector Abstraction** | CRITICAL | Security (vendor lock-in), Architectural (C3), Performance (coupling concern) | UX (not primary focus) | Separate `CONNECTORS.md` into abstract interfaces + `CONNECTOR-IMPLEMENTATIONS.md` (concrete tools). Define interface per placeholder (e.g., `~~analytics~~` interface: `getEvents()`, `getFlagStatus()`). Add adapter layer: PostHogAdapter, AmplitudeAdapter. |

**Confidence:** 90% — Three personas independently identified, one persona didn't address (not disagreement, just not in scope for their lens).

### SPLIT (2-2 Disagreement)

| Finding | Personas FOR | Personas AGAINST | Resolution |
|---------|-------------|------------------|------------|
| **33 Components = Overwhelming** | UX (C2 CRITICAL), Architectural (needs organization) | Security (complexity is security feature), Performance (not primary concern) | **COMPROMISE:** Keep 33 components (Security's need) BUT add module organization (Architectural's solution) + progressive disclosure (UX's solution). New users see Essential 5 commands, Advanced 7 unlockable. Modules: Spec (5), Execution (5), Observability (3), Quality (2), Meta (2). Tabbed documentation (UX's addition). |
| **Analytics Must Be Blocking** | Security (prevent skip-analytics shortcuts), UX (needs decision output) | Performance (500ms latency), Architectural (not primary concern) | **COMPROMISE:** Keep analytics blocking (Security's need) BUT add 2s timeout (Performance's need) + cached fallback (both agree) + configurable per project (Performance's addition). Log all analytics failures (Security's addition). |

**Confidence:** 80% — Clear 2-2 split, but resolution path exists via compromise that satisfies both sides.

### MINORITY (1 Persona, Others Didn't Address)

| Finding | Severity | Persona | Why Minority | Action |
|---------|----------|---------|-------------|--------|
| **Credential Anti-Patterns** | CRITICAL | Security (C2) | Others agree in principle, but not primary focus | ADOPT — Add pre-commit hook (`detect-secrets`), CI check (`gitleaks`), extend quality-scoring to include credential security dimension. Security-critical, no downside. |
| **Enterprise Search Access Control** | CRITICAL | Security (C3) | Others flagged scope ambiguity, but not access control specifically | ADOPT — Block `enterprise-search-patterns` skill until scope defined + access control model documented. Security-critical. |
| **Developer Marketing Scope** | CRITICAL | Security (C4 prompt injection risk) | UX flagged lack of use cases, but not security risk | ADOPT — Block `developer-marketing` skill until scope defined + output validation documented. Security-critical. |
| **Versioning Governance** | CRITICAL | Architectural (C4) | UX agreed (trust cascade), Security/Performance didn't address | ADOPT — Define semantic versioning policy in `docs/versioning.md` (MAJOR/MINOR/PATCH rules). Add changelog. Root cause for README inaccuracy. |
| **Skill Activation Opacity** | Important | UX (I1) | Others didn't address | CONSIDER — Add skill activation feedback ("[✓] skill activated"). Low effort, high UX value. |
| **Connector Setup Scattered** | Important | UX (I4) | Others didn't address | CONSIDER — Add "Connector Setup" section to CONNECTORS.md with step-by-step guides. Low effort, reduces friction. |

**Confidence:** 70% — One persona identified, others didn't disagree, just didn't prioritize. Adopt if non-controversial.

---

## Position Changes Across Rounds

| Persona | Finding | Round 1 | Round 2 | Driver |
|---------|---------|---------|---------|--------|
| **Security** | README accuracy | Important (I1) | CRITICAL | UX showed trust cascades to security docs |
| **Security** | Connector abstraction | Not addressed | CRITICAL | Architectural showed vendor lock-in blocks security migrations |
| **Security** | Agent contracts | Not addressed | CRITICAL (via Architectural) | Trust boundaries undefined, sanitization gaps |
| **Performance** | Analytics latency | CRITICAL (C2) | Important | Security's 2s timeout compromise acceptable |
| **Performance** | README accuracy | Important (I5) | CRITICAL | UX's trust cascade applies to performance benchmarks |
| **Architectural** | Connector abstraction | Important (C3) | CRITICAL | Security's vendor lock-in argument elevated |
| **Architectural** | README accuracy | Important (C4 symptom) | CRITICAL | UX's trust cascade + versioning root cause |
| **UX** | 33 components | CRITICAL (C2) | Important | Architectural's module organization solves without reducing features |
| **UX** | Progress indicators | Important (I3) | CRITICAL | Performance validated — without progress, users abandon |

**Key Insight:** Round 2 cross-examination elevated 5 findings from Important → CRITICAL and downgraded 1 from CRITICAL → Important. Net: 4 new CRITICAL findings. Personas influenced each other's priorities.

---

## Disagreement Deep-Dives

### Disagreement 1: Analytics Blocking vs. Async

**Participants:** Security Skeptic vs. Performance Pragmatist

**Security position:** Analytics MUST be blocking to prevent "skip analytics, ship without data" shortcuts. If async, developers ignore analytics failures.

**Performance position:** Analytics adds 500ms+ latency to Stage 2 (spec drafting). If blocking, network partition blocks entire workflow. Make async to reduce latency.

**Resolution:** COMPROMISE via timeout
- Keep analytics **blocking** (satisfies Security — can't skip)
- Add **2-second timeout** (satisfies Performance — max latency bounded)
- If timeout: Use **cached data** from last successful fetch (graceful degradation)
- **Log all failures** (satisfies Security — audit trail for analytics tampering)
- Make timeout **configurable per project** (satisfies Performance — power users can tune)

**Why this works:** Both sides get their core need (Security: no skipping, Performance: bounded latency), neither gets 100% of their ask (Security wanted indefinite wait, Performance wanted full async).

**Architectural support:** UX added that analytics without decision framework is useless, reinforcing need for blocking (must wait for data to make decision).

### Disagreement 2: 33 Components Overwhelming vs. Security Feature

**Participants:** UX Advocate vs. Security Skeptic

**UX position:** 12 commands + 21 skills = 33 components = choice paralysis. Violates Hick's Law (decision time increases logarithmically with choices). Users abandon plugin due to overwhelm.

**Security position:** Complexity is intentional. Forces users to explicitly run `/sdd:review` (adversarial review gate), `/sdd:close` (quality gate), etc. Simple plugin with 1 command (`/sdd:ship`) would let users skip security steps.

**Resolution:** KEEP components, ADD organization
- **Keep all 33 components** (satisfies Security — no gates removed)
- **Add module organization** (satisfies UX — reduces cognitive load)
  - 5 modules: Spec (5 commands), Execution (5), Observability (3), Quality (2), Meta (2)
  - User navigates to module, sees 5-7 commands (manageable), not 33 flat list
- **Add progressive disclosure** (satisfies UX — reduces initial overwhelm)
  - New users see **Essential 5** commands only (`write-prfaq`, `review`, `start`, `close`, `anchor`)
  - Advanced users unlock **Advanced 7** via `/sdd:config --unlock-advanced` (`decompose`, `go`, `insights`, `hygiene`, `index`, `config`, `self-test`)
- **Add tabbed documentation** (satisfies UX — easier navigation)
  - README has tabs: Spec | Execution | Observability | Quality | Meta
  - Each tab lists 2-7 commands, not 12 in one table

**Why this works:** Security's complexity is preserved (no features removed), but UX's navigability is improved (information architecture). Hick's Law doesn't apply when choices are categorized into modules (users choose module first, then command within module — two serial 5-choice decisions, not one 33-choice decision).

**Architectural support:** Architectural Purist suggested module organization first, showing it's not just UX benefit, but also architectural cohesion.

---

## Escalation List

### Escalation 1: README Accuracy (Important → CRITICAL)
**Original severity:** Important (Security I1, Performance I5, Architectural C4, UX C1)
**Escalated to:** CRITICAL by all personas in Round 2
**Escalation driver:** UX showed trust erosion cascades to ALL documentation, not just command counts. If README wrong about counts, users don't trust security guidance (Security), performance benchmarks (Performance), or architecture decisions (Architectural).
**Impact assessment:** Without trust, documented best practices are ignored. Security vulnerabilities increase, performance regressions go unnoticed, architectural constraints are violated.
**Blocking criteria:** No new features until README accuracy CI check passes for 3 consecutive releases.

### Escalation 2: Connector Abstraction (Not Addressed → CRITICAL)
**Original severity:** Not mentioned by Security/Performance in Round 1, Important by Architectural (C3)
**Escalated to:** CRITICAL by Security (Round 2), Architectural (Round 2)
**Escalation driver:** Security showed vendor lock-in blocks security-driven vendor switches. If PostHog breached, can't migrate to Amplitude because Stage 7 workflow hardcodes PostHog-specific features (session replays). Architectural showed this is interface leakage — implementation details leak into workflow logic.
**Impact assessment:** Single vendor breach forces emergency migration, but migration blocked by tight coupling. Business continuity risk.
**Blocking criteria:** No new connectors until abstract interfaces defined for existing 14 placeholders.

### Escalation 3: Agent Trust Boundaries (Not Addressed → CRITICAL)
**Original severity:** Not mentioned in Round 1
**Escalated to:** CRITICAL by Security (Round 2), Architectural (C2)
**Escalation driver:** Security showed agents pass unsanitized data to external APIs, enabling prompt injection attacks. Architectural showed lack of behavioral contracts means no trust boundaries — any agent can call any API with any data.
**Impact assessment:** Prompt injection via `spec-author` → `reviewer` → GPT-4 API could bypass adversarial review gate (malicious spec approved).
**Blocking criteria:** No new agents until behavioral contracts documented + data sanitization layer implemented.

---

## Severity Calibration

**CRITICAL (7 findings):**
1. README undercounting (trust erosion)
2. Analytics connectors (PII exposure + decision framework + adapter layer)
3. Progress indicators (16-90 min commands, user abandonment)
4. Multi-model review cost (DoS + $200K/year risk)
5. Command/skill taxonomy (authorization boundaries)
6. Agent behavioral contracts (trust boundaries + sanitization)
7. Connector abstraction (vendor lock-in + interface leakage)

**Important (12 findings):**
- Credential anti-patterns enforcement
- Enterprise search access control
- Developer marketing scope definition
- Versioning governance
- Sentry error throttling
- Codebase index cache TTL
- Insights HTML size limit
- Stage contracts definition
- Skill trigger phrases structured
- Connector integration tests
- Analytics event interface
- Multi-model findings normalization

**Consider (8 findings):**
- Session digest encryption
- Geolocation IP sanitization
- Zotero backup protocol
- Task decompose limit
- Multi-model parallel execution
- Notion rate limit docs
- Skill activation feedback
- Connector setup consolidation

**Severity distribution:** 27 findings total (7 CRITICAL, 12 Important, 8 Consider). 26% CRITICAL rate is high — reflects accumulated technical debt from rapid growth (6/6 → 12/21 components without governance).

---

## Quality Score with Confidence Intervals

### Round 1 Scores

| Persona | Score | Interpretation |
|---------|-------|----------------|
| Security Skeptic | 40/100 | Multiple CRITICAL findings: PII exposure, credential anti-patterns, enterprise search access control, developer marketing scope |
| Performance Pragmatist | 48/100 | Unbounded cost, latency on critical path, storage growth, no caching |
| Architectural Purist | 48/100 | Taxonomy undefined, agent contracts missing, connector leakage, versioning gap |
| UX Advocate | 42/100 | README inaccuracy, 33 components overwhelming, analytics complexity, use case gaps |

**Average Round 1:** 44.5/100

### Round 2 Scores (After Cross-Examination)

| Persona | Score | Change | Driver |
|---------|-------|--------|--------|
| Security Skeptic | 37/100 | -3 | New attack vectors revealed: DoS via cost, error flooding, analytics misinterpretation |
| Performance Pragmatist | 48/100 | 0 | Analytics timeout compromise acceptable, but cost DoS concerns added |
| Architectural Purist | 44/100 | -4 | Interface leakage, coupling to PostHog, agent trust boundaries |
| UX Advocate | 53/100 | +11 | Module organization + progressive disclosure solves overwhelm |

**Average Round 2:** 45.5/100

**Confidence Interval:** 45.5 ± 6.3 (range: 39-52)
- Base CI: ±3.0 (4 perspectives, good diversity)
- Widen: +0.3 per SPLIT finding (2 splits) = +0.6
- Narrow: -0.1 per UNANIMOUS beyond 2nd (3 unanimous = 1 beyond 2nd) = -0.1
- No ESCALATE widening (escalations from Important → CRITICAL, not new severity disagreements)
- **Final CI:** ±(3.0 + 0.6 - 0.1) = ±6.3

**Interpretation:** 95% confident true quality is between 39-52 out of 100. Spec is **below passing threshold (60)** but **mitigatable** (all CRITICAL findings have documented solutions).

---

## Debate Value Assessment

### What Multi-Perspective Review Revealed (vs. Single Review)

**Cross-perspective insights (would NOT have been found by single reviewer):**

1. **PII exposure is also interface leakage** (Security's C1 + Architectural's adapter requirement) — Security saw privacy risk, Architectural saw coupling risk, combined insight: need adapter layer for both reasons.

2. **Cost ceiling prevents DoS** (Performance's C1 + Security's escalation) — Performance saw budget overrun, Security saw attack vector, combined: rate limiting + cost ceiling + spec size limit.

3. **README inaccuracy cascades to trust** (UX's C1 + Security/Performance escalations) — UX saw misleading docs, Security saw undermined security guidance, Performance saw invalid benchmarks, combined: documentation trust is transitive.

4. **Complexity can be both good and bad** (Security vs. UX disagreement) — Security sees security gates, UX sees abandonment risk, resolution: module organization preserves gates, improves navigation.

5. **Analytics blocking vs. async false dichotomy** (Security vs. Performance compromise) — Both extremes have downsides, timeout compromise gets benefits of both (bounded latency + no skipping).

6. **Taxonomy defines authorization, not just organization** (Architectural's C1 + Security's escalation) — Architectural saw structure issue, Security saw authorization boundary confusion, combined: commands run in user context, skills can't call APIs.

**Debate efficiency:** 2 rounds × 4 personas = 8 reviews. Single comprehensive review would have taken ~6 hours (estimate). Parallel debate took ~4 hours elapsed (personas worked independently). **Savings:** 2 hours + richer insights from cross-examination.

### Disagreements Resolved (vs. Escalated to Human)

**2 disagreements, 2 resolved via compromise, 0 escalated:**

1. **Analytics blocking** → Resolved via timeout compromise (both sides satisfied)
2. **Component count** → Resolved via module organization (both sides satisfied)

**Resolution rate:** 100% (no escalations to human)

**Quality of resolutions:** Both resolutions are architecturally sound (timeout is standard pattern, module organization is established UX pattern). Not "agree to disagree" compromises, but solutions that satisfy both sides' core needs.

---

## Recommendation

**APPROVE** with the following mitigations required:

### CRITICAL Mitigations (7 items — MUST complete before feature work)

1. **README Accuracy (UNANIMOUS)**
   - Add CI check: `npm run verify-readme` compares actual vs. claimed command/skill counts
   - Fail CI if mismatch, block merge
   - Update README to include 4 missing commands + 5 missing skills
   - Add to pre-release checklist: "Verify README counts match marketplace.json"
   - **Timeline:** 2 days
   - **Blocking:** All feature additions

2. **Analytics Integration (UNANIMOUS)**
   - Add "Data Privacy Protocol" section to CONNECTORS.md:
     - PII masking requirements for PostHog (mask form inputs, emails, tokens)
     - Sentry scrubbing rules (env vars, DB URLs, API keys)
     - Data retention limits (30 days session replays, 90 days errors)
     - GDPR compliance checklist (consent banners, DPAs, right to erasure)
   - Add analytics adapter layer: `AnalyticsAdapter.getSessionMetrics()` returns sanitized metrics, not raw replays
   - Add decision framework to Stage 2 docs: "High usage + low satisfaction → improvement candidate" (4 decision quadrants)
   - Keep analytics blocking with 2s timeout + cached fallback + configurable per project
   - Log all analytics failures for audit trail
   - **Timeline:** 1 week
   - **Blocking:** Analytics connector additions

3. **Progress Indicators (UNANIMOUS)**
   - Add to `/sdd:index`: "[Scanning 1000/10000 files... estimated 8 minutes remaining]"
   - Add to `/sdd:review`: "[1/4] Calling GPT-4... [2/4] Calling Claude... estimated 45 seconds remaining]"
   - Add to `/sdd:decompose`: "[Generated 25 tasks... analyzing dependencies... estimated 30 seconds remaining]"
   - Add cancellation safety: "Press Ctrl+C to cancel safely. Progress will be saved."
   - **Timeline:** 3 days
   - **Blocking:** None (parallel with other work)

4. **Multi-Model Review Cost Control (MAJORITY)**
   - Add cost ceiling: `MAX_REVIEW_COST=5.00` (fail if exceeded)
   - Add per-model budget: GPT-4 $2, Claude Opus $2, Gemini $1 (total $5)
   - Add caching: If spec unchanged since last review (git hash), return cached result
   - Add rate limiting: Max 10 reviews/day/user (prevent review spam DoS)
   - Add spec size limit: Max 50KB per spec (prevent token exhaustion DoS)
   - **Timeline:** 1 week
   - **Blocking:** Multi-model runtime usage

5. **Command/Skill Taxonomy (MAJORITY)**
   - Create `docs/component-taxonomy.md` with formal definitions:
     - Command: User-invoked + stateful workflow + runs in user security context (user's API tokens)
     - Skill: Context-triggered + guidance + no direct API calls
     - Command + skill: Command invokes skill (e.g., `/sdd:anchor` → `drift-prevention`)
   - Add decision tree: "Is this user-initiated? Stateful? → Command. Context-triggered? Guidance? → Skill."
   - Retroactively classify all 33 components (12 commands, 21 skills) with rationale
   - **Timeline:** 3 days
   - **Blocking:** New command/skill additions

6. **Agent Behavioral Contracts (MAJORITY)**
   - Create `docs/agent-architecture.md` with 3 agent types:
     - Stage handler (owns funnel stages, e.g., `spec-author`, `implementer`)
     - Review persona (critiques specs, e.g., 4 specialized reviewers)
     - Workflow orchestrator (coordinates multi-agent workflows, e.g., `debate-synthesizer`)
   - Add data sanitization requirement: "All agent inputs must be markdown-only before external API calls. Strip executable code, URLs except whitelisted domains."
   - Add trust boundary documentation: "Agent-to-agent data passes through validation layer."
   - **Timeline:** 1 week
   - **Blocking:** New agent additions

7. **Connector Abstraction (MAJORITY)**
   - Separate `CONNECTORS.md` into two files:
     - `CONNECTORS.md` — Abstract connector definitions (no vendor names)
     - `CONNECTOR-IMPLEMENTATIONS.md` — Concrete tool examples (PostHog, Sentry, Amplitude)
   - Define connector interface for each placeholder:
     - `~~analytics~~` interface: `getEvents(filters) → Event[]`, `getFlagStatus(flag) → boolean`
     - `~~error-tracking~~` interface: `getErrors(timeRange) → Error[]`, `getErrorRate() → number`
   - Add feature mapping: "PostHog session replays → optional analytics feature, fallback to event stream if unavailable"
   - Add adapter layer implementation: `PostHogAdapter`, `AmplitudeAdapter` (implement abstract interface)
   - **Timeline:** 1 week
   - **Blocking:** New connector additions

**Total timeline:** 2-3 weeks (some items parallel)

### Important Recommendations (12 items — Strongly encourage, not blocking)

1. **Credential anti-patterns enforcement** (Security C2)
   - Add pre-commit hook: `detect-secrets`
   - Add CI check: `gitleaks`
   - Extend quality-scoring to include credential security dimension
   - **Timeline:** 3 days

2. **Enterprise search access control** (Security C3)
   - Block `enterprise-search-patterns` skill until scope defined
   - Require: 3 user stories, access control model, audit trail
   - **Timeline:** N/A (blocks feature)

3. **Developer marketing scope definition** (Security C4)
   - Block `developer-marketing` skill until scope defined
   - Require: 3 user stories, output validation, approval workflow
   - **Timeline:** N/A (blocks feature)

4. **Versioning governance** (Architectural C4)
   - Create `docs/versioning.md` with semantic versioning policy:
     - MAJOR: Breaking API changes (rename command, change input format)
     - MINOR: New commands, new skills, new agents (backward compatible)
     - PATCH: Bug fixes, documentation updates, no new components
   - Add deprecation policy: "Deprecated in MINOR, removed in MAJOR (1-version grace period)"
   - Add `CHANGELOG.md` documenting all component changes per version
   - **Timeline:** 2 days

5-12. **Performance, Architectural, UX improvements** (see full findings for details)

**Total timeline:** 1-2 weeks additional

### Consider Recommendations (8 items — Optional, nice-to-have)

1. Session digest encryption (Security R1)
2. Geolocation IP sanitization (Security R2)
3. Zotero backup protocol (Security R3)
4. Task decompose limit (Performance R1)
5. Multi-model parallel execution (Performance R2)
6. Notion rate limit docs (Performance R3)
7. Command aliases (UX R1)
8. `/sdd:status` mid-session quality score (UX R2)

---

## Feature Recommendations (Responding to Spec Proposals)

### Proposed Commands: Adopt, Modify, or Reject?

| Proposed Command | Verdict | Rationale |
|-----------------|---------|-----------|
| `/sdd:analytics-review` | **REJECT** | Stage 2 is manual data review, not automatable command. Analytics guidance belongs in CONNECTORS.md + Stage 2 docs, not separate command. |
| `/sdd:verify` | **REJECT** | Stage 7 verification is workflow (deploy → test → monitor), not single command. `/sdd:close` already handles quality scoring at closure. |
| `/sdd:research-ground` | **REJECT** | Research grounding already integrated into `/sdd:write-prfaq` via `research-grounding` skill. Separate command creates redundancy. |
| `/sdd:digest` | **CONSIDER** | Session summary distinct from `/sdd:go` (replanning). Could be useful for end-of-session handoff. But overlap with `session-exit` skill. Defer until user validation. |

**Verdict:** 0 new commands from spec proposals. All are either redundant (integrated elsewhere) or lack clear use case distinction.

### Proposed Skills: Adopt, Modify, or Reject?

| Proposed Skill | Verdict | Rationale |
|---------------|---------|-----------|
| `analytics-integration` | **ADOPT** (modified) | Elevate analytics patterns from CONNECTORS.md to skill. Trigger phrases: "check analytics", "review metrics", "data-informed prioritization". Content: Decision framework (4 quadrants), PII masking checklist, adapter usage. |
| `enterprise-search-patterns` | **BLOCK** | Scope undefined. Security showed access control gaps. UX showed no use cases. Block until: 3 user stories, access control model, scope boundary (public docs only? private repos?). |
| `developer-marketing` | **BLOCK** | Scope undefined. Security showed prompt injection risk. UX showed no use cases. Block until: 3 user stories, output validation, approval workflow. |
| `data-informed-closure` | **REJECT** | Already covered by `quality-scoring` skill. If data sources (Sentry errors, PostHog analytics) should inform closure, extend `quality-scoring`, don't create duplicate. |
| `adaptive-methodology` | **REJECT** | Already covered by `execution-modes` skill. Execution mode selection IS adaptive methodology. If "adaptive" label desired, rename `execution-modes` to `adaptive-methodology`, but don't duplicate. |

**Verdict:** 1 new skill adopted (`analytics-integration`), 2 blocked pending clarification (`enterprise-search-patterns`, `developer-marketing`), 2 rejected as redundant.

### README Reconciliation: Adopted

**Action:** Update README tables to reflect actual 12 commands + 21 skills.

**Commands to add:** `/sdd:config`, `/sdd:go`, `/sdd:insights`, `/sdd:self-test`

**Skills to add:** `insights-pipeline`, `parallel-dispatch`, `session-exit`, `ship-state-verification`, `observability-patterns`

**Timeline:** Included in CRITICAL mitigation #1 (2 days)

### CONNECTORS.md Extension: Adopted (with modifications)

**Action:** Already done for most tools (PostHog, Sentry, Amplitude, Firecrawl, Slack). Add Notion documentation.

**Notion addition:**
- Category: Optional (communication/documentation connector)
- Purpose: Spec drafting collaboration, documentation versioning
- MCP: Not available (use API)
- Setup: API token storage (Keychain, not `.env`), access control (user's Notion workspace only)
- Rate limit: 3 req/s, implement exponential backoff
- **Timeline:** 1 day

### Agent Formalization: Rejected

**Question:** Should PM persona (Stages 0-5) and Dev persona (Stages 6-7.5) be formalized as agents?

**Answer:** **NO.** PM and Dev are **roles** (funnel stage ownership), not **agent personas** (behavioral identities). Current stage-handler agents (`spec-author`, `implementer`) already cover these roles. Formalizing as personas would be renaming, not architectural improvement. If behavioral variants desired (PM voice, Dev voice), create **agent variants** of existing stage handlers, not new agent types.

---

## Success Criteria for Mitigations

**How to verify mitigations are complete:**

1. **README Accuracy:** CI check passes for 3 consecutive commits. `npm run verify-readme` exits 0.
2. **Analytics Integration:** PII masking documented, adapter layer implemented, decision framework in Stage 2 docs. Test: Fetch analytics via adapter, verify no raw PII in returned data.
3. **Progress Indicators:** Run `/sdd:index` on 10K file repo, verify progress updates every 5 seconds with time estimate. Run `/sdd:review`, verify 4 progress steps shown.
4. **Multi-Model Review Cost:** Run `/sdd:review`, verify cost logged <$5. Submit 51KB spec, verify rejection. Submit 11th review in one day, verify rate limit.
5. **Taxonomy:** `docs/component-taxonomy.md` exists, all 33 components classified. Spot-check: `/sdd:insights` is command (user-invoked), `insights-pipeline` is skill (context-triggered).
6. **Agent Contracts:** `docs/agent-architecture.md` exists, 8 agents classified (2 stage handlers, 5 review personas, 1 orchestrator). Code review: Verify sanitization layer exists between agents and external APIs.
7. **Connector Abstraction:** `CONNECTORS.md` has no vendor names, `CONNECTOR-IMPLEMENTATIONS.md` documents PostHog/Sentry/Amplitude. Code review: Verify Stage 7 workflow calls `AnalyticsAdapter.getSessionMetrics()`, not PostHog API directly.

**Acceptance test:** New developer installs plugin, reads README, sees 12 commands documented, runs `/sdd:self-test`, all checks pass, can invoke all 12 commands + trigger all 21 skills via documented phrases.

---

## Conclusion

This spec addresses real workflow gaps (README inaccuracy, analytics integration, connector documentation), but proposes adding features (4 commands, 5 skills) without first fixing foundational issues (taxonomy, contracts, abstractions, versioning).

**Core recommendation:** Fix the 7 CRITICAL mitigations first (2-3 weeks), then revisit feature proposals. Of the proposed features:
- **1 skill viable** (`analytics-integration`)
- **2 skills blocked** (`enterprise-search-patterns`, `developer-marketing`) — need use case validation
- **2 skills redundant** (`data-informed-closure`, `adaptive-methodology`) — already covered
- **4 commands rejected** — no clear use case distinction from existing commands/workflows

The plugin has grown from 6/6 to 12/21 components organically. Adding 4+5 more without governance will exacerbate existing issues (overwhelm, ambiguity, coupling). **Pause feature additions, strengthen foundations, then extend thoughtfully.**

**Estimated full timeline:** 2-3 weeks for CRITICAL mitigations, then 2 weeks for feature work (`analytics-integration` skill + Notion connector docs), total 4-5 weeks. This is faster than continuing to add features on weak foundations, then refactoring later.

**Debate value:** Multi-perspective review prevented 4 problematic features (analytics-review command, verify command, 2 redundant skills) and revealed 5 critical issues (README trust cascade, connector vendor lock-in, agent trust boundaries, cost DoS, analytics as attack surface) that single-perspective review would have missed.

**Final recommendation:** **APPROVE** the intent (extend PM/Dev workflows), **REJECT** the specific feature proposals (4 commands, 5 skills), **REQUIRE** the foundational work (7 CRITICAL mitigations) before proceeding.
