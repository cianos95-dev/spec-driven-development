# CIA-641: Cross-Tool Persona Injection Surfaces

**Status:** Complete
**Date:** 2026-02-24
**Branch:** `tembo/cia-641-persona-injection-spike`

## Objective

Investigate how CCC reviewer persona definitions (Security Skeptic, Architectural Purist, Performance Pragmatist, UX Advocate) can be injected into 5 AI development tools beyond Claude Code.

## CCC Persona Format (Baseline)

CCC personas are Markdown files with YAML frontmatter (`agents/*.md`). Each contains:

- **YAML frontmatter:** `name`, `description` (with 3 annotated examples), `model: inherit`, `color`
- **System prompt body:** Role statement ("You are the **Security Skeptic**..."), perspective, 7-item review checklist, output format template, quality score dimensions, behavioral rules

The system prompt body is the portable unit — it's plain Markdown prose that can be extracted and injected into any tool that accepts free-form instructions.

---

## Comparison Table

| Tool | Instruction File | Location | Format | Persona Injection Works? | Injection Method | Key Limitations |
|------|-----------------|----------|--------|--------------------------|------------------|-----------------|
| **Cursor** | `.cursor/rules/*.mdc` | `.cursor/rules/` dir (project) | YAML frontmatter + Markdown | **Yes** | One `.mdc` file per persona with `alwaysApply: true` or glob-scoped activation | 20K char/file limit; all rules share token budget; no mutual exclusion between personas; legacy `.cursorrules` also works but is deprecated |
| **Codex CLI** | `AGENTS.md` | Repo root + subdirs + `~/.codex/AGENTS.md` | Plain Markdown | **Yes** | Embed persona prompt in `AGENTS.md` prose; one persona per file in subdirs | 32 KiB total cap (configurable); injected as user-role messages not system; no native role/persona abstraction; single-agent only |
| **Gemini CLI** | `GEMINI.md` | Repo root + ancestors + subdirs + `~/.gemini/GEMINI.md` | Plain Markdown | **Yes** | `"You are..."` pattern in `GEMINI.md`; full system prompt replacement via `GEMINI_SYSTEM_MD` env var | All files concatenated (no override semantics); token-limit bugs reported; `GEMINI_SYSTEM_MD` is all-or-nothing replacement; no append mode for system prompt |
| **OpenCode** | `AGENTS.md` + `.opencode/agents/*.md` | Repo root (falls back to `CLAUDE.md`) + `.opencode/agents/` | Plain Markdown (instructions); YAML frontmatter + Markdown (agents) | **Yes** | Dedicated agent definition files with frontmatter (`description`, `model`, `temperature`, `tools`, `permissions`) + Markdown body as system prompt | Falls back to `CLAUDE.md` if no `AGENTS.md`; first-match-wins per directory (no layering); no documented file size limit but bounded by context window |
| **Antigravity** | `.agent/rules/*.mdc` + `.agent/skills/*/SKILL.md` | `.agent/` dir (project) + `~/.gemini/GEMINI.md` (global) | Markdown/MDC (rules); YAML frontmatter + Markdown (skills) | **Yes** | Rules for always-on persona context; Specialist Agent skills for on-demand persona activation via semantic matching | SKILL.md < 500 lines recommended; name field ≤ 64 chars; rules should be 1-2 pages max; vulnerable to indirect prompt injection via untrusted content |

---

## Detailed Findings Per Tool

### 1. Cursor (`.cursor/rules/*.mdc`)

**Instruction surface:** `.cursor/rules/` directory with `.mdc` files (YAML frontmatter + Markdown). Legacy `.cursorrules` at project root still works but is deprecated. Also reads `AGENTS.md`.

**Persona injection approach:**
```yaml
---
description: "Security-first adversarial spec reviewer"
globs:
  - "**/*.md"
alwaysApply: false
---

You are the **Security Skeptic**...
[rest of persona system prompt]
```

**Four activation modes:**
- `alwaysApply: true` — injected into every interaction
- `globs` defined — attached when referenced files match patterns
- `description` only — agent decides when to apply based on semantic matching
- No metadata — manual invocation via `@ruleName`

**Limitations:**
- 20,000 character limit per `.mdc` file (CCC personas are ~3-5K chars, so this is fine)
- No mutual exclusion — if multiple persona rules match, they all merge
- Token tax: every active rule consumes context window budget
- No native concept of "agents" or "personas" — just instruction text

