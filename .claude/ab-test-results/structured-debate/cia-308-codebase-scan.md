# CIA-308 Codebase Scan

## Scan Metadata

- **Date:** 2026-02-15
- **Repo:** `/Users/cianosullivan/Repositories/spec-driven-development/`
- **Purpose:** Map existing commands, skills, agents, and connector references for CIA-308 (PM/Dev extension command and skill specification)

---

## Current State Summary

### Commands (12 actual)

Located in `/commands/`:

1. `anchor.md` — Drift prevention via re-anchoring
2. `close.md` — Evidence-based closure with quality scoring
3. `config.md` — Configuration management
4. `decompose.md` — Epic → atomic task breakdown
5. `go.md` — Session continuity (replanning)
6. `hygiene.md` — Issue health audit
7. `index.md` — Codebase indexing for spec-aware discovery
8. `insights.md` — Archive and learn from Insights reports
9. `review.md` — Adversarial spec review
10. `start.md` — Implementation with mode routing
11. `write-prfaq.md` — Interactive PR/FAQ drafting
12. `self-test.md` — Plugin structural validation

### Skills (21 actual)

Located in `/skills/` (directories with `SKILL.md`):

1. `adversarial-review` — 3 perspectives, 4 architecture options
2. `codebase-awareness` — Index-informed spec writing
3. `context-management` — Subagent delegation + context budget
4. `drift-prevention` — Re-anchoring protocol
5. `execution-engine` — Core execution loop + state machine
6. `execution-modes` — 5 modes + decision heuristics
7. `hook-enforcement` — Runtime hook patterns
8. `insights-pipeline` — Insights report archival and pattern extraction
9. `issue-lifecycle` — Ownership table + closure rules
10. `prfaq-methodology` — Working Backwards method + 4 templates
11. `project-cleanup` — Classification matrix, naming rules, deletion protocol
12. `quality-scoring` — 0-100 scoring rubric
13. `research-grounding` — Readiness label progression + citation requirements
14. `research-pipeline` — 4-stage pipeline: discover, enrich, organize, synthesize
15. `spec-workflow` — 9-stage funnel + 3 approval gates
16. `zotero-workflow` — Plugin sequence, Linter/Cita settings, safety rules
17. `parallel-dispatch` — Subagent orchestration patterns
18. `platform-routing` — Cross-platform routing, hook-free exit checklist
19. `session-exit` — End-of-session status normalization
20. `ship-state-verification` — Commit-before-status-update protocol
21. `observability-patterns` — 3-layer monitoring stack

### Agents (8 actual)

Located in `/agents/`:

1. `spec-author.md` — Stages 0-3: intake → spec approval
2. `reviewer.md` — Stage 4: adversarial review
3. `implementer.md` — Stages 5-7.5: implementation → closure
4. `reviewer-security-skeptic.md` — Red persona (attack vectors, injection risks)
5. `reviewer-performance-pragmatist.md` — Orange persona (scaling, caching, latency)
6. `reviewer-architectural-purist.md` — Blue persona (coupling, API contracts, extensibility)
7. `reviewer-ux-advocate.md` — Green persona (user journey, error UX, discoverability)
8. `debate-synthesizer.md` — Multi-round debate consolidation

### Marketplace Configuration

**File:** `.claude-plugin/marketplace.json`

- **Marketplace name:** `ai-pm-plugin-marketplace`
- **Version:** `1.3.0`
- **Commands count (declared):** 12 (matches actual)
- **Skills count (declared):** 21 (matches actual)
- **Agents count (declared):** 7 (but 8 exist — `debate-synthesizer.md` not in manifest)

### Plugin Configuration

**File:** `.claude-plugin/plugin.json`

- Name: `spec-driven-development`
- Version: `1.3.0`
- Description: "Drive software from spec to deployment with AI-agent-native ownership boundaries, adversarial review, and execution mode routing."

### README Claims vs Reality

**README.md (line 172-198):**

| Claimed | Actual | Status |
|---------|--------|--------|
| **8 commands** | **12 commands** | README UNDERCOUNTS by 4 |
| **10 skills** (implied by table structure) | **21 skills** | README UNDERCOUNTS by 11 |

**Specific README command table lists 8:**
1. `/sdd:write-prfaq`
2. `/sdd:review`
3. `/sdd:decompose`
4. `/sdd:start`
5. `/sdd:close`
6. `/sdd:hygiene`
7. `/sdd:index`
8. `/sdd:anchor`

