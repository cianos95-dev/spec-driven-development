---
name: platform-routing
description: Recommends the optimal Claude platform (Code, Cowork, Desktop Chat) for each SDD workflow stage. Provides hook-free exit checklists for non-CLI contexts and Desktop Chat project patterns for client context routing.
triggers:
  - starting a new workflow stage
  - asking where to do something
  - beginning spec drafting, triage, or implementation
  - ending a session in Cowork or Desktop Chat
  - setting up a new client or project context
---

# Platform Routing

Route SDD workflow stages to the platform where they work best. These are **recommendations, not blockers** — everything technically works everywhere, but some platforms have capabilities that make specific stages significantly more effective.

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
| Adversarial review (`/sdd:review`) | Claude Code | Requires subagent Task tool for multi-agent review |
| Implementation / TDD | Claude Code | Hooks enforce guardrails, git access, full MCP stack |
| Research grounding | Claude Code | Zotero, arXiv, Semantic Scholar, OpenAlex are stdio MCPs (CLI-only) |
| Insights pipeline (`/sdd:insights`) | Claude Code | Requires file system for data collection and analysis |

### When to suggest a platform switch

If the user starts a workflow stage on a suboptimal platform, **suggest** (never block):

- "This would work better in Cowork — you'd get interactive artefact generation for this spec draft."
- "Research grounding needs Zotero/arXiv access which is CLI-only. Consider switching to Claude Code."
- "For adversarial review, Claude Code's subagent system enables parallel reviewer agents."

## Context Sharing Across Surfaces

No surface operates in isolation. Context flows through artefacts, not platform-native memory:

| Bridge | Flow | What transfers |
|--------|------|----------------|
| **Linear issues** | Any surface → Any surface | Specs, status, decisions, assignments |
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
