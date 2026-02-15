---
description: |
  Run zero-cost in-session plugin validation. Enumerates all skills, agents, and commands from the plugin manifest, verifies file existence, validates frontmatter, checks trigger phrase quality, flags ambiguous overlaps, and generates synthetic test prompts.
  Use when validating plugin health, checking component coverage, auditing trigger descriptions, or verifying no components are missing or broken.
  Trigger with phrases like "self-test", "validate plugin", "check plugin health", "plugin coverage report", "test plugin components", "audit plugin triggers".
argument-hint: "[--verbose]"
platforms: [cli, cowork]
---

# Plugin Self-Test

Run a comprehensive, zero-cost validation of the SDD plugin within the current Claude Code session. This replaces cc-plugin-eval Stages 2-4 for routine validation.

## Step 1: Load Plugin Manifest

Read `.claude-plugin/marketplace.json` from the plugin root directory.

Extract the component registry from `plugins[0]`:
- **Commands:** `plugins[0].commands[]` — array of relative paths to command `.md` files
- **Skills:** `plugins[0].skills[]` — array of relative paths to skill directories (each must contain `SKILL.md`)
- **Agents:** Listed in `agents/*.md` files in the plugin root (agents are not explicitly listed in marketplace.json — discover them by scanning the `agents/` directory)

Build a component inventory:

```
Components found:
- Commands: N registered in manifest
- Skills: N registered in manifest
- Agents: N discovered in agents/ directory
- Total: N components to validate
```

## Step 2: Structural Validation

For each component, verify that the referenced file exists on disk and contains valid YAML frontmatter.

### 2a: File Existence

| Component Type | Expected File |
|----------------|---------------|
| Command | The `.md` file at the path specified in `commands[]` |
| Skill | `SKILL.md` inside the directory path specified in `skills[]` |
| Agent | The `.md` file in `agents/` directory |

**FAIL** if a file referenced in the manifest does not exist on disk.
**WARN** if a file exists on disk but is not referenced in the manifest (orphaned component).

### 2b: Frontmatter Validation

Parse the YAML frontmatter (between `---` delimiters) of each component file.

**Commands** must have:
- `description` — non-empty string

**Skills** must have:
- `name` — non-empty string
- `description` — non-empty string

**Agents** must have:
- `name` — non-empty string
- `description` — non-empty string

**FAIL** if any required field is missing or empty.
**WARN** if `description` is shorter than 50 characters (likely too terse for reliable triggering).

## Step 3: Trigger Quality Analysis

Analyze each component's `description` field for trigger phrase quality.

### 3a: Trigger Phrase Detection

A trigger phrase is any of:
- An explicit phrase after "Trigger with phrases like" followed by quoted strings
- An action verb in the description that indicates when the component is used (e.g., "Use when...", "Use for...")
- Example blocks (`<example>`) that show sample user messages

For each component, extract:
- **Explicit triggers:** Quoted phrases from "Trigger with phrases like ..."
- **Implicit triggers:** Key action phrases from "Use when ..." clauses
- **Example triggers:** User messages from `<example>` blocks

**FAIL** if a component has zero trigger phrases (explicit, implicit, or example).
**WARN** if a component has only implicit triggers and no explicit ones.

### 3b: Ambiguity Detection

Compare every pair of components for description overlap:

1. Extract the set of trigger keywords from each component (nouns and verbs from trigger phrases, excluding stop words).
2. Compute keyword overlap: `|intersection| / |smaller set|`.
3. **WARN** if overlap > 50% between two components of the same type (two skills, two commands).
4. **INFO** if overlap > 50% between components of different types (a skill and a command) — these may be intentionally complementary.

For each flagged pair, explain which keywords overlap and suggest how to differentiate their descriptions.

## Step 4: Synthetic Test Prompt Generation

For each component, generate a synthetic user message that should trigger that component and only that component.

### Generation Rules

1. **From explicit triggers:** Use the first quoted trigger phrase directly as the test prompt.
2. **From examples:** Use the first `user:` message from `<example>` blocks.
3. **From implicit triggers:** Construct a prompt from the "Use when..." clause by rephrasing it as a user request.
4. **Fallback:** If none of the above are available, construct a minimal prompt: `/sdd:[command-name]` for commands, or a brief description-derived phrase for skills/agents.

### Uniqueness Check

For each generated test prompt, scan all other component descriptions to check if the prompt could plausibly trigger a different component:
- Does the test prompt contain keywords that appear in another component's trigger phrases?
- If yes, flag as **AMBIGUOUS** and list the competing components.

## Step 5: Coverage Report

Output the final report as a structured table:

```
## Plugin Self-Test Report

**Plugin:** [name] v[version]
**Date:** [timestamp]
**Components tested:** N

### Coverage Table

| # | Component | Type | File | Frontmatter | Triggers | Test Prompt | Status |
|---|-----------|------|------|-------------|----------|-------------|--------|
| 1 | [name]    | Skill | OK/MISSING | OK/FAIL | N explicit, N implicit | "[prompt]" | PASS/WARN/FAIL |
| 2 | ...       | ...   | ...  | ...         | ...      | ...         | ...    |

### Ambiguity Warnings

| Component A | Component B | Overlap | Shared Keywords |
|-------------|-------------|---------|-----------------|
| [name]      | [name]      | XX%     | [word1, word2]  |

### Summary

- PASS: N components
- WARN: N components (weak triggers or minor issues)
- FAIL: N components (missing files, broken frontmatter, no triggers)
- Ambiguous pairs: N

### Health Score

Score: XX / 100

Scoring:
- Start at 100
- Each FAIL: -10 points
- Each WARN: -3 points
- Each ambiguous pair: -5 points
- Floor at 0
```

## Step 6: Recommendations

If any FAILs or WARNs were found, output actionable recommendations:

```
### Recommendations

1. **[Component name]** (FAIL: missing file) — Create the file at [expected path] or remove from manifest.
2. **[Component name]** (WARN: no explicit triggers) — Add "Trigger with phrases like ..." to the description.
3. **[Component A] vs [Component B]** (AMBIGUOUS) — Differentiate by adding unique keywords to one or both descriptions.
```

## Verbose Mode

If `--verbose` is passed:
- Show the full extracted trigger phrases for each component (not just counts).
- Show the full frontmatter parse results.
- Show the keyword sets used for ambiguity detection.
- Show all competing components for each test prompt, not just ambiguous ones.

## What If

| Situation | Response |
|-----------|----------|
| **Manifest file not found** | Error: "No .claude-plugin/marketplace.json found. Are you in the plugin root directory?" Suggest the user navigate to the correct directory. |
| **No components registered** | Warn: "Plugin manifest contains no skills, agents, or commands." Report health score 0/100. |
| **Agents directory missing** | Info: "No agents/ directory found. Skipping agent validation." Still validate skills and commands. |
| **Frontmatter parse error** | FAIL the component. Report the parse error message. Suggest checking for malformed YAML (missing quotes, bad indentation). |
| **All components PASS** | Report health score 100/100 with a clean bill of health. Suggest running periodically after adding new components. |
