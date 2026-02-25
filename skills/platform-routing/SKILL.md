---
name: platform-routing
description: |
  Recommends the optimal Claude platform (Code, Cowork, Desktop Chat) for each CCC workflow stage.
  Provides hook-free exit checklists for non-CLI contexts and Desktop Chat project patterns for client context routing.
  Use when starting a new workflow stage, asking where to do something, beginning spec drafting, triage, or implementation,
  ending a session in Cowork or Desktop Chat, or setting up a new client or project context.
  Trigger with phrases like "where should I do this", "which platform for spec drafting", "should I use Cowork or Code",
  "set up a Desktop Chat project", "what's the exit checklist for Cowork".
compatibility:
  surfaces: [code, cowork, desktop]
  tier: universal
---

# Platform Routing

Route CCC workflow stages to the platform where they work best. These are **recommendations, not blockers** — everything technically works everywhere, but some platforms have capabilities that make specific stages significantly more effective.

## Platform Routing Table

| Workflow Stage | Recommended Platform | Why |
|----------------|---------------------|-----|
| Context setup / client routing | Desktop Chat Projects | Pre-loads domain-specific instructions, files, and memory per client |
| Quick questions, brainstorming | Desktop Chat | Lightweight, no setup, fast turnaround |
| Spec drafting (interactive) | Cowork | Artefact generation, interactive connector UIs |
| PR/FAQ workshops | Cowork | Interactive drafting, stakeholder-facing output |
| Issue triage / sprint planning | Cowork | Linear connector interactive mode |
| Status reviews / project updates | Cowork | Visual, artefact-oriented |
| Spec writing (file-based) | Claude Code | Needs file system for `docs/specs/` |
| Adversarial review (`/ccc:review`) | Claude Code | Requires subagent Task tool for multi-agent review |
| Implementation / TDD | Claude Code | Hooks enforce guardrails, git access, full MCP stack |
| Research scoping (what to ground) | Cowork | Interactive discussion to define research questions, identify gaps, choose search strategy |
| Research execution (grounding) | Claude Code | Zotero, arXiv, Semantic Scholar, OpenAlex are stdio MCPs (CLI-only) |
| Agent dispatch (delegation) | Cowork | Linear connector interactive mode for delegation; see CONNECTORS.md § Agent Dispatch Protocol |
| Visual artefact creation | Cowork | Diagrams, architecture visuals, stakeholder-facing graphics via artefact generation |
| UI prototyping — component generation | Claude Code (v0 MCP) | v0 generates React components from descriptions; needs project-level MCP |
| UI prototyping — high-fidelity mockups | Cowork / Desktop (Figma) | Figma OAuth connector; pixel-perfect design with design system tokens |
| Design system inspection / .pen editing | Claude Code (Pencil MCP) | 13 Pencil MCP tools for .pen file operations; deferred loading via ToolSearch |
| Architecture diagrams | Claude Code | `visual-documentation-skills` plugin for SVG output — NOT for UI prototyping |
| Insights pipeline (`/ccc:insights`) | Claude Code | Requires file system for data collection and analysis |
| Agent dispatch (via @mention/delegateId) | Linear (@mention or delegate) | Native Linear mechanism -- agents receive webhook events directly via AgentSessionEvent |

### When to suggest a platform switch

If the user starts a workflow stage on a suboptimal platform, **suggest** (never block):

- "This would work better in Cowork — you'd get interactive artefact generation for this spec draft."
- "Research grounding needs Zotero/arXiv access which is CLI-only. Consider switching to Claude Code."
- "For adversarial review, Claude Code's subagent system enables parallel reviewer agents."
- "Research scoping (defining questions and strategy) works well in Cowork — switch to Code when you're ready to execute the actual searches."
- "Agent delegation is best done in Cowork where you can interact with the Linear connector. The dispatch itself happens through Linear's delegation field."
- "For diagrams and visual artefacts, Cowork's artefact generation is the right surface — Claude Code doesn't produce visual outputs."
- "For UI prototyping, use v0 in Claude Code (component generation) or Figma in Desktop/Cowork (high-fidelity mockups)."
- "For .pen file design work, Claude Code has the Pencil MCP with 13 tools for batch design operations."

## Agent Dispatch via @mention

Linear's @mention and delegateId mechanisms are a dispatch surface in their own right -- users trigger agent actions directly from Linear issues without switching to Claude Code, Cowork, or Desktop Chat. The **mechanism-router** skill defines the full dispatch pipeline; the **agent-session-intents** skill defines the intent schema and parsing rules.

