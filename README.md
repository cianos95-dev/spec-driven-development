# Claude Command Centre

The orchestration hub for AI-assisted software delivery -- ownership boundaries, adversarial review gates, multi-agent routing, drift prevention, and evidence-based closure from spec to ship.

## Getting Started in 5 Minutes

```bash
# 1. Install
claude plugins add /path/to/claude-command-centre

# 2. Verify (ask Claude)
# "What execution modes are available?"
# Expected: quick, tdd, pair, checkpoint, swarm

# 3. Use
# Tell Claude about your feature idea. Run /ccc:write-prfaq.
# The plugin guides you from there.
```

That's it. Everything below is depth on demand -- the plugin surfaces the right skill automatically based on what you're doing.

## What This Is

Claude Command Centre (CCC) is the orchestration hub that sits between "spec approved" and "feature shipped." It defines *how your AI agent works with you*: when it acts autonomously, when it defers, how it selects implementation strategies, and how it proves work is complete.

Where [Anthropic's product-management plugin](https://github.com/anthropics/knowledge-work-plugins/tree/main/product-management) helps PMs *write* specs (roadmaps, stakeholder updates, PRDs), CCC drives those specs *through review, implementation, and closure* -- orchestrating the full delivery lifecycle with ownership clarity at every stage.

**36 skills, 17 commands, 9 agents, 4 hooks** -- a complete methodology covering the 9-stage funnel from universal intake to async handoff.

## What Makes This Different

**The problem this solves:** Have you ever had your AI agent close an issue prematurely? Or refuse to act because it wasn't sure if it was allowed to? Or spend 30 minutes asking permission for things it should have done autonomously? Or watched it drift from the spec halfway through a session with no way to pull it back? These are ownership boundary failures -- and they're the most common source of friction in AI-assisted development.

1. **Agent ownership model** -- The only plugin that formalizes who closes issues, who sets priorities, and when the agent acts autonomously vs. defers to the human. A clear matrix prevents agents either doing too little (asking permission for everything) or too much (closing issues prematurely). Three-tier closure rules: auto-close, propose-close, and never-close.

2. **Adversarial review architecture** -- 4 architecture options from free CI agents to multi-model API pipelines, with cost/quality/automation trade-off analysis and ready-to-use GitHub Actions workflows. Option C includes a multi-model runtime script with model-agnostic abstraction via litellm, supporting configurable focus modes (security, performance, architecture) and built-in cost tracking.

3. **Execution mode routing** -- Tasks are tagged with one of 5 modes (quick/tdd/pair/checkpoint/swarm) that determine ceremony level, review cadence, and agent autonomy. Not just workflow types -- implementation strategy routing with a decision heuristic tree that makes mode selection reproducible and auditable.

4. **Working Backwards PR/FAQ** -- The only plugin combining Amazon-style Working Backwards methodology with adversarial spec techniques (pre-mortem failure scenarios, inversion analysis, research grounding requirements). Problem statements must not mention the solution. Four templates for different scope levels.

5. **Drift prevention** -- A re-anchoring protocol that re-reads the active spec, git diff, issue state, and unresolved review comments before every task. This prevents the most common failure mode in long sessions: the agent drifting from the spec as context accumulates. No more "I forgot what we were building."

6. **Hook enforcement** -- Claude Code hooks (SessionStart, PreToolUse, PostToolUse, Stop) that enforce workflow constraints at the runtime level, not just via prompts. A PostToolUse hook verifies that file writes align with the active spec before allowing continuation. Workflow rules become engineering constraints, not suggestions.

7. **Quality scoring** -- Quantitative 0-100 closure scores across three weighted dimensions: test quality (40%), scope coverage (30%), and review completeness (30%). Scores gate progression: 80+ enables auto-close, 60-79 proposes closure with gaps noted, below 60 blocks with specific deficiencies listed.

## Design Philosophy

CCC is an **orchestration hub**, not an execution plugin. The distinction matters:

- **Execution plugins** ship scripts, runtime tools, and automation that work with specific models, CLIs, or platforms. When the platform changes, the automation breaks.
- **Orchestration hubs** teach the agent *how to work*: when to act autonomously, when to defer, how to structure reviews, how to select implementation strategies, how to route work across multiple agents. The methodology transfers across tools.

The `~~placeholder~~` convention makes this explicit. Every tool reference (project tracker, CI/CD, deployment platform) is a placeholder you replace with your stack. The 9-stage funnel, ownership model, and review architecture work whether you use Linear or Jira, GitHub or GitLab, Vercel or AWS.

**Principles:**
1. **Ownership before autonomy** -- Define who owns what before defining what the agent can do
2. **Methodology over tooling** -- Portable practices that survive platform changes
3. **Adversarial before implementation** -- Stress-test specs before writing code
4. **Evidence over ceremony** -- Close with proof, not process

## How This Compares

The spec-driven development space for AI coding agents is active, with 30+ plugins addressing various aspects. Here's how CCC fits:

**What we focus on that others don't:**
- Agent/human ownership boundaries with explicit closure rules
- Execution mode selection with decision heuristic tree (not just "what to build" but "how to build it")
- PR/FAQ methodology with pre-mortem and inversion analysis
- Drift prevention via re-anchoring protocol
- Hook enforcement at the Claude Code runtime level
- Codebase indexing for spec-aware code discovery
- Quality scoring with quantitative closure thresholds
- Context window management as codified agent behavior

**What others do better (and we acknowledge):**
- **Autonomous execution loops** -- Tools like claude-workflow ship shell scripts for unattended task queue processing. Our `/ccc:start` handles single-task routing with mode awareness. For unattended processing of tasks decomposed by `/ccc:decompose`, pair with a dedicated execution framework.
- **Dependency task graphs** -- Several plugins model bidirectional dependencies between tasks. Our `/ccc:decompose` produces ordered task lists with dependency annotations but does not enforce execution order programmatically.

**Complementary tools:**
These plugins address adjacent concerns and pair well with CCC:
- [Anthropic's product-management plugin](https://github.com/anthropics/knowledge-work-plugins/tree/main/product-management) for spec writing and roadmap management
- Multi-model review tools for additional adversarial review configurations
- Autonomous execution frameworks for unattended processing of decomposed tasks

**Relationship to Anthropic's product-management plugin:**
We pick up where product-management leaves off. That plugin helps PMs write specs, manage roadmaps, and synthesize research. CCC drives those specs through adversarial review, implementation with mode routing, drift-aware execution, and evidence-based closure.

## Recommended Companion Plugins

CCC is an orchestration hub -- it covers specs, reviews, and multi-agent routing but not code-level patterns or domain knowledge. These companion plugins fill those gaps. None are required.

| Plugin | Category | What It Adds | Install |
|--------|----------|-------------|---------|
| **superpowers** | Process | Debugging methodology, brainstorming, code review discipline, parallel agents | `claude plugins add superpowers@superpowers-marketplace` |
| **developer-essentials** | Domain | Auth patterns, monorepo, SQL optimization, e2e testing | `claude plugins add developer-essentials@claude-code-workflows` |
| **backend-development** | Domain | API design, microservices, event sourcing, CQRS | `claude plugins add backend-development@claude-code-workflows` |
| **python-development** | Language | Async patterns, testing, packaging, performance | `claude plugins add python-development@claude-code-workflows` |
| **code-operations-skills** | Tactical | Bulk code execution, cross-file refactoring | `claude plugins add code-operations-skills@mhattingpete-claude-skills` |
| **visual-documentation-skills** | Output | SVG diagrams, flowcharts, timelines | `claude plugins add visual-documentation-skills@mhattingpete-claude-skills` |
| **context7-plugin** | Docs | Library documentation lookup | `claude plugins add context7-plugin@context7-marketplace` |
| **supabase-pack** | SaaS | Supabase schema, RLS, migrations | `claude plugins add supabase-pack@claude-code-plugins-plus` |
| **vercel-pack** | SaaS | Vercel deployment, edge functions | `claude plugins add vercel-pack@claude-code-plugins-plus` |
| **plugin-dev** | Meta | Plugin authoring guides | `claude plugins add plugin-dev@claude-plugins-official` |

See [COMPANIONS.md](COMPANIONS.md) for funnel mapping and overlap evaluation details.

## Installation

### From Claude Code

```bash
# Add as a plugin
claude plugins add /path/to/claude-command-centre

# Or symlink to your skills directory
ln -s /path/to/claude-command-centre ~/.claude/skills/claude-command-centre
```

### Manual

Clone the repo and symlink it into your Claude Code skills directory:

```bash
git clone https://github.com/cianos95-dev/claude-command-centre.git
ln -s "$(pwd)/claude-command-centre" ~/.claude/skills/claude-command-centre
```

## The Funnel

Every feature, fix, and infrastructure change flows through a 9-stage funnel with 3 human approval gates.

```mermaid
flowchart TD
    S0[Stage 0: Universal Intake] --> S1[Stage 1: Ideation]
    S1 --> S2[Stage 2: Analytics Review]
    S2 --> S3[Stage 3: PR/FAQ Draft]
    S3 --> G1{Gate 1: Approve Spec}
    G1 -->|Approved| S4[Stage 4: Adversarial Review]
    G1 -->|Rejected| S3
    S4 --> G2{Gate 2: Accept Findings}
    G2 -->|Accepted| S5[Stage 5: Visual Prototype]
    G2 -->|Revisions needed| S3
    S5 --> S6[Stage 6: Implementation]
    S6 --> G3{Gate 3: Review PR}
    G3 -->|Approved| S7[Stage 7: Verification]
    G3 -->|Changes requested| S6
    S7 --> S75[Stage 7.5: Issue Closure]
    S75 --> S8[Stage 8: Async Handoff]

    style G1 fill:#f9a825,stroke:#f57f17,color:#000
    style G2 fill:#f9a825,stroke:#f57f17,color:#000
    style G3 fill:#f9a825,stroke:#f57f17,color:#000
```

| Stage | What Happens | Gate |
|-------|-------------|------|
| 0. Universal Intake | Normalize ideas from any source into project tracker | -- |
| 1. Ideation | Explore problem space, gather context, index codebase | -- |
| 2. Analytics Review | Data-informed prioritization via connected analytics | -- |
| 3. PR/FAQ Draft | Write Working Backwards spec with pre-mortem | Gate 1: Human approves spec |
| 4. Adversarial Review | Multi-perspective stress test (up to multi-model) | Gate 2: Human accepts findings |
| 5. Visual Prototype | UI/UX mockups if applicable | -- |
| 6. Implementation | Code with execution mode routing and drift prevention | Gate 3: Human reviews PR |
| 7. Verification | Deploy, test, validate with quality scoring | -- |
| 7.5. Issue Closure | Evidence-based closure with quantitative score | -- |
| 8. Async Handoff | Session summary for continuity | -- |

## Commands

Commands are user-invoked workflows triggered with `/ccc:<command>`.

| Command | Description |
|---------|-------------|
| `/ccc:write-prfaq` | Interactive PR/FAQ drafting with template selection and research grounding |
| `/ccc:review` | Trigger adversarial spec review (Options A-D, including multi-model runtime) |
| `/ccc:decompose` | Break an epic/spec into atomic implementation tasks with mode labels |
| `/ccc:start` | Begin implementation with automatic execution mode routing |
| `/ccc:close` | Evaluate closure with quality scoring (0-100) and structured evidence |
| `/ccc:hygiene` | Audit open issues for label consistency, staleness, and ownership gaps |
| `/ccc:index` | Scan codebase for modules, patterns, and integration points before spec writing |
| `/ccc:anchor` | Re-read active spec, git state, and issue context to prevent drift |
| `/ccc:config` | Manage CCC preferences (gates, execution, scoring, style) |
| `/ccc:go` | Unified entry point -- auto-detect context and route to correct funnel stage |
| `/ccc:insights` | Archive Insights reports and extract actionable patterns |
| `/ccc:self-test` | Run zero-cost in-session plugin validation and coverage audit |

## Skills

Skills are passive knowledge that Claude surfaces automatically when relevant context appears in conversation.

| Skill | Triggers On | What It Provides |
|-------|------------|-----------------|
| `spec-workflow` | Funnel stages, workflow planning | 9-stage funnel with gate definitions |
| `execution-engine` | Task execution, iteration loops | Core execution loop, state machine, replan protocol |
| `execution-modes` | Task implementation, mode selection | 5-mode taxonomy with decision heuristics |
| `issue-lifecycle` | Issue closure, status transitions | Agent/human ownership table, closure rules |
| `adversarial-review` | Spec review, quality assurance | 3 perspectives, 4 architecture options, multi-model runtime |
| `prfaq-methodology` | Spec writing, Working Backwards | 4 templates with research grounding requirements |
| `context-management` | Session planning, delegation | Subagent tiers, context budget rules |
| `drift-prevention` | Mid-session work, context loss risk | Re-anchoring protocol, spec drift detection |
| `hook-enforcement` | Workflow violations, runtime rules | Claude Code hook patterns for constraint enforcement |
| `quality-scoring` | Closure evaluation, review quality | 0-100 scoring rubric across test/coverage/review |
| `codebase-awareness` | New specs, code discovery | Index-informed spec writing, pattern detection |
| `project-cleanup` | Project normalization, convention enforcement | Classification matrix, naming rules, deletion protocol, 10 anti-patterns |
| `research-pipeline` | Literature review, paper discovery, research tools | 4-stage pipeline: discover, enrich, organize, synthesize |
| `zotero-workflow` | Zotero operations, metadata enrichment | Plugin sequence, Linter/Cita settings, safety rules, anti-patterns |
| `research-grounding` | Research-backed features, citation standards | Readiness label progression, PR/FAQ citation requirements |
| `platform-routing` | Cross-platform work, non-CLI sessions | Platform recommendations, hook-free exit checklist, context bridges |
| `insights-pipeline` | Insights reports, pattern extraction | Archive reports, extract friction patterns, track improvement trends |
| `observability-patterns` | Stage 7 verification, monitoring setup | Tool selection (PostHog/Sentry/Honeycomb), plugin validation, release gates |
| `parallel-dispatch` | Multi-session dispatch, parallel phases | Dispatch decision tree, session mode mapping, coordination protocol |
| `planning-preflight` | Spec writing, plan mode, landscape scan | Context gathering, issue overlap detection, strategic zoom-out, timeline validation |
| `session-exit` | Session end, wrap-up, handoff | Status normalization, closing comments, summary tables, context budget checks |
| `ship-state-verification` | Pre-publish, release preparation, completion claims | Evidence-first verification, anti-rationalization enforcement, manifest validation, phantom deliverable detection |
| `pattern-aggregation` | Cross-session trends, improvement trajectory | Pattern matching, friction correlation, preference drift detection, rule effectiveness |
| `tdd-enforcement` | TDD mode, test-first discipline | RED-GREEN-REFACTOR loop, spec-derived test cases, cycle state tracking |
| `debugging-methodology` | Test failures, bug investigation | 4-phase loop (scope, hypothesize, test, verify), spec-anchored root cause analysis |
| `review-response` | PR review comments, adversarial findings | RUVERI protocol, spec-drift-aware triage, pushback guidance |
| `pr-dispatch` | Implementation complete, ready for review | CCC Stage 6 spec-aware review dispatch, code-reviewer agent orchestration |
| `branch-finish` | Branch completion, merge, PR, park, abandon | Stage 6-7.5 bridge: Linear closure, spec status updates, evidence-based completion |

## Cross-Platform Compatibility

CCC works across Claude Code (CLI), Desktop Chat, and Cowork. Commands and skills are 100% portable -- only hooks and stdio MCPs are CLI-specific.

| Component | Claude Code | Desktop Chat | Cowork |
|-----------|:-----------:|:------------:|:------:|
| Commands & Skills | Full | Full | Full |
| Hooks (runtime enforcement) | Full | -- | -- |
| OAuth MCPs (Linear, GitHub) | Full | Full | Full |
| Stdio MCPs (Zotero, arXiv, S2) | Full | -- | -- |
| File system / git | Full | -- | -- |

**Where to do what:**

| Workflow | Recommended Platform |
|----------|---------------------|
| Spec drafting, PR/FAQ workshops, triage | **Cowork** -- interactive connectors, artefact generation |
| Context setup, client routing | **Desktop Chat** -- Projects system customizes context per domain |
| Implementation, TDD, adversarial review | **Claude Code** -- hooks, git, subagents, full MCP stack |

Context flows between surfaces via **Linear issues** (universal state bus) and **GitHub specs** -- no surface operates in isolation. The `platform-routing` skill provides detailed routing recommendations and a hook-free exit checklist for non-CLI sessions.

## Execution Modes

```mermaid
flowchart LR
    T[Task] --> D{Decision Heuristic}
    D -->|Clear scope, low risk| Q[quick]
    D -->|Testable AC| TDD[tdd]
    D -->|Uncertain scope| P[pair]
    D -->|High-risk milestones| C[checkpoint]
    D -->|5+ parallel subtasks| S[swarm]
```

| Mode | When | Agent Autonomy | Ceremony |
|------|------|---------------|----------|
| `quick` | Small, well-understood changes | High | Minimal |
| `tdd` | Testable acceptance criteria | High | Red-green-refactor |
| `pair` | Uncertain scope, needs exploration | Low (human-in-loop) | Interactive |
| `checkpoint` | High-risk, milestone-gated | Medium | Pause at gates |
| `swarm` | 5+ independent parallel subtasks | High | Subagent orchestration |

## Adversarial Review Options

| Option | Cost | Automation | Model Quality | Setup |
|--------|------|-----------|---------------|-------|
| A: CI Agent | $0 | Full | Good | Low |
| B: Premium Agent | ~$40/mo | Full | Very Good | Low |
| C: Multi-Model Runtime | ~$2-8/review | Full | Best (configurable) | Medium |
| D: In-Session | $0 | Manual | Very Good | None |

Option C includes a model-agnostic runtime script using litellm for multi-model adversarial debate. Configure focus modes (security, performance, architecture) to scope the review. Built-in cost tracking per review.

GitHub Actions workflows for Options A and C are included in `skills/adversarial-review/references/`.

## Quality Scoring

`/ccc:close` evaluates issues across three weighted dimensions:

| Dimension | Weight | What It Measures |
|-----------|--------|-----------------|
| Test | 40% | Test coverage, tests passing, edge cases addressed |
| Coverage | 30% | Acceptance criteria addressed, scope completeness |
| Review | 30% | Review comments resolved, adversarial findings addressed |

**Score thresholds:**

| Score | Action |
|-------|--------|
| 80-100 | Auto-close eligible (if ownership rules permit) |
| 60-79 | Propose closure with evidence gaps noted |
| 0-59 | Block -- list specific deficiencies that must be addressed |

Scores are deterministic given the same inputs. The rubric is documented in `skills/quality-scoring/SKILL.md` and can be customized per project.

## Drift Prevention

Before every task, `/ccc:anchor` re-reads:

1. **Active spec** -- Frontmatter, acceptance criteria, and open questions from the PR/FAQ
2. **Git state** -- Diff since last commit, uncommitted changes, branch status
3. **Issue state** -- Current status, labels, and assignment from the project tracker
4. **Review comments** -- Unresolved adversarial findings and PR review threads

This prevents the most common failure mode in long sessions: the agent drifting from the spec as context accumulates. The re-anchoring protocol rebuilds ground truth from source artifacts rather than relying on accumulated session context.

The `drift-prevention` skill activates automatically when session length exceeds configurable thresholds, or can be triggered manually with `/ccc:anchor` at any time.

## Hook Enforcement

Optional Claude Code hooks that enforce workflow constraints at the runtime level:

| Hook | Trigger | What It Enforces |
|------|---------|-----------------|
| `SessionStart` | Session begins | Load active spec, verify context budget, set ownership scope |
| `PreToolUse` | Before file write | Verify write aligns with active spec acceptance criteria |
| `PostToolUse` | After tool execution | Check for ownership boundary violations, log evidence |
| `Stop` | Session ends | Run hygiene check, update issue status, generate handoff |

Hooks are in `hooks/` -- install by copying to your project's `.claude/hooks/` directory. Each hook is independent; enable only the enforcement level you need.

**Why hooks matter:** Prompt-based workflow rules are advisory. A determined agent (or a careless one) can ignore them. Hooks enforce constraints at the Claude Code runtime level, making violations structurally impossible rather than merely discouraged.

## Codebase Indexing

`/ccc:index` scans your repository and produces:

- **Module map** -- Directories, key exports, internal dependencies
- **Pattern summary** -- Frameworks, conventions, test patterns, naming schemes
- **Integration points** -- APIs, shared state, event buses, external service calls

The index feeds into `/ccc:write-prfaq` as a "Current Codebase Context" section, ensuring new specs account for existing patterns rather than proposing redundant implementations. The index is cached and incrementally updated on subsequent runs.

## Issue Closure Rules

The agent follows strict rules about when it can close issues:

| Condition | Quality Score | Action |
|-----------|--------------|--------|
| Agent assignee + single PR + merged + deploy green | >= 80 | Auto-close with evidence |
| Agent assignee + single PR + merged + deploy green | 60-79 | Propose closure with gaps noted |
| Multi-PR, research issues, complex scope | Any | Propose closure, await confirmation |
| Human-assigned or `needs:human-decision` | Any | Never auto-close |
| Any | < 60 | Block -- deficiencies must be addressed first |

## Customization

CCC uses `~~placeholder~~` conventions for organization-specific values. Replace these with your own:

| Placeholder | Replace With | Example |
|-------------|-------------|---------|
| `~~team-name~~` | Your team/org name | `Acme Engineering` |
| `~~PREFIX-XXX~~` | Your issue prefix | `ACME-042` |
| `~~owner/repo~~` | Your GitHub org/repo | `acme/product` |
| `~~project-tracker~~` | Your tracker tool | `Linear`, `Jira`, `Asana` |
| `~~version-control~~` | Your VCS platform | `GitHub`, `GitLab` |
| `~~ci-cd~~` | Your CI/CD platform | `GitHub Actions`, `CircleCI` |
| `~~analytics~~` | Your analytics tool | `PostHog`, `Amplitude` |
| `~~deployment~~` | Your deploy platform | `Vercel`, `AWS`, `Railway` |
| `~~error-tracking~~` | Your error tracker | `Sentry`, `Bugsnag` |

## Connectors

CCC works best with these connected services (see [CONNECTORS.md](CONNECTORS.md) for details):

**Required:** Project tracker (Linear, Jira, Asana) + Version control (GitHub, GitLab)

**Recommended:** CI/CD, Deployment platform, Analytics, Error tracking

**Data-informed closure:** Connect analytics (PostHog, Amplitude) and error tracking (Sentry) to enable Stage 7 data-informed verification. Quality scores incorporate deploy health and error rates when these connectors are available.

## Tools We Optimize For

CCC's methodology is tool-agnostic (see [Customization](#customization)), but we test and document integration patterns for these specific tools:

### Core (configured in ~/.mcp.json)

| Tool | Funnel Role | Why |
|------|-------------|-----|
| **Linear** | Issue tracking across all stages | Agent ownership model, label taxonomy, closure protocol |
| **GitHub** | Spec versioning + adversarial review | PR-based review, Actions for Options A/C, hook enforcement |

### Recommended

| Tool | Funnel Role | Education Tier? |
|------|-------------|-----------------|
| **Vercel** | Stage 5 previews + Stage 7 deployment | Hobby free; Pro via education |
| **v0.dev** | Stage 5 component generation | Free tier; Premium via .edu |
| **Sentry** | Stage 7 error tracking + quality scoring input | Education plan available |
| **PostHog** | Stage 2 analytics + Stage 7 data-informed closure | 1M events/mo free |
| **Firecrawl** | Research grounding (web data) | STUDENTEDU code for credits |

### Multi-IDE

| Tool | Role | Education Tier? |
|------|------|-----------------|
| **Claude Code** | Primary implementation environment | Included in Anthropic plan |
| **Cursor** | Parallel implementation | 1yr Pro free via education |
| **OpenAI Codex** | Background task delegation | Via OpenAI API |

The methodology is portable across IDEs. The spec format and funnel stages are tool-agnostic; only command invocation differs per environment.

### Additional Education Tiers

These tools pair well with the methodology and offer student pricing:

- **GitHub Student Pack** -- Copilot Pro, Actions minutes, partner offers
- **Figma** -- Professional free for students (design to v0 workflow)
- **JetBrains** -- All Products Pack free (alternative IDE)
- **1Password** -- 1yr free via GitHub Pack (credential management)

## Plugin Structure

v1.6.0 follows the [Anthropic plugin-dev](https://github.com/anthropics/claude-plugins) standard layout.

```
claude-command-centre/
├── .claude-plugin/
│   ├── plugin.json               # Canonical plugin manifest (v1.6.0)
│   └── marketplace.json          # Marketplace metadata
├── agents/
│   ├── spec-author.md            # Stages 0-3: intake → spec approval
│   ├── reviewer.md               # Stage 4: adversarial review orchestrator
│   ├── reviewer-architectural-purist.md  # Adversarial perspective: architecture
│   ├── reviewer-performance-pragmatist.md # Adversarial perspective: performance
│   ├── reviewer-security-skeptic.md      # Adversarial perspective: security
│   ├── reviewer-ux-advocate.md           # Adversarial perspective: UX
│   ├── debate-synthesizer.md     # Synthesize multi-perspective review findings
│   ├── code-reviewer.md          # Stage 6: spec-aware code review
│   └── implementer.md            # Stages 5-7.5: implementation → closure
├── commands/
│   ├── write-prfaq.md            # Interactive PR/FAQ drafting
│   ├── review.md                 # Adversarial spec review (multi-model)
│   ├── decompose.md              # Epic → atomic task breakdown
│   ├── start.md                  # Implementation with mode routing
│   ├── close.md                  # Evidence-based closure with quality scoring
│   ├── hygiene.md                # Issue health audit
│   ├── index.md                  # Codebase indexing for spec-aware discovery
│   ├── anchor.md                 # Drift prevention via re-anchoring
│   ├── config.md                 # Manage CCC preferences
│   ├── go.md                     # Unified workflow entry point
│   ├── insights.md               # Archive and extract Insights patterns
│   └── self-test.md              # In-session plugin validation
├── skills/
│   ├── adversarial-review/
│   │   ├── SKILL.md              # Perspectives + architecture options
│   │   └── references/
│   │       ├── github-action-copilot.yml
│   │       └── github-action-api.yml
│   ├── codebase-awareness/
│   │   └── SKILL.md              # Index-informed spec writing + pattern detection
│   ├── context-management/
│   │   ├── SKILL.md              # Subagent delegation + context budget
│   │   └── references/
│   │       ├── session-economics.md
│   │       └── tool-discipline.md
│   ├── debugging-methodology/
│   │   └── SKILL.md              # 4-phase spec-aware debugging loop
│   ├── drift-prevention/
│   │   └── SKILL.md              # Re-anchoring protocol + drift detection
│   ├── execution-engine/
│   │   ├── SKILL.md              # Core loop + state machine
│   │   └── references/
│   │       ├── replan-protocol.md
│   │       ├── retry-budget.md
│   │       └── configuration.md
│   ├── execution-modes/
│   │   └── SKILL.md              # 5 modes + decision heuristics
│   ├── hook-enforcement/
│   │   └── SKILL.md              # Runtime hook patterns + constraint enforcement
│   ├── insights-pipeline/
│   │   └── SKILL.md              # Archive reports + extract patterns
│   ├── issue-lifecycle/
│   │   ├── SKILL.md              # Ownership table + closure rules
│   │   └── references/
│   │       ├── project-hygiene.md
│   │       └── content-discipline.md
│   ├── observability-patterns/
│   │   ├── SKILL.md              # Monitoring stack + tool selection
│   │   └── references/
│   │       └── structural-validation.md
│   ├── parallel-dispatch/
│   │   ├── SKILL.md              # Multi-session dispatch rules
│   │   └── references/
│   │       └── dispatch-examples.md
│   ├── pattern-aggregation/
│   │   └── SKILL.md              # Cross-session pattern matching + trajectories
│   ├── planning-preflight/
│   │   └── SKILL.md              # Pre-planning context gathering
│   ├── platform-routing/
│   │   └── SKILL.md              # Cross-platform routing, hook-free exit checklist
│   ├── prfaq-methodology/
│   │   ├── SKILL.md              # Working Backwards method
│   │   └── templates/
│   │       ├── prfaq-feature.md
│   │       ├── prfaq-research.md
│   │       ├── prfaq-infra.md
│   │       └── prfaq-quick.md
│   ├── project-cleanup/
│   │   ├── SKILL.md              # Classification matrix, naming rules, deletion protocol
│   │   └── references/
│   │       └── do-not-rules.md
│   ├── quality-scoring/
│   │   └── SKILL.md              # 0-100 scoring rubric + threshold configuration
│   ├── research-grounding/
│   │   └── SKILL.md              # Readiness label progression + citation requirements
│   ├── research-pipeline/
│   │   └── SKILL.md              # 4-stage pipeline: discover, enrich, organize, synthesize
│   ├── review-response/
│   │   └── SKILL.md              # RUVERI protocol for spec-drift-aware review triage
│   ├── session-exit/
│   │   └── SKILL.md              # End-of-session normalization protocol
│   ├── pr-dispatch/
│   │   └── SKILL.md              # CCC Stage 6 spec-aware review dispatch
│   ├── branch-finish/
│   │   └── SKILL.md              # Stage 6-7.5 branch completion with Linear integration
│   ├── ship-state-verification/
│   │   └── SKILL.md              # Evidence-first verification + anti-rationalization enforcement
│   ├── spec-workflow/
│   │   ├── SKILL.md              # 9-stage funnel + 3 approval gates
│   │   └── references/
│   │       ├── stage-details.md
│   │       └── scope-discipline.md
│   ├── tdd-enforcement/
│   │   └── SKILL.md              # RED-GREEN-REFACTOR discipline + spec-derived tests
│   └── zotero-workflow/
│       └── SKILL.md              # Plugin sequence, Linter/Cita settings, safety rules
├── hooks/
│   ├── hooks.json                # Hook registration (all lifecycle events)
│   ├── session-start.sh          # Load spec, verify context budget
│   ├── pre-tool-use.sh           # Verify write alignment with spec
│   ├── post-tool-use.sh          # Check ownership boundary violations
│   ├── stop.sh                   # Hygiene check, status update, handoff
│   └── scripts/
│       └── ccc-stop-handler.sh   # Execution engine stop handler
├── examples/
│   ├── sample-prfaq.md           # Filled-out PR/FAQ
│   ├── sample-closure-comment.md # Closure comment with quality score
│   ├── sample-review-findings.md # Adversarial review output
│   ├── sample-index-output.md    # Codebase index example
│   └── sample-anchor-output.md   # Re-anchoring context rebuild
├── CONNECTORS.md                 # Data source documentation
├── README.md
└── LICENSE                       # Apache 2.0
```

**Progressive disclosure:** Core methodology lives in each `SKILL.md` (~1,500-2,000 words). Supplementary content (protocol details, anti-patterns, troubleshooting) lives in `references/` subdirectories and is loaded on demand via reference pointers.

## Example Workflow

A typical end-to-end flow using CCC:

1. **Index:** Run `/ccc:index` -- scan the codebase to understand existing patterns and modules
2. **Intake:** Idea arrives via chat, voice memo, or planning session
3. **Draft:** Run `/ccc:write-prfaq` -- select template, answer prompts, get a structured spec with codebase context
4. **Review:** Run `/ccc:review` -- choose Option D for immediate feedback, or commit spec to trigger Options A-C (including multi-model runtime)
5. **Address findings:** Revise spec based on Critical and Important findings
6. **Decompose:** Run `/ccc:decompose` -- spec breaks into atomic tasks with execution mode labels
7. **Implement:** Run `/ccc:start PROJ-042` -- task routes to the right execution mode. `/ccc:anchor` fires before each task to prevent drift
8. **Close:** Run `/ccc:close` -- quality score evaluates test/coverage/review, closure rules determine action, evidence is structured automatically
9. **Audit:** Run `/ccc:hygiene` periodically to catch label drift, stale issues, and ownership gaps

## Label Taxonomy

CCC uses two label families:

**Spec lifecycle:** `spec:draft` → `spec:ready` → `spec:review` → `spec:implementing` → `spec:complete`

**Execution mode:** `exec:quick` | `exec:tdd` | `exec:pair` | `exec:checkpoint` | `exec:swarm`

Optional labels for additional workflows:
- `needs:human-decision` -- blocks agent from auto-closing
- `research:needs-grounding` → `research:literature-mapped` → `research:methodology-validated` → `research:expert-reviewed`
- `template:prfaq-feature` | `template:prfaq-infra` | `template:prfaq-research` | `template:prfaq-quick`

## Troubleshooting

### Plugin fails to load ("failed to load · 1 error")

This typically means the plugin cache is stale or the marketplace reference is broken.

1. **Check for stale marketplace references** (common after repo renames):
   ```bash
   cat ~/.claude/plugins/known_marketplaces.json | grep ai-pm-plugin-marketplace
   ```
   If the repo name is wrong, clean and reinstall:
   ```bash
   rm -rf ~/.claude/plugins/cache/ai-pm-plugin-marketplace/
   rm -rf ~/.claude/plugins/marketplaces/ai-pm-plugin-marketplace/
   ```
   Then remove the stale entry from `~/.claude/plugins/known_marketplaces.json` and reinstall:
   ```
   /plugin marketplace add cianos95-dev/claude-command-centre
   /plugin install claude-command-centre@ai-pm-plugin-marketplace
   ```

2. **Verify the cache exists** after installation:
   ```bash
   ls ~/.claude/plugins/cache/ai-pm-plugin-marketplace/claude-command-centre/
   ```

### MCP auth errors ("does not support dynamic client registration")

This plugin does **not** ship MCP servers. If you see MCP auth errors:

- Check if a project-level `.mcp.json` exists in the repo root — delete it (this repo gitignores it)
- HTTP MCPs using OAuth (e.g. Linear at `mcp.linear.app`, GitHub at `api.githubcopilot.com`) require authentication via **Claude Desktop Settings UI** or **Cowork**, not project-level `.mcp.json`
- Configure all MCPs in your global `~/.mcp.json` instead

### Plugin source types

| Source | Works in Claude Code | Works in Cowork | Auto-updates | Notes |
|--------|---------------------|-----------------|-------------|-------|
| `github` | Yes | Yes | With `GITHUB_TOKEN` | **Production default** |
| `directory` | Yes | No | N/A | Development-only; Cowork runs in sandboxed VM |
| `url` | Yes | Yes | With credentials | Alternative to `github` |

For private repos, set `GITHUB_TOKEN` with `repo` scope in your shell environment for background auto-updates.

### After repo renames

Claude Code's `known_marketplaces.json` retains the old repo reference after a rename. GitHub redirects handle git operations, but metadata gets stale. To fix:

1. Remove the stale entry from `~/.claude/plugins/known_marketplaces.json`
2. Delete the marketplace clone: `rm -rf ~/.claude/plugins/marketplaces/<marketplace-name>/`
3. Re-add: `/plugin marketplace add <owner>/<new-repo-name>`

### Marketplace vs plugin

- A **marketplace** is a git repo with `.claude-plugin/marketplace.json` listing one or more plugins
- A **plugin** is a directory with `.claude-plugin/plugin.json` plus `skills/`, `commands/`, `agents/`, `hooks/`
- The marketplace wrapper is **always required** — there is no direct plugin install in Claude Code
- Single-plugin repos use `"source": "./"` (plugin content at repo root alongside marketplace.json)
- Multi-plugin repos use `"source": "./plugins/<name>"` for each plugin

## License

Apache 2.0 -- see [LICENSE](LICENSE).