**Missing from README command table (4):**
- `/sdd:config`
- `/sdd:go`
- `/sdd:insights`
- `/sdd:self-test`

**Specific README skill table lists 16:**
1. `spec-workflow`
2. `execution-engine`
3. `execution-modes`
4. `issue-lifecycle`
5. `adversarial-review`
6. `prfaq-methodology`
7. `context-management`
8. `drift-prevention`
9. `hook-enforcement`
10. `quality-scoring`
11. `codebase-awareness`
12. `project-cleanup`
13. `research-pipeline`
14. `zotero-workflow`
15. `research-grounding`
16. `platform-routing`

**Missing from README skill table (5):**
- `insights-pipeline`
- `parallel-dispatch`
- `session-exit`
- `ship-state-verification`
- `observability-patterns`

---

## CONNECTORS.md Analysis

### Current Connector Placeholders

| Placeholder | Purpose | Examples Given | MCP Status |
|-------------|---------|---------------|------------|
| `~~project-tracker~~` | Issue tracking | Linear (default) | MCP available |
| `~~version-control~~` | PRs, code review | GitHub (default) | MCP available |
| `~~ci-cd~~` | Automated review triggers | GitHub Actions | No MCP (platform-native) |
| `~~deployment~~` | Preview/prod deploys | Vercel, Netlify, Railway | MCP available (Railway) |
| `~~analytics~~` | Data-informed drafting | PostHog, Amplitude, Mixpanel | MCP available (PostHog) |
| `~~error-tracking~~` | Error monitoring | Sentry, Bugsnag | MCP available (Sentry) |
| `~~component-gen~~` | UI component generation | v0.dev, Lovable | MCP available (v0) |
| `~~email-marketing~~` | Mailing list management | Mailchimp, SendGrid, Resend | No MCP |
| `~~geolocation~~` | IP-based region inference | Vercel headers, ipapi.co | No MCP |
| `~~research-library~~` | Literature grounding | Zotero | MCP available |
| `~~web-research~~` | Web data for specs | Firecrawl | MCP available |
| `~~communication~~` | Stakeholder notifications | Slack | No MCP (webhook-based) |
| `~~design~~` | Visual prototyping | Figma, v0 | MCP available (v0) |
| `~~observability~~` | Traces, metrics | Honeycomb, Datadog | No MCP (OTEL SDK) |

### Decided Observability Stack (CONNECTORS.md lines 35-73)

Four-tool stack for Stage 7 verification:
1. **PostHog** — Product analytics, feature flags, session replays (Stage 2 + Stage 7)
2. **Sentry** — Error tracking, performance monitoring (Stage 7)
3. **Honeycomb** — OTEL traces, distributed tracing (Stage 7)
4. **Vercel Analytics** — Web vitals, edge performance (Stage 7)

**Decision heuristic provided:** Not every project needs all four. UI features → PostHog + Vercel Analytics. Server-side logic → Sentry + Honeycomb. Multi-service → Honeycomb. Feature flags → PostHog.

### Three-Layer Monitoring (CONNECTORS.md lines 65-73)

Plugin health operates at 3 layers:
1. **Structural validation** — `cc-plugin-eval` (pre-release, CI)
2. **Runtime observability** — `/insights` command (post-session)
3. **App-level analytics** — PostHog/Sentry/Honeycomb (continuous)

---

## Analytics/Data Integration Patterns

### PostHog References

**Locations:**
- `CONNECTORS.md` lines 40-42: "PostHog: Product analytics, feature flags, session replays. Stage 2 (analytics review) + Stage 7 (behavior verification)."
- `CONNECTORS.md` line 60: MCP available (`posthog-mcp`)
- `skills/observability-patterns/SKILL.md` references PostHog as part of app-level analytics
- `skills/spec-workflow/references/stage-details.md` references analytics at Stage 2

**Usage pattern:** Data-informed spec drafting (Stage 2), post-deploy behavior verification (Stage 7), feature flag rollout (Stage 6).

### Sentry References

**Locations:**
- `CONNECTORS.md` lines 41-42: "Sentry: Error tracking, performance monitoring. Stage 7 (error verification)."
- `CONNECTORS.md` line 61: MCP available (`sentry-mcp`)
- `skills/observability-patterns/SKILL.md` references Sentry
- Error tracking connector appears in Stage 7 verification table

**Usage pattern:** Monitor error rates post-deploy, performance regression detection, source map integration.

### Amplitude References

**Locations:**
- `CONNECTORS.md` line 18: Listed as example alongside PostHog, Mixpanel
- No MCP listed
- Not part of "decided stack" (PostHog is preferred)