### How It Works

1. **User triggers dispatch** in Linear: writes `@Claude review CIA-234` in a comment (mention), sets the Delegate field to Claude (delegateId), or assigns Claude as the issue assignee (assignee).
2. **Linear fires webhook** (for mention/delegateId) or agent polls (for assignee).
3. **Mechanism router** detects the trigger mechanism and either parses intent from the comment body or infers it from issue state.
4. **Router validates preconditions** and selects the appropriate handler + agent.
5. **Handler executes** and posts results back to the Linear issue as a comment.

### When to Use @mention/delegateId vs. Other Surfaces

| Scenario | Surface | Rationale |
|----------|---------|-----------|
| Quick status check on an issue | @mention (`@Claude status CIA-XXX`) | Stays in Linear, no context switch |
| Trigger implementation of a spec-ready issue | delegateId (set Delegate field) | State-based inference picks the right action |
| Interactive spec drafting with iteration | Cowork | Needs artefact generation and interactive refinement |
| TDD implementation with git access | Claude Code | Needs file system, hooks, full MCP stack |
| Bulk delegation to background agent | delegateId or assignee | Factory picks up via Linear integration |
| Adversarial review with parallel personas | Claude Code (then results posted to Linear) | Needs subagent Task tool for multi-agent review |

### Agent x Intent Eligibility (Platform-Routing Context)

This is the same matrix from the mechanism-router skill, presented here for platform routing decisions. It answers: "Which agents can handle which intents when dispatched via Linear?"

| Intent | Claude | Factory | Cursor | Copilot | Codex | cto.new | Amp |
|--------|:------:|:-------:|:------:|:-------:|:-----:|:-------:|:---:|
| `review` | Y | -- | -- | Y (PR only) | -- | -- | -- |
| `implement` | Y | Y | Y | -- | Y | Y | Y |
| `gate2` | Y | -- | -- | -- | -- | -- | -- |
| `dispatch` | Y | Y | -- | -- | -- | -- | -- |
| `status` | Y | -- | -- | -- | -- | -- | -- |
| `expand` | Y | -- | -- | -- | -- | -- | -- |
| `help` | Y | -- | -- | -- | -- | -- | -- |
| `close` | Y | -- | -- | -- | -- | -- | -- |
| `spike` | Y | Y | -- | -- | -- | -- | -- |
| `spec-author` | Y | -- | -- | -- | -- | -- | -- |

### Cross-Skill References for Dispatch

- **mechanism-router** skill -- Unified entry point, handler registration, agent selection tree
- **agent-session-intents** skill -- Intent schema v2, keyword patterns, state-based inference
- **factory-dispatch** skill -- Background agent dispatch via Factory (native Linear delegation) or Amp/cto.new (overflow)

## Context Sharing Across Surfaces

No surface operates in isolation. Context flows through artefacts, not platform-native memory:

| Bridge | Flow | What transfers |
|--------|------|----------------|
| **Linear issues** | Any surface → Any surface | Specs, status, decisions, assignments |
| **Linear plan documents** | Code → Linear → Cowork (or reverse) | Promoted session plans (`/ccc:plan --promote`). Written in Code with hook-enforced quality, accessible from Cowork via MCP. See `plan-promotion` skill. |
| **GitHub specs** | Code ↔ Cowork | `docs/specs/` files readable via GitHub MCP |
| **Desktop Project Files** | Chat → Cowork | Domain docs, instructions, memory (inherited on "Create task") |
| **CLAUDE.md** | Repo → Code | Project-level instructions, MCP config |
| **Cowork spec artefact** | Cowork → Linear → Code | Spec drafted in Cowork, attached to Linear issue, implemented in Code |

**Linear is the universal state bus.** All surfaces have Linear MCP access (OAuth). When handing off between surfaces, ensure the Linear issue contains current state: spec link, status, decisions made, and any blockers.

## The Three Platforms

### Claude Code — The Workshop
Full enforcement mode. Hooks active, all guardrails on, complete MCP stack (13 global + project-level), subagent delegation, file system and git access.

**Plugin features at full power:** All 9 commands, all skills, all 4 hooks (scope guard, drift detection, exit hygiene), insights pipeline, adversarial review with parallel subagents.

### Cowork — The War Room
PM workflow mode. Interactive connector UIs (Linear boards, Notion pages), one-off artefact generation (polished docs, visual specs, presentations), collaborative sessions where the conversation is the deliverable.

