# CIA-418: Cross-Tool Plan Review Workflow Evaluation

**Status:** Complete
**Date:** 2026-02-25
**Branch:** `tembo/cia-418-evaluate-cross-tool-plan-review-workflow-plannotator-browser`

## Objective

Evaluate how plan review, annotation, and feedback loops work across AI coding tools under the **Linear agent-first model** — where tools are consumed as Linear agents rather than direct IDE sessions. Determine how VS Code plan preview serves as the primary desktop review surface and how feedback flows back to agents.

## Background: The Linear Agent-First Shift

The operational model has changed fundamentally:

| Before (Direct IDE) | After (Linear Agent-First) |
|---------------------|---------------------------|
| User launches Cursor/Antigravity/Codex directly | Tools dispatched via Linear issue assignment |
| Plan review happens inside each tool's native UI | Plan review happens at a shared surface (VS Code / Linear) |
| Each tool has its own plan format and review UX | Plans converge through Linear Documents and VS Code plan preview |
| Tool switching = context loss | "Continue in" dropdown preserves session context |
| Cursor subscription = direct IDE use | Cursor subscription = consumed via its use as a Linear agent |

**Implication for plan review:** Since the user isn't sitting inside Cursor or Antigravity, plan review cannot depend on tool-native UIs. It must happen at surfaces the user naturally inhabits: **Linear UI**, **Cowork**, and **VS Code** (via "Continue in").

## The "Continue in" Handoff

The Cowork "Continue in" dropdown provides three handoff targets:

1. **Claude Code on the Web** — continues the Cowork session remotely
2. **VS Code** — opens the session in VS Code with Claude Code extension
3. **Cursor** — opens the session in Cursor (but under agent-first model, Cursor is a Linear agent)

This dropdown is the natural bridge from **planning** (Cowork) to **review** (VS Code plan preview). The workflow:

```
Linear Issue → Agent assigned
  → Agent works in Cowork or Code tab
  → Agent enters plan mode
  → User sees "Continue in" → selects VS Code
  → VS Code plan preview opens with live plan
  → User reviews, comments, approves/rejects
  → Feedback returns to agent session
```

### Current Gaps in "Continue in"

- **No bidirectional sync** — Cowork → VS Code is a one-way transfer, not a live link
- **Session isolation** — Cowork and Claude Code sessions don't share state beyond Linear
- **Context loss on transfer** — conversation history may be summarized/truncated during handoff
- **No "Continue in" from Linear UI** — users can't jump from a Linear issue comment directly to VS Code plan review

---

## Candidate Review Surfaces

### 1. VS Code Plan Preview (Native)