**Pattern:** Generic analytics placeholder. PostHog is the canonical recommendation.

---

## PM/Dev Persona and Agent Architecture

### Existing Agent Personas

**PM Persona (Stages 0-5):**
- **Agent:** `spec-author.md`
- **Scope:** Intake (Stage 0), Ideation (Stage 1), Analytics Review (Stage 2), PR/FAQ Draft (Stage 3), approval gate checkpoint
- **Not formalized as distinct "PM persona" — it's one agent covering 0-3**

**Dev Persona (Stages 6-7.5):**
- **Agent:** `implementer.md`
- **Scope:** Visual Prototype (Stage 5), Implementation (Stage 6), Verification (Stage 7), Issue Closure (Stage 7.5)
- **Not formalized as distinct "Dev persona" — it's one agent covering 5-7.5**

**Review Persona (Stage 4):**
- **Agent:** `reviewer.md` (generic) + 4 specialized reviewers (security-skeptic, performance-pragmatist, architectural-purist, ux-advocate)
- **Scope:** Adversarial review only

### Agent Component Type Analysis

**Current pattern:** Agents are **single-responsibility specialists** mapped to funnel stages, not personas.

**spec-author.md** handles "PM work" but doesn't embody a "PM persona" — it's a stage handler. Same with **implementer.md** for "Dev work."

**Structured debate agents** (4 reviewers + synthesizer) are **adversarial review personas**, not PM/Dev roles.

**Verdict:** PM and Dev are **roles** (funnel stage ownership), not **agent personas** (behavioral identities). Current architecture treats agents as **stage handlers**, not **role actors**.

---

## Funnel Stage to Tool Mapping

From `CONNECTORS.md` lines 86-99:

| Stage | Required | Recommended | Optional |
|-------|----------|-------------|----------|
| 0: Intake | project-tracker | — | communication |
| 1-2: Ideation + Analytics | project-tracker | analytics | research-library, web-research |
| 3: PR/FAQ Draft | project-tracker, version-control | — | — |
| 4: Adversarial Review | version-control | ci-cd | — |
| 5: Visual Prototype | — | deployment, component-gen | design |
| 6: Implementation | version-control | ci-cd, email-marketing | geolocation |
| 7: Verification | version-control | deployment, analytics, error-tracking, email-marketing | observability |
| 7.5: Closure | project-tracker | — | — |
| 8: Handoff | project-tracker | — | communication |

**Email marketing** appears at Stages 6-7 (dual-write subscriber data during implementation, validate campaigns at verification).

**Geolocation** appears at Stage 6 (IP-based region inference for geo-aware features).

**Analytics** appears at Stages 1-2 (data-informed drafting) AND Stage 7 (behavior verification).

---

## Research Integration

### CIA-299 (Tool-to-Funnel Connector Mapping)

**Not found in repo.** Referenced in CIA-308 spec as a source, but no file exists. Likely a Linear issue not yet committed to repo.

### CIA-302 (Analytics + Data Plugin Integration Patterns)

**Not found in repo.** Referenced in CIA-308 spec as a source, but no file exists. Likely a Linear issue not yet committed to repo.

### CIA-303 (v2 Adaptive Methodology)

**Found:** Full structured debate output in `.claude/ab-test-results/structured-debate/`:
- `cia-303-codebase-scan.md`
- `cia-303-round1-*` (4 personas)
- `cia-303-round2-*` (4 personas)
- `cia-303-synthesis.md`

**Key findings (from synthesis):**
- Drift detection methodology
- Execution mode hooks
- Methodology scoring
- Codebase indexing improvements

**Relevance to CIA-308:** Adaptive methodology influences execution modes (quick/tdd/pair/checkpoint/swarm). New commands may need to integrate with drift detection and hooks.

### Anthropic Pattern Research

**Found:** `docs/competitive-analysis.md` includes comparison with Anthropic's product-management plugin.

**Key distinction:** Anthropic's plugin helps PMs *write* specs. SDD plugin drives specs *through review, implementation, and closure*.

**Complementarity claim (README line 26):** "Complements Anthropic's product-management plugin: That plugin helps PMs write specs (roadmaps, stakeholder updates, PRDs). This plugin drives specs through review, implementation, and closure."

---

## Known Issues (Historical Context)

### README Accuracy Gap (Feb 10 2026 Discovery)

**Source:** `skills/ship-state-verification/SKILL.md` line 15, `skills/project-cleanup/references/do-not-rules.md` line 50

