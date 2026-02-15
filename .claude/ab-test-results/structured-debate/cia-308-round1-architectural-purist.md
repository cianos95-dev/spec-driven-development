# CIA-308 Round 1: Architectural Purist (Blue)

## Review Metadata
- **Persona:** Architectural Purist (Blue)
- **Focus:** Coupling, cohesion, API contracts, naming, extensibility
- **Date:** 2026-02-15
- **Codebase scan:** cia-308-codebase-scan.md

---

## Executive Summary

This spec proposes PM/Dev workflow extensions through new commands, skills, and connector integrations, plus reconciliation of README documentation debt. From an architectural perspective, the proposal reveals fundamental design tensions: commands vs. skills classification is inconsistent, connector abstractions leak implementation details, agent personas lack clear behavioral contracts, and the README/marketplace.json divergence indicates weak architectural governance.

**Key concern:** The spec treats symptoms (missing commands, outdated README) rather than root causes (no plugin component taxonomy, no versioning strategy, no stability guarantees). The plugin has grown from 6/6 (commands/skills) to 12/21 organically, without architectural vision for what constitutes a "command" vs. "skill" vs. "agent."

**Recommendation:** APPROVE with CRITICAL architectural clarifications required before extending the component surface area.

---

## Critical Findings (Block Until Resolved)

### C1: Command vs. Skill Taxonomy Lacks Formal Definition

**Evidence:**
- README line 170: "Commands are user-invoked workflows triggered with `/sdd:<command>`."
- README line 185: "Skills are passive knowledge that Claude surfaces automatically when relevant context appears in conversation."
- Current reality: 12 commands, 21 skills
- Codebase scan: "`/sdd:insights` processes HTML reports" — is this a command (user invokes) or skill (automatic)?
- Codebase scan: "`analytics-integration` skill" proposed — but analytics is Stage 2 workflow. Why skill, not command?
- No decision tree: "Is this a command or skill?" question has no formal answer

**Architectural tension:**
- Command = imperative, user-controlled, explicit workflow
- Skill = declarative, context-triggered, passive knowledge
- **BUT:** Some commands are just wrappers around skills (e.g., `/sdd:anchor` invokes `drift-prevention` skill)
- **AND:** Some skills trigger workflows (e.g., `session-exit` updates Linear issue statuses — not passive)

**Example ambiguity:**
- `/sdd:insights --archive <path>` — User invokes, so it's a command
- `insights-pipeline` skill — Triggers on "archive insights report" phrase, so it's... also a skill?
- Are they duplicates? Complements? Layers?

**Impact:** High — without taxonomy, every new feature creates "Is this a command or skill?" bikeshedding

**Mitigation required:**
1. Define formal taxonomy in new document: `docs/component-taxonomy.md`
2. Decision tree: "User-initiated + stateful workflow = command. Context-triggered + guidance = skill. Both = command invokes skill."
3. Add examples:
   - Command only: `/sdd:self-test` (no associated skill)
   - Skill only: `prfaq-methodology` (no command trigger)
   - Command + skill: `/sdd:anchor` (command) invokes `drift-prevention` (skill)
4. Add to spec acceptance criteria: "New commands/skills must document which category and why"
5. Retroactively classify all 12 commands and 21 skills in `docs/component-taxonomy.md`

**Without mitigation:** Plugin will grow to 50+ components with no coherent structure.

### C2: Agent Personas Lack Behavioral Contracts

**Evidence:**
- 8 agents exist: `spec-author`, `reviewer`, `implementer`, 4 reviewer personas, `debate-synthesizer`
- Spec asks: "Evaluate whether PM persona (Stages 0-5) and Dev persona (Stages 6-7.5) should be formalized as agents"
- Codebase scan verdict: "PM and Dev are **roles** (funnel stage ownership), not **personas** (behavioral identities)"
- Current agents are stage-handlers (do Stage X) or review-personas (critique from Y perspective)
- No behavioral contract: What can an agent assume about its inputs? What must it guarantee about its outputs?