**Plugin features available:** All commands and skills work. No hooks — use the exit checklist below. OAuth MCPs (Linear, GitHub) available. No stdio MCPs, no file system, no subagents.

**Best for:** Spec drafting workshops, PR/FAQ co-authoring, issue triage with Linear connector, sprint planning, status reviews, stakeholder-facing artefact creation.

### Desktop Chat — The Context Router
NOT a PM work surface. Its differentiator is the **Projects system** (Memory, Instructions, Files) that customizes context per client or domain before spawning Cowork tasks.

**Cognito Playbook pattern:** Each client/domain gets its own Desktop Chat project. Project Instructions customize Claude's behavior. Project Files pre-load domain-relevant docs. "Create task" spawns a Cowork session that inherits this context.

**Plugin role:** Minimal — general methodology guidance. Quick questions, brainstorming, decision capture. The plugin defers to the project's own context.

### The Flow

```
Desktop Chat (context routing)
  └── Project: "Client X" (Instructions + Files + Memory)
       └── "Create task" → spawns Cowork session with project context
            └── Cowork: PM artefacts, triage, spec drafting
                 └── Linear issue created (state bus)
                      └── Claude Code: implementation, research, TDD
                           └── PR → merge → Linear closure
```

## Hook-Free Exit Checklist

When running in Cowork or Desktop Chat (where hooks are unavailable), manually run this checklist before ending the session. This compensates for the `stop.sh` hook's automated reminders.

### Session Exit Protocol (Non-CLI)

1. **Status normalization:** Are all Linear issues touched in this session at the correct status? Update any that changed.
2. **Sub-issue capture:** Was any out-of-scope work discovered? Create sub-issues immediately — don't add scope to parent issues.
3. **Session summary table:** Present the standard handoff table with linked issue titles, status, assignee, and all metadata fields.
4. **Daily project update:** Did any issue statuses change? If yes, post a project update.
5. **Handoff context:** If work continues in another surface (e.g., Code for implementation), ensure the Linear issue contains everything the next session needs: spec link, decisions made, blockers, acceptance criteria.

### What You Lose Without Hooks (Severity Assessment)

| Capability | Hook | Severity | Impact on PM Work |
|-----------|------|----------|-------------------|
| Active spec path loading | `session-start.sh` | Medium | Must manually state which spec/issue is in scope |
| Status normalization reminder | `stop.sh` | Medium | Must manually check Linear statuses at exit |
| Sub-issue creation prompt | `stop.sh` | Medium | Must manually capture out-of-scope discoveries |
| Daily project update trigger | `stop.sh` | Low | Must manually remember project hygiene protocol |
| Session summary format | `stop.sh` | Low | Reinforced by CLAUDE.md — this checklist is backup |
| Write scope guard | `pre-tool-use.sh` | N/A | Not relevant — PM sessions don't write code files |
| Protected branch detection | `post-tool-use.sh` | N/A | Not relevant — PM sessions don't touch git |
| Drift detection | `post-tool-use.sh` | N/A | Not relevant — no uncommitted file tracking needed |

**No PM capabilities are blocked.** Only discipline enforcement degrades. This checklist provides equivalent coverage through skill-based guidance.

## Desktop Chat Project Patterns

### Setting Up Client Contexts (Cognito Playbook)

Each client or domain gets its own Desktop Chat project:

```
Projects/
  ├── Alteri              → Research platform context, Alteri-specific instructions
  ├── SoilWorx            → Cognito client, Patrick's workflows, distributor data
  ├── My Hub              → Academic work, HES + KCL courses, personal research
  └── [New Client]        → Client-specific instructions, domain docs, constraints
```

**Project structure:**
- **Instructions:** Domain-specific behavioral guidance (e.g., "You are operating in the SoilWorx context. The primary user is Patrick. Focus on distributor discovery workflows.")
- **Files:** Pre-loaded domain documents (research papers, briefs, reference materials)
- **Memory:** Accumulated project context across sessions

**Spawning Cowork tasks:** When "Create task" is used from a project, the Cowork session inherits that project's instructions and files. This is how domain context flows from Chat to Cowork without manual re-explanation.

**Handoff to Code:** Cowork produces artefacts (specs, decisions) → writes them to Linear issues → Claude Code reads the Linear issue and implements. The Code session doesn't need Desktop Chat's project context — it gets what it needs from Linear + the repo's CLAUDE.md.