**Discovery:** Alteri cleanup (Feb 10 2026) found README claimed 11 skills and 8 commands when only 7 and 6 existed. Four Linear issues (CIA-293/294/295/296) were marked "Done" but files never shipped.

**Root cause:** Issue status and documentation updated before artifacts committed.

**Current status (as of this scan):**
- README now claims 8 commands (actual: 12) — STILL UNDERCOUNTING by 4
- README skill table shows 16 skills (actual: 21) — STILL UNDERCOUNTING by 5
- marketplace.json shows 12 commands, 21 skills — ACCURATE
- plugin.json does not list skills/commands count — N/A

**Implication for CIA-308:** Any new commands/skills added MUST update README command/skill tables AND marketplace.json. Ship-state verification protocol applies.

---

## Missing v2 Components (Referenced but Not Found)

### Commands

README claims 8, but 12 exist. The 4 missing from README:
- `/sdd:config` — Exists
- `/sdd:go` — Exists
- `/sdd:insights` — Exists
- `/sdd:self-test` — Exists

**None are missing. README is simply outdated.**

### Skills

README table shows 16, but 21 exist. The 5 missing from README:
- `insights-pipeline` — Exists
- `parallel-dispatch` — Exists
- `session-exit` — Exists
- `ship-state-verification` — Exists
- `observability-patterns` — Exists

**None are missing. README is simply outdated.**

---

## CIA-308 Spec Analysis Against Current State

### Spec Requests

1. **New commands** — Candidates: `/sdd:analytics-review`, `/sdd:verify`, `/sdd:research-ground`, `/sdd:digest`
2. **New skills** — Candidates: `analytics-integration`, `enterprise-search-patterns`, `developer-marketing`, `data-informed-closure`, `adaptive-methodology`
3. **Extended CONNECTORS.md** — Replace placeholders with concrete integrations (analytics → PostHog/Sentry/Amplitude, web-research → Firecrawl, communication → Slack, Add: Notion)
4. **README reconciliation** — Claims 10 skills and 8 commands but reality is 21 and 12
5. **Agents component type** — Evaluate whether PM persona (Stages 0-5) and Dev persona (Stages 6-7.5) should be formalized as agents

### Current State Supports

1. **Analytics integration** already present:
   - PostHog/Sentry/Honeycomb/Amplitude mentioned in CONNECTORS.md
   - Stage 2 (analytics review) exists in funnel
   - Stage 7 (verification) includes analytics connectors
   - No dedicated `/sdd:analytics-review` command — Stage 2 is manual
   - No `analytics-integration` skill — analytics guidance lives in CONNECTORS.md and stage-details.md

2. **Verification** partially present:
   - Stage 7 (Verification) exists in funnel
   - `/sdd:close` handles closure quality scoring
   - No dedicated `/sdd:verify` command — verification is Stage 7 workflow, not a command
   - `ship-state-verification` skill exists (commit-before-status-update)
   - `quality-scoring` skill exists (0-100 scoring rubric)

3. **Research grounding** already present:
   - `research-grounding` skill exists
   - `research-pipeline` skill exists
   - Stages 1-2 include research-library and web-research connectors
   - No `/sdd:research-ground` command — research is integrated into `/sdd:write-prfaq`

4. **Session continuity** already present:
   - `/sdd:go` command exists (replanning, session continuation)
   - `session-exit` skill exists (end-of-session status normalization)
   - `drift-prevention` skill exists (re-anchoring protocol)
   - No `/sdd:digest` command

5. **CONNECTORS.md** already extended:
   - PostHog, Sentry, Amplitude, Firecrawl, Slack, Honeycomb, Notion — ALL mentioned
   - Decided observability stack documented
   - Three-layer monitoring stack documented
   - Email marketing connector added (Mailchimp/SendGrid/Resend)
   - Geolocation connector added (Vercel headers/ipapi.co)

6. **README gap** confirmed:
   - README claims 8 commands (actual: 12) — undercounts by 4
   - README claims 10 skills implied (actual: 21) — undercounts by 11
   - marketplace.json is accurate (12 commands, 21 skills)

7. **Agent architecture** already defined:
   - 3 stage-handler agents: spec-author (0-3), reviewer (4), implementer (5-7.5)
   - 4 review persona agents: security-skeptic, performance-pragmatist, architectural-purist, ux-advocate
   - 1 synthesizer agent: debate-synthesizer
   - PM/Dev are **roles** (stage ownership), not **personas** (behavioral identities)
   - No explicit "PM persona agent" or "Dev persona agent" — roles are stage-scoped