**Architectural tension:**
- `spec-author.md` is a **stage handler** — does Stages 0-3, no behavioral identity
- `reviewer-security-skeptic.md` is a **persona** — critiques from security lens, has behavioral identity
- These are different abstractions, but both called "agents"

**Example ambiguity:**
- If PM persona agent added: Does it replace `spec-author` agent? Complement it? Wrap it?
- If Dev persona agent added: Does it replace `implementer` agent? What stages does it own?
- If both added: Do they interact? Is there an agent-to-agent protocol?

**Impact:** High — agent abstraction is overloaded, means 3 different things

**Mitigation required:**
1. Define agent types in `docs/agent-architecture.md`:
   - **Stage handler** — Owns funnel stages, input = stage context, output = stage artifacts
   - **Review persona** — Critiques specs, input = spec, output = findings
   - **Workflow orchestrator** — Coordinates multi-agent workflows, input = task graph, output = execution plan
2. Classify existing 8 agents:
   - Stage handlers: `spec-author`, `implementer`
   - Review personas: `reviewer`, 4 specialized reviewers
   - Orchestrators: `debate-synthesizer`
3. Answer spec question: PM/Dev personas are **NOT** new agents, they are **behavioral variants** of existing stage handlers
4. Add to spec acceptance criteria: "New agents must declare type (stage handler | review persona | orchestrator)"

**Without mitigation:** Agent abstraction becomes meaningless, every workflow becomes an "agent."

### C3: CONNECTORS.md Placeholder Convention Leaks Implementation Details

**Evidence:**
- CONNECTORS.md uses `~~placeholder~~` convention for tool-agnostic abstractions
- Examples: `~~project-tracker~~`, `~~version-control~~`, `~~analytics~~`
- BUT: CONNECTORS.md also documents concrete tools: PostHog, Sentry, Amplitude, Firecrawl, Slack
- Example (line 60): "Connector Placeholder | Recommended Tool | MCP Available"
- This table mixes abstraction (placeholder) with implementation (PostHog)

**Architectural tension:**
- Abstraction: "We support any analytics tool"
- Reality: "We document PostHog-specific patterns (session replays, feature flags)"
- If user wants Amplitude instead of PostHog, must they rewrite all Stage 2 and Stage 7 workflows?

**Example ambiguity:**
- CONNECTORS.md line 40: "PostHog: Product analytics, feature flags, session replays"
- These are PostHog-specific features (not all analytics tools have session replays)
- If user uses Amplitude (no session replays), what happens to Stage 7 verification workflow?

**Impact:** Medium — plugin claims tool-agnosticism but leaks vendor-specific assumptions

**Mitigation required:**
1. Separate CONNECTORS.md into two files:
   - `CONNECTORS.md` — Abstract connector definitions (no vendor names)
   - `CONNECTOR-IMPLEMENTATIONS.md` — Concrete tool examples (PostHog, Sentry, etc.)
2. Define connector interface for each placeholder:
   - `~~analytics~~` interface: `getEvents(filters) → Event[]`, `getFlagStatus(flag) → boolean`
   - `~~error-tracking~~` interface: `getErrors(timeRange) → Error[]`, `getErrorRate() → number`
3. Document feature mapping: "PostHog session replays → optional analytics feature, fallback to event stream if unavailable"
4. Add to spec acceptance criteria: "New connectors must define interface, not just list tools"

**Without mitigation:** Tool-specific features become architectural assumptions, blocking alternative implementations.

### C4: README/Marketplace.json Divergence Indicates Weak Versioning Governance

**Evidence:**
- Codebase scan: "README claims 8 commands (actual: 12) — undercounts by 4"
- Codebase scan: "README claims 10 skills (actual: 21) — undercounts by 11"
- marketplace.json is accurate (12 commands, 21 skills)
- plugin.json has version `1.3.0` but README is outdated
- No semantic versioning policy documented