**What it does today (v2.1.47+):**
- Plan preview auto-updates as Claude iterates
- Commenting enabled only when plan is ready for review
- Preview stays open on rejection so Claude can revise
- Plan mode survives compaction (plans don't randomly switch to implementation)
- Session names persist across resume and compaction
- `Shift+Tab` cycles through modes (Edit → Auto-Accept → Plan)
- `Ctrl+G` opens the plan file in the text editor for direct editing

**Strengths for agent-first model:**
- Zero integration cost — built into Claude Code VS Code extension
- Native keyboard shortcuts and VS Code UX conventions
- Plan file is a real file (`~/.claude/plans/<session-slug>.md`) that can be edited directly
- Auto-updates provide live feedback as agent revises

**Limitations:**
- **Claude Code only** — plans from Cursor-as-agent or Codex-as-agent aren't visible here
- **Approve/reject only** — no rich inline annotation (can't mark specific sections for deletion, insertion, or replacement)
- **Session-scoped** — plan preview disappears when session ends
- **No structured feedback format** — rejection triggers Claude to revise, but the user can't specify *what* to change beyond free-text

**Verdict:** Good for approve/reject on Claude Code plans. Insufficient for structured annotation across multiple tools.

### 2. Plannotator (Browser-Based)

**What it does:**
- Browser UI for visual plan annotation (delete, insert, replace, comment operations)
- Triggers via hook on `ExitPlanMode`
- Plans compressed into URL for sharing (no accounts, no database, no server)
- Local-first — plans never leave the user's machine
- Approved plans auto-save to a vault with frontmatter and tags
- Code review mode (`/plannotator-review`) for git diff annotation
- Works with Claude Code and OpenCode

**Strengths for agent-first model:**
- **Rich annotation vocabulary** — delete, insert, replace, comment are structured operations that agents can parse
- **Shareable URLs** — plan review state can be shared without infrastructure
- **Tool-agnostic output** — annotations are structured data, not tool-specific
- **Vault feature** — approved plans accumulate as a searchable archive (analogous to CCC's plan-promotion Tier 2)

**Limitations:**
- **Hook dependency** — triggers on `ExitPlanMode`, which only fires in Claude Code (not from Linear agent sessions)
- **Browser context switch** — opens a new browser tab, breaking the VS Code flow
- **No Linear integration** — annotations don't flow back to Linear issues automatically
- **Single-tool feedback** — annotations return to the originating Claude Code session only
- **External dependency** — adding a third-party tool to the critical path of plan review

**Verdict:** Valuable annotation vocabulary and patterns. Integration into agent-first flow requires adaptation — the hook trigger point and feedback channel need rethinking.

### 3. Linear Document Review

**What it does:**
- Plan-promotion skill (`/ccc:plan --promote`) creates a Linear Document from the session plan
- Linear Documents accessible from all surfaces (Code tab, Cowork, Linear UI)
- Comments on Linear Documents serve as feedback
- Any agent with Linear MCP access can read documents and comments

**Strengths for agent-first model:**
- **Universal accessibility** — every agent (Claude, Tembo, Cursor-via-Linear, Codex, cto.new) can read Linear Documents via MCP
- **Zero integration cost** — plan-promotion skill already exists (PR #58)
- **Persistent** — survives session termination, tool switching, compaction
- **Native commenting** — Linear's comment system provides threading, mentions, reactions
- **Cross-tool by default** — Linear is already the universal state bus

**Limitations:**
- **No inline annotation** — Linear Document comments are at the document level, not section/line level
- **Async feedback loop** — comments on a document don't trigger the agent automatically; the agent must poll or be re-dispatched
- **Promotion overhead** — requires explicit promotion step (not automatic)
- **No approve/reject semantics** — comments lack the structured approve/reject/revise vocabulary

**Verdict:** Best cross-tool accessibility. Weakest annotation granularity. Ideal as the persistence layer, not the review surface.

### 4. Browser-Based Custom Reviewer (Build from Scratch)

**What it would do:**
- Custom web UI for plan review with CCC-specific annotation vocabulary
- Could integrate with Linear API for bidirectional feedback
- Could support all plan formats (Claude Code, Codex, Cursor)

**Strengths:**
- Full control over UX and annotation semantics
- Could be purpose-built for the CCC workflow

**Limitations:**
- **High build cost** for a single-developer workflow
- CIA-567 finding: "CCC should NOT build custom review surfaces"
- Would duplicate functionality already available in VS Code plan preview and plannotator

**Verdict:** Rejected. CIA-567's GO recommendation explicitly advises against building custom review surfaces.

---

## Recommended Architecture

### Three-Layer Plan Review Stack

```
Layer 3: ANNOTATION          Plannotator patterns (structured feedback vocabulary)
         ↓ feedback           ↑ plan content
Layer 2: REVIEW SURFACE      VS Code plan preview (primary) / Linear UI (fallback)
         ↓ promote            ↑ read
Layer 1: PERSISTENCE         Linear Documents (via plan-promotion skill)
```

### Layer 1: Linear Documents (Persistence)

**Already implemented** via plan-promotion skill (PR #58).

- Every plan that needs review gets promoted to a Linear Document
- Agents from any tool can read the plan via `get_document()`
- Issue comments capture review decisions and feedback
- Serves as the cross-tool source of truth

### Layer 2: VS Code Plan Preview (Primary Review Surface)

**Use as-is** for Claude Code sessions:

- When a Linear agent (Claude/Tembo) creates a plan, it enters plan mode
- If the user is in VS Code (via "Continue in" or direct), they see the plan preview
- User approves or rejects with comments
- Agent receives feedback inline and revises

**For non-Claude agents** (Codex, cto.new, Cyrus):

- Agent posts plan to Linear issue comment or creates Linear Document
- User reviews in Linear UI or Cowork
- User posts feedback as Linear comment
- Agent reads feedback on next session

### Layer 3: Plannotator Annotation Patterns (Structured Feedback)

**Extract, don't depend.** Plannotator's annotation vocabulary is the valuable abstraction:

| Operation | Meaning | Agent-Parseable Format |
|-----------|---------|----------------------|
| `DELETE` | Remove this section | `[DELETE] Section: <heading>` |
| `INSERT` | Add content after this point | `[INSERT after: <heading>] <content>` |
| `REPLACE` | Swap this content | `[REPLACE] Section: <heading> → <new content>` |
| `COMMENT` | Note without structural change | `[COMMENT on: <heading>] <feedback>` |

These operations can be:
1. Typed as structured comments on Linear issues (cross-tool)
2. Used in VS Code plan preview rejection feedback (Claude Code)
3. Parsed by any agent that reads Linear issue comments

**Implementation in CCC:** Add an annotation vocabulary reference to the `plan-promotion` skill. When a user provides plan feedback (via Linear comment or VS Code rejection), the agent parses structured annotations and applies them to the plan revision.

---

## Workflow Diagrams

### Workflow A: Claude/Tembo Agent (Primary — VS Code Review)

```
1. Linear issue created/assigned to agent
2. Agent enters plan mode (Code tab or Cowork)
3. Agent creates plan in ~/.claude/plans/
4. Plan promoted to Linear Document (plan-promotion skill)
5. User opens VS Code (via "Continue in" or directly)
6. VS Code plan preview shows live plan
7. User reviews:
   a. APPROVE → agent proceeds to implementation
   b. REJECT + feedback → agent revises plan (preview stays open)
   c. REJECT + structured annotation → agent parses and applies changes
8. Repeat 6-7 until approved
9. Agent implements plan
```

### Workflow B: External Agent (Codex/cto.new/Cyrus — Linear Review)

```
1. Linear issue assigned to external agent
2. Agent creates plan (tool-specific format)
3. Agent posts plan to Linear issue comment
4. User reviews plan in Linear UI or Cowork
5. User posts feedback as Linear comment (using annotation vocabulary)
6. Agent reads feedback on next poll/dispatch
7. Agent revises plan and re-posts
8. Repeat 4-7 until approved
9. Agent implements plan
```

### Workflow C: Cowork → VS Code Handoff (Planning → Review)

```
1. User starts planning session in Cowork
2. Claude creates plan collaboratively with user
3. User clicks "Continue in → VS Code"
4. Session transfers to VS Code with plan context
5. VS Code plan preview renders the plan
6. User reviews with full IDE context (file tree, terminal, etc.)
7. User approves/rejects with structured feedback
8. Claude revises in VS Code (full tool access)
```

---

## Gap Analysis

### What Works Today

| Capability | Status | Surface |
|-----------|--------|---------|
| Plan creation in Claude Code | Works | Code tab |
| Plan promotion to Linear Document | Works (PR #58) | All surfaces via MCP |
| VS Code plan preview with approve/reject | Works (v2.1.47) | VS Code |
| Linear Document reading by agents | Works | All agents with MCP |
| "Continue in" from Cowork to VS Code | Works | Cowork → VS Code |

### What's Missing

| Gap | Impact | Mitigation |
|-----|--------|------------|
| No structured annotation vocabulary in VS Code plan preview | Users can only approve/reject with free-text, not structured operations | Extract plannotator patterns into CCC annotation vocabulary (Layer 3) |
| No auto-promotion on plan completion | Plans must be manually promoted via `/ccc:plan --promote` | Hook in `plan-subagent-stop.sh` already suggests promotion; could auto-promote for 3+ point issues |
| No "Continue in" from Linear UI to VS Code | Users viewing plans in Linear can't jump to VS Code review | Share VS Code deep link in the promoted document |
| Async feedback loop for external agents | External agents don't get real-time feedback | Acceptable — external agents are inherently async |
| No plan format normalization across tools | Each tool's plan format is different | Use Linear Document as canonical format; plan-promotion normalizes on promotion |
| Session context loss on "Continue in" transfer | Some conversation context may be lost during handoff | Promote plan to Linear Document before handoff; document is the canonical context |

---

## Recommendations

### GO: Adopt Three-Layer Stack

1. **Layer 1 (Persistence):** Continue using Linear Documents via plan-promotion skill. No changes needed.

2. **Layer 2 (Review Surface):** VS Code plan preview for Claude Code sessions. Linear UI/Cowork for external agent plans. No new surfaces to build.

3. **Layer 3 (Annotation):** Define a CCC annotation vocabulary (DELETE/INSERT/REPLACE/COMMENT) in the plan-promotion skill. This is the only new work needed.

### GO: Auto-Promotion for Significant Plans

Add auto-promotion logic to `plan-subagent-stop.sh`:
- If the issue is 3+ points, auto-promote the plan to Linear Document on plan completion
- If the issue has the `exec:tdd` label, auto-promote (plan is likely to need review)
- If the plan spans multiple sessions (detected via session naming), auto-promote

### NO-GO: Building Custom Review Surfaces

CIA-567's finding stands: CCC should not build custom review surfaces. VS Code plan preview + Linear Documents cover the requirements. Plannotator is a valuable reference implementation but should not be added as a dependency.

### NO-GO: Plannotator as Runtime Dependency

Plannotator's architecture (browser-based, hook-triggered, URL-encoded) doesn't align with the agent-first model where plans flow through Linear. Extract the annotation vocabulary; don't depend on the tool.

### DEFER: "Continue in" Deep Links

Adding VS Code deep links to promoted Linear Documents would improve the handoff from Linear UI to VS Code review. This is a nice-to-have that depends on Claude Code's deep link support, which is still evolving.

---

## Integration Points with Existing CCC Skills

| Skill | Integration |
|-------|------------|
| `plan-promotion` | Add annotation vocabulary section; add auto-promotion criteria |
| `platform-routing` | Update to recommend VS Code for plan review (not just implementation) |
| `adversarial-review` | Review findings on plans can use the annotation vocabulary for structured feedback |
| `session-exit` | Strengthen promotion suggestion; add auto-promotion trigger |
| `mechanism-router` | Plan review intent routing for @mention-triggered reviews |

## Key Finding: The Feedback Loop

The critical insight from this evaluation: **the feedback loop is already mostly built.** The pieces exist:

1. **Plan creation** → plan mode in Claude Code/Cowork
2. **Plan persistence** → plan-promotion to Linear Documents
3. **Plan review** → VS Code plan preview (Claude) or Linear comments (external agents)
4. **Feedback delivery** → approve/reject in VS Code; comments in Linear
5. **Feedback consumption** → agent reads rejection feedback (VS Code) or issue comments (Linear)

The missing piece is **structured feedback vocabulary** — a way for users to express "delete this section", "insert a step here", "replace this approach" in a format that agents can parse reliably. That's the annotation vocabulary from Layer 3.

## Appendix: Plannotator Technical Details

**Repository:** [backnotprop/plannotator](https://github.com/backnotprop/plannotator)
**License:** MIT / Apache-2.0 (dual-licensed)
**Compatibility:** Claude Code, OpenCode
**Stars:** 2.2K+

**Architecture:**
- Browser-based UI (React/Next.js)
- Hook integration: triggers on `ExitPlanMode` event
- Plans encoded in URL fragment (no server, no database)
- Annotation types: delete, insert, replace, comment
- Feedback returned to originating session as structured text
- Vault: approved plans saved with frontmatter and auto-extracted tags
- Code review mode: annotate git diffs with same UX

**CCC-Relevant Patterns:**
1. **Structured annotation vocabulary** — DELETE/INSERT/REPLACE/COMMENT operations with section references
2. **Plan vault concept** — searchable archive of approved plans (analogous to Tier 2 Linear Documents)
3. **URL-encoded sharing** — stateless plan sharing (CCC equivalent: Linear Document URL)
4. **Auto-close on approval** — approval triggers next phase automatically (CCC equivalent: plan-promotion → implementation)