---

## Gap Analysis for CIA-308

### What CIA-308 Requests That DOESN'T Exist

1. **`/sdd:analytics-review` command** — Stage 2 exists as funnel stage, but no dedicated command
2. **`/sdd:verify` command** — Stage 7 exists, but no dedicated command (verification is workflow, not command)
3. **`/sdd:research-ground` command** — Research grounding integrated into `/sdd:write-prfaq`, not standalone
4. **`/sdd:digest` command** — No session digest command (closest: `/sdd:go` for replanning)
5. **`analytics-integration` skill** — Analytics guidance lives in CONNECTORS.md, not a skill
6. **`enterprise-search-patterns` skill** — No mention of enterprise search anywhere
7. **`developer-marketing` skill** — No mention of developer marketing anywhere
8. **`data-informed-closure` skill** — Closure scoring exists (`quality-scoring`), but not explicitly data-informed
9. **`adaptive-methodology` skill** — Execution modes exist (`execution-modes`), but not labeled "adaptive methodology"

### What EXISTS But Spec Doesn't Mention

1. **`/sdd:config` command** — Configuration management
2. **`/sdd:go` command** — Session replanning/continuity
3. **`/sdd:insights` command** — Insights report archival
4. **`/sdd:self-test` command** — Plugin structural validation
5. **`insights-pipeline` skill** — Insights archival and learning
6. **`parallel-dispatch` skill** — Subagent orchestration
7. **`session-exit` skill** — End-of-session status normalization
8. **`ship-state-verification` skill** — Commit-before-status-update
9. **`observability-patterns` skill** — 3-layer monitoring stack

### README Reconciliation Options

**Option A:** Define the 4 missing v2 commands and 5 missing skills (as spec suggests)
- Problem: Spec's candidate names don't align with existing gaps

**Option B:** Correct README to match reality (21 skills, 12 commands)
- Requires: Add 5 missing skills to README table, add 4 missing commands to README table
- Simpler, no new development

**Option C:** Hybrid — correct README + define new extensions
- Add missing 5 skills + 4 commands to README
- Define NEW commands/skills for PM/Dev workflow extensions (analytics, marketing, search)

---

## Recommendations for CIA-308 Spec

### 1. README Reconciliation (CRITICAL)

**Action:** Update README to reflect actual 12 commands and 21 skills.

**Commands to add to README table:**
- `/sdd:config` — Configuration management
- `/sdd:go` — Session replanning and continuity
- `/sdd:insights` — Archive and learn from Insights reports
- `/sdd:self-test` — Plugin structural validation

**Skills to add to README table:**
- `insights-pipeline` — Insights report archival and pattern extraction
- `parallel-dispatch` — Subagent orchestration patterns
- `session-exit` — End-of-session status normalization
- `ship-state-verification` — Commit-before-status-update protocol
- `observability-patterns` — 3-layer monitoring stack

### 2. New Command Justification

**Spec candidates vs. reality:**

| Candidate | Exists As | Recommend |
|-----------|-----------|-----------|
| `/sdd:analytics-review` | Stage 2 workflow | **DO NOT ADD** — Stage 2 is manual data review, not automatable command |
| `/sdd:verify` | Stage 7 workflow + `/sdd:close` | **DO NOT ADD** — Verification is workflow, not command. `/sdd:close` handles quality scoring. |
| `/sdd:research-ground` | Integrated into `/sdd:write-prfaq` | **DO NOT ADD** — Already integrated. Separate command creates redundancy. |
| `/sdd:digest` | Partial (`/sdd:go` for replanning) | **CONSIDER** — Session summary/digest distinct from replanning. Could be useful for end-of-session handoff. |

**Verdict:** Only `/sdd:digest` is a viable new command. Others are either workflow stages (not commands) or already integrated.

### 3. New Skill Justification

**Spec candidates vs. reality:**