**Architectural question:**
- When does version increment?
- Is adding a command a PATCH (1.3.0 → 1.3.1), MINOR (1.3.0 → 1.4.0), or MAJOR (1.3.0 → 2.0.0)?
- If README is outdated, is that a versioning failure or documentation debt?

**Impact:** Medium — consumers can't trust version numbers, no stability guarantee

**Mitigation required:**
1. Define semantic versioning policy in `docs/versioning.md`:
   - MAJOR: Breaking changes to command/skill APIs (rename command, change input format)
   - MINOR: New commands, new skills, new agents (backward compatible)
   - PATCH: Bug fixes, documentation updates, no new components
2. Add to pre-release checklist: "README component counts match marketplace.json, else increment PATCH"
3. Add changelog: `CHANGELOG.md` documents all component additions/removals per version
4. Add deprecation policy: "Commands deprecated in MINOR, removed in MAJOR (1-version grace period)"

**Without mitigation:** No way to know if upgrading plugin will break workflows.

---

## Important Findings (Strongly Recommend)

### I1: Funnel Stage Mapping Lacks Formal Stage Contracts

**Evidence:**
- 9-stage funnel: 0 (Intake) → 1 (Ideation) → 2 (Analytics) → 3 (PR/FAQ) → 4 (Review) → 5 (Prototype) → 6 (Implementation) → 7 (Verification) → 7.5 (Closure) → 8 (Handoff)
- Connectors mapped to stages (CONNECTORS.md lines 86-99)
- Commands mapped to stages (README command descriptions)
- Skills mapped to stages (README skill descriptions)
- **BUT:** No stage contract defines: "What inputs required? What outputs guaranteed? What can fail?"

**Example ambiguity:**
- Stage 2 (Analytics Review): Is analytics data **required** or **optional**?
- If PostHog unavailable, does Stage 2 block? Skip? Degrade gracefully?
- No contract defines this

**Impact:** Medium — can't validate stage transitions, can't detect incomplete stages

**Recommendation:**
1. Define stage contracts in `docs/stage-contracts.md`:
   - Each stage: Inputs (required + optional), Outputs (guaranteed + best-effort), Failure modes
2. Example: Stage 2 contract:
   - Input (required): Project tracker issue with problem statement
   - Input (optional): Analytics data (PostHog events, Sentry errors)
   - Output (guaranteed): Prioritization decision (proceed/defer/reject)
   - Output (best-effort): Data-informed rationale
   - Failure mode: If analytics unavailable, proceed with qualitative prioritization
3. Add to command implementations: "Check stage contract before executing"

### I2: Skill Trigger Phrases Are Implicit, Not Machine-Readable

**Evidence:**
- Skills activate on "relevant context" (README line 186)
- `insights-pipeline` skill activates on "archive insights report", "extract patterns from insights", etc.
- Trigger phrases documented in skill `description` field (natural language)
- No structured trigger definition (regex, keyword list, semantic embedding)

**Example ambiguity:**
- User says: "Can you process my Insights file?"
- Does this activate `insights-pipeline` skill? "Process" vs. "archive" — close enough?
- No formal definition of phrase similarity threshold

**Impact:** Low — skill activation is unreliable, users don't know how to trigger skills

**Recommendation:**
1. Add structured trigger field to skill definition:
   ```yaml
   triggers:
     exact: ["archive insights report", "process insights report"]
     contains: ["insights", "archive"]
     semantic: ["insights report processing", "insights archival"]
   ```
2. Document in `docs/skill-activation.md`: "Skills activate on exact match > contains > semantic similarity (threshold 0.8)"
3. Add `/sdd:self-test` check: "Verify all skill triggers are non-overlapping"

### I3: Connector Integration Tests Are Missing

**Evidence:**
- 14 connector placeholders documented
- 9 concrete tool integrations mentioned (PostHog, Sentry, Linear, GitHub, Vercel, Firecrawl, Railway, Zotero, Notion)
- No integration tests documented
- No smoke tests for connector availability
- Example: If PostHog API key invalid, how is this detected? At Stage 2 runtime? Pre-flight check?