**Verdict:** Works well. Glob-scoped activation gives contextual persona switching.

---

### 2. Codex CLI (`AGENTS.md`)

**Instruction surface:** `AGENTS.md` at repo root, subdirectories, and `~/.codex/AGENTS.md` (global). Override via `AGENTS.override.md`.

**Persona injection approach:**
```markdown
## Agent Persona: Security Skeptic

You are the **Security Skeptic**...
[rest of persona system prompt]
```

**Limitations:**
- 32 KiB total cap across all `AGENTS.md` files (configurable via `project_doc_max_bytes`)
- Injected as **user-role messages**, not system messages — model may weight them differently
- No native multi-agent/persona abstraction — single flat instruction file
- Only one file per directory level (first match wins)
- Cannot dynamically switch personas — all instructions are always active

**Adaptation needed:** For multi-persona support, would need subdirectory-based `AGENTS.md` files or a single file containing all personas with clear section headers. The 32 KiB cap means 4 full personas (~4K chars each = ~16K) fits comfortably.

**Verdict:** Works, but less elegant than tools with native persona support. Best suited for a single combined instruction set rather than switchable personas.

---

### 3. Gemini CLI (`GEMINI.md`)

**Instruction surface:** `GEMINI.md` at multiple hierarchy levels. `GEMINI_SYSTEM_MD` env var for full system prompt replacement. Supports `@file.md` modular imports.

**Persona injection approach:**
```markdown
# Security Skeptic Persona

You are the **Security Skeptic**...
[rest of persona system prompt]

@./personas/architectural-purist.md
@./personas/performance-pragmatist.md
```

Or via full system prompt override:
```bash
GEMINI_SYSTEM_MD=./personas/security-skeptic-system.md gemini
```

**Unique advantages:**
- `@file.md` import syntax allows modular persona composition
- `GEMINI_SYSTEM_MD` enables full system prompt replacement for deep persona control
- Template variables (`${AgentSkills}`, `${AvailableTools}`) in custom system prompts
- Configurable filename via `settings.json` (can add `AGENTS.md` to scan list)

**Limitations:**
- No override semantics — all files concatenated, conflicts resolved by model
- `GEMINI_SYSTEM_MD` is all-or-nothing (no append mode)
- Token-limit bugs reported with even small instruction files
- No per-persona activation scoping (everything is always-on unless using separate CLI invocations)

**Verdict:** Works well. The import system and system prompt override give the most flexibility for persona composition. Can run separate `gemini` instances with different `GEMINI_SYSTEM_MD` values for true persona switching.

---

### 4. OpenCode (`AGENTS.md` + `.opencode/agents/*.md`)

**Instruction surface:** `AGENTS.md` at repo root (falls back to `CLAUDE.md` if absent). Dedicated agent definitions in `.opencode/agents/*.md` with YAML frontmatter.

**Persona injection approach (agent definition):**
```yaml
---
description: Security-first adversarial spec reviewer
mode: primary
model: anthropic/claude-sonnet-4-20250514
temperature: 0
tools:
  read: true
  glob: true
  grep: true
  write: false
  edit: false
  bash: false
---

You are the **Security Skeptic**...
[rest of persona system prompt]
```

**Unique advantages:**
- **Richest persona support of all 5 tools** — dedicated agent definition format
- Per-agent model selection, temperature, tool permissions
- `mode: primary` vs `mode: subagent` for agent orchestration
- Falls back to reading `CLAUDE.md` — existing CCC setup works out-of-box
- `/init` command auto-generates `AGENTS.md` from codebase analysis

**Limitations:**
- First-match-wins: can't layer `AGENTS.md` + `CLAUDE.md` in same directory
- No documented file size limit (bounded by context window)
- Relatively new tool — smaller ecosystem than Cursor or Codex

**Verdict:** Best native fit for CCC personas. The `.opencode/agents/*.md` format is nearly 1:1 with CCC's `agents/*.md` format — same YAML frontmatter + Markdown body pattern.

---

### 5. Antigravity (`.agent/rules/*.mdc` + `.agent/skills/*/SKILL.md`)

**Instruction surface:** `.agent/rules/` for always-on context, `.agent/skills/*/SKILL.md` for on-demand specialist agents, `~/.gemini/GEMINI.md` for global rules.