| Candidate | Exists As | Recommend |
|-----------|-----------|-----------|
| `analytics-integration` | CONNECTORS.md guidance | **CONSIDER** — Elevate analytics patterns from CONNECTORS.md to skill (trigger phrases, Stage 2 workflow, PostHog/Sentry/Amplitude integration patterns) |
| `enterprise-search-patterns` | Not mentioned | **CLARIFY SCOPE** — What is "enterprise search"? Codebase search? Documentation search? Web search? Already have `codebase-awareness` and `web-research` connector. |
| `developer-marketing` | Not mentioned | **CLARIFY SCOPE** — What is "developer marketing"? Content strategy? Launch planning? Not currently in SDD scope. |
| `data-informed-closure` | `quality-scoring` skill | **DO NOT ADD** — Already covered by `quality-scoring`. If data sources (Sentry errors, PostHog analytics) should inform closure, extend `quality-scoring` skill, don't create new skill. |
| `adaptive-methodology` | `execution-modes` skill | **DO NOT ADD** — Execution mode selection IS adaptive methodology. Rename `execution-modes` to `adaptive-methodology` if desired, but don't create duplicate. |

**Verdict:**
- `analytics-integration` — VIABLE (elevate CONNECTORS.md analytics guidance to skill)
- `enterprise-search-patterns` — NEEDS DEFINITION (unclear scope)
- `developer-marketing` — NEEDS DEFINITION (unclear scope, possibly out of scope)
- `data-informed-closure` — REDUNDANT (extend `quality-scoring` instead)
- `adaptive-methodology` — REDUNDANT (rename `execution-modes` if desired)

### 4. CONNECTORS.md Extension

**Already done:**
- Analytics: PostHog (canonical), Sentry, Amplitude, Honeycomb
- Web research: Firecrawl
- Communication: Slack (mentioned)
- Email marketing: Mailchimp, SendGrid, Resend, ConvertKit (added)
- Geolocation: Vercel headers, ipapi.co, MaxMind (added)
- Observability: Honeycomb, Datadog (added)
- Error tracking: Sentry, Bugsnag (added)
- Notion: **NOT MENTIONED**

**Missing:** Notion connector (spec requests this).

**Action:** Add Notion to CONNECTORS.md as optional communication/documentation connector. No MCP available (use API).

### 5. Agent Component Type (PM/Dev Personas)

**Current:** PM and Dev are **roles** (funnel stage ownership), not **agent personas** (behavioral identities).

**Spec question:** Should PM persona (Stages 0-5) and Dev persona (Stages 6-7.5) be formalized as agents?

**Analysis:**
- `spec-author.md` already covers PM role (Stages 0-3)
- `implementer.md` already covers Dev role (Stages 5-7.5)
- Formalizing as "PM persona agent" and "Dev persona agent" would be **renaming**, not new architecture
- Current stage-handler pattern is clearer than persona pattern (stages are objective, personas are subjective)

**Recommendation:** **DO NOT FORMALIZE** PM/Dev as persona agents. Keep current stage-handler pattern. If personas are desired, create **behavioral agent profiles** (PM voice, Dev voice) as **agent variants** of spec-author and implementer, not replacements.

---

## Summary

### Inventory
- **12 commands** (README claims 8 — 4 missing from docs)
- **21 skills** (README claims 10-16 — 5-11 missing from docs)
- **8 agents** (marketplace.json claims 7 — 1 missing from manifest)
- **14 connector placeholders** (all extended with concrete tools)
- **9-stage funnel** (fully mapped to connectors)
- **3-layer monitoring stack** (structural, runtime, app-level)
- **4-tool observability stack** (PostHog, Sentry, Honeycomb, Vercel Analytics)

### Gaps
- README undercounts commands by 4, skills by 5-11
- marketplace.json missing `debate-synthesizer.md` agent
- No dedicated analytics review command (Stage 2 is manual)
- No dedicated verification command (Stage 7 is workflow)
- No session digest command (partial: `/sdd:go` for replanning)
- No standalone research grounding command (integrated into `/sdd:write-prfaq`)
- No analytics-integration skill (guidance in CONNECTORS.md)
- No enterprise-search-patterns skill (undefined scope)
- No developer-marketing skill (undefined scope)
- Notion connector not documented in CONNECTORS.md

### Recommendations
1. **README:** Add 4 missing commands, 5 missing skills to tables
2. **marketplace.json:** Add `debate-synthesizer.md` to agents array
3. **New command:** Consider `/sdd:digest` for session summary (distinct from `/sdd:go` replanning)
4. **New skill:** Consider `analytics-integration` (elevate CONNECTORS.md analytics patterns)
5. **CONNECTORS.md:** Add Notion as optional communication/documentation connector
6. **Agent architecture:** DO NOT formalize PM/Dev personas — keep stage-handler pattern
7. **Spec clarification:** Define scope for "enterprise search patterns" and "developer marketing"
8. **Skill extension:** Extend `quality-scoring` skill to include data-informed closure (Sentry errors, PostHog analytics as inputs)