**Impact:** Low — connector failures discovered late, no early warning

**Recommendation:**
1. Add connector health checks to `/sdd:self-test`:
   - Verify Linear MCP responds
   - Verify GitHub MCP responds
   - Verify PostHog API key valid (make test request)
   - Verify Sentry DSN valid
2. Add to pre-session checklist: "Run `/sdd:self-test` to verify connectors"
3. Add to CI: "Smoke test all MCPs in `.mcp.json`"

### I4: Analytics Connector Abstraction Lacks Metric Normalization

**Evidence:**
- CONNECTORS.md lists 3 analytics tools: PostHog, Amplitude, Mixpanel
- Each has different event schema:
   - PostHog: `{ event: "pageview", properties: { path: "/home" } }`
   - Amplitude: `{ event_type: "pageview", event_properties: { path: "/home" } }`
   - Mixpanel: `{ event: "pageview", properties: { path: "/home" } }`
- Stage 2 workflow: "Fetch analytics data" — from which tool? What schema?

**Impact:** Low — analytics code tightly coupled to one vendor

**Recommendation:**
1. Define analytics event interface:
   ```typescript
   interface AnalyticsEvent {
     name: string;
     timestamp: Date;
     properties: Record<string, any>;
   }
   ```
2. Add adapter layer: PostHogAdapter, AmplitudeAdapter, MixpanelAdapter
3. Stage 2 workflow calls adapter, not PostHog API directly

### I5: Multi-Model Runtime Lacks Model Abstraction

**Evidence:**
- README line 258: "Option C includes a model-agnostic runtime script using litellm"
- litellm provides model abstraction (OpenAI, Anthropic, Google APIs → unified interface)
- **BUT:** Review findings structure is model-specific
- Example: GPT-4 returns findings as `{ critical: [...], important: [...] }`, Claude returns as `{ severity: "critical", findings: [...] }`
- No normalization documented

**Impact:** Low — multi-model review requires manual findings reconciliation

**Recommendation:**
1. Define review findings interface:
   ```typescript
   interface Finding {
     id: string;
     severity: "critical" | "important" | "consider";
     title: string;
     description: string;
     mitigation?: string;
   }
   ```
2. Add model-specific parsers: GPT4Parser, ClaudeParser, GeminiParser
3. Multi-model runtime returns normalized findings, not raw model outputs

---

## Consider Items (Optional Improvements)

### R1: Plugin Structure Follows Anthropic Standard But Lacks Extension Points

**Evidence:**
- README line 399: "v1.3.0 follows the Anthropic plugin-dev standard layout"
- Standard layout: `.claude-plugin/`, `commands/`, `skills/`, `agents/`, `hooks/`
- No extension points documented
- Example: User wants to add custom command — where does it go?
- Example: User wants to override `spec-author` agent — how to register custom agent?

**Recommendation:**
- Add `docs/extending.md`: "How to add custom commands, skills, agents without forking"
- Support plugin composition: `~/.claude/plugins/sdd/` + `~/.claude/plugins/sdd-custom/` → merged

### R2: Execution Mode Decision Heuristic Is Prose, Not Code

**Evidence:**
- README line 232-246: Execution mode decision heuristic (flowchart)
- Decision logic: "Clear scope, low risk → quick. Testable AC → tdd. Uncertain scope → pair."
- Prose description, not executable code
- No `/sdd:classify <task>` command to auto-select mode

**Recommendation:**
- Add `/sdd:classify` command: Reads task description, outputs recommended exec mode with rationale
- Add `execution-mode-classifier` skill: Embeds decision heuristic as rules engine

### R3: Hooks Lack Dependency Injection

**Evidence:**
- `hooks/` directory contains shell scripts: `session-start.sh`, `pre-tool-use.sh`, etc.
- Hooks hardcode paths: `~/.claude/`, `.mcp.json`
- No way to inject test doubles for hooks testing
- No way to customize hook behavior per project