**Persona injection approach (Specialist Agent skill):**
```
.agent/skills/security-skeptic/
├── SKILL.md
├── references/
│   └── owasp-top-10.md
└── assets/
    └── review-template.md
```

```yaml
---
name: security-skeptic
description: >
  Security-first adversarial spec reviewer. Assumes every spec has
  an exploitable weakness. Probes for attack vectors, data exposure,
  auth boundary gaps, and compliance blind spots.
license: MIT
compatibility:
  antigravity: ">=1.0"
---

You are the **Security Skeptic**...
[rest of persona system prompt]
```

**Unique advantages:**
- **Semantic auto-activation** — personas trigger when user's request matches skill description
- Skills can include reference docs and templates alongside the persona prompt
- Rules vs Skills separation (always-on context vs on-demand personas)
- Layered priority: system → global → workspace → skills

**Limitations:**
- SKILL.md should be < 500 lines; persona name ≤ 64 chars
- Vulnerable to indirect prompt injection (documented security concern)
- Rules limited to 1-2 pages recommended
- More installed skills = more token usage and risk of irrelevant activation

**Verdict:** Works well. The Specialist Agent pattern is a natural fit for CCC personas. Semantic auto-activation is a unique advantage over other tools.

---

## Portability Assessment

### What's Portable (Zero Adaptation)

The **system prompt body** of each CCC persona (everything after the YAML frontmatter) is plain Markdown prose. It can be copy-pasted into any of the 5 tools with no modification. This includes:
- Role statement and worldview
- Review checklist (7 items per persona)
- Output format template
- Quality score dimensions
- Behavioral rules

### What Needs Adaptation Per Tool

| Component | Cursor | Codex CLI | Gemini CLI | OpenCode | Antigravity |
|-----------|--------|-----------|------------|----------|-------------|
| YAML frontmatter | Rewrite to `.mdc` format (`description`, `globs`, `alwaysApply`) | Strip entirely (plain Markdown) | Strip entirely (plain Markdown) | Rewrite to OpenCode format (`description`, `mode`, `model`, `tools`) | Rewrite to SKILL.md format (`name`, `description`, `license`) |
| Examples in description | Move to rule body or drop | Move to file body | Move to file body | Move to agent body | Move to `references/` dir |
| Multi-persona switching | Separate `.mdc` files with globs | Single file with sections or subdirs | Separate `GEMINI_SYSTEM_MD` invocations or `@import` | Separate `.opencode/agents/*.md` files | Separate `.agent/skills/*/SKILL.md` dirs |
| Quality score output | Works (plain text) | Works (plain text) | Works (plain text) | Works (plain text) | Works (plain text) |

### Recommended Export Strategy

A generator script could produce tool-specific persona files from the canonical CCC `agents/*.md` definitions:

1. **Parse** YAML frontmatter + Markdown body from `agents/reviewer-*.md`
2. **Extract** the system prompt body (post-frontmatter Markdown)
3. **Emit** per-tool variants:
   - `cursor/` → `.mdc` files with Cursor-specific frontmatter
   - `codex/` → `AGENTS.md` with persona sections
   - `gemini/` → `GEMINI.md` with `@import` structure
   - `opencode/` → `.opencode/agents/*.md` with OpenCode frontmatter
   - `antigravity/` → `.agent/skills/*/SKILL.md` with Antigravity frontmatter

---

## Key Findings

1. **All 5 tools accept persona injection via Markdown prose.** The CCC persona system prompt body is universally portable.

2. **OpenCode has the closest native format** to CCC — YAML frontmatter + Markdown body agent definitions, nearly identical structure.

3. **Antigravity has the most sophisticated activation** — semantic auto-matching means personas activate when contextually relevant, without explicit invocation.

4. **Cursor offers the best scoping** — glob-based activation means personas can be tied to specific file types or directories.

5. **Codex CLI is the simplest but least flexible** — flat Markdown with no native persona abstraction, but the emerging `AGENTS.md` standard provides cross-tool portability.

6. **Gemini CLI offers the deepest customization** — full system prompt replacement via `GEMINI_SYSTEM_MD` and modular imports via `@file.md`.

7. **Token budget is the universal constraint.** Every tool shares persona instructions with the model's context window. CCC personas at ~3-5K chars each are well within all tools' limits.

8. **No tool tested refused persona instructions.** All 5 tools process "You are the [Persona]..." instructions as expected based on documentation and community reports.