**Recommendation:**
- Add hook configuration: `hooks/config.json` with path overrides
- Add hook testing: `hooks/tests/` with mock file system

---

## Quality Score

| Dimension | Score | Rationale |
|-----------|-------|-----------|
| **Abstraction** | 40/100 | Command vs skill taxonomy undefined (C1), connector placeholders leak implementation (C3), no analytics event interface (I4), no review findings interface (I5). |
| **Cohesion** | 55/100 | Agents overloaded (stage handler vs persona vs orchestrator) (C2), skills trigger on implicit phrases (I2). |
| **Coupling** | 50/100 | Analytics code coupled to PostHog (I4), review code coupled to model outputs (I5), no adapter layers. |
| **Versioning** | 45/100 | No semantic versioning policy (C4), no deprecation policy, no changelog. |
| **Contracts** | 40/100 | No stage contracts (I1), no agent behavioral contracts (C2), no skill activation contracts (I2). |
| **Extensibility** | 60/100 | Follows Anthropic standard layout (good), but no extension points (R1), no plugin composition. |

**Overall Architecture Score: 48/100**

**Confidence:** High (9/10) — Codebase scan provides detailed evidence of component counts, marketplace.json structure, and documentation divergence.

---

## What This Spec Gets Right

1. **Follows Anthropic plugin-dev standard** — `.claude-plugin/plugin.json` + `marketplace.json` structure matches Anthropic's official layout. This is architecturally sound.

2. **Separation of concerns via funnel stages** — 9-stage funnel creates clear phase boundaries (intake → ideation → drafting → review → implementation → verification → closure → handoff). Each stage has distinct inputs/outputs.

3. **Progressive disclosure in skills** — Skills have `SKILL.md` (core methodology) + `references/` (supplementary details). This layering prevents information overload.

4. **Placeholder convention for tool-agnosticism** — `~~project-tracker~~` pattern shows intent to support multiple tools. Execution is flawed (leaks vendor specifics), but intent is correct.

5. **Agent specialization via review personas** — 4 specialized reviewers (security-skeptic, performance-pragmatist, architectural-purist, ux-advocate) + 1 synthesizer is clean multi-perspective architecture.

6. **Quality scoring as extensible rubric** — `quality-scoring` skill provides 0-100 scoring across test/coverage/review dimensions. Can extend to add performance, security, architecture dimensions.

---

## Recommendation

**APPROVE** with the following **CRITICAL mitigations required** before any implementation:

1. **BLOCK C1:** Define formal command vs. skill taxonomy in `docs/component-taxonomy.md`, add decision tree, retroactively classify all 33 components
2. **BLOCK C2:** Define agent types in `docs/agent-architecture.md` (stage handler | review persona | orchestrator), answer PM/Dev persona question (NOT new agents)
3. **BLOCK C3:** Separate CONNECTORS.md into abstract interfaces + concrete implementations, define connector interface for each placeholder
4. **BLOCK C4:** Define semantic versioning policy in `docs/versioning.md`, add changelog, add deprecation policy

**Important recommendations (strongly encourage, not blocking):**
- Define stage contracts with inputs/outputs/failure modes (I1)
- Add structured skill trigger fields (exact/contains/semantic) (I2)
- Add connector health checks to `/sdd:self-test` (I3)
- Add analytics event interface and adapter layer (I4)
- Add review findings interface and model-specific parsers (I5)

**Consider recommendations (optional):**
- Add plugin extension guide and composition support (R1)
- Add `/sdd:classify` command for auto-mode selection (R2)
- Add hook configuration and testing infrastructure (R3)

**Rationale:** The spec addresses real gaps (README accuracy, missing connectors), but the plugin's architecture is under-documented. Adding 4+ new commands and 5+ new skills without clarifying component taxonomy, agent types, and connector abstractions will create technical debt. The mitigations are documentation-only (no code changes required), making this a low-effort, high-value improvement.
