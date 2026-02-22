---
name: cursor-agent-dispatch
description: |
  Integration patterns and usage protocol for cursor_agent_chat MCP bridge.
  Defines task routing thresholds (when to switch from Claude to Cursor), model
  selection within Cursor, context-passing templates, output verification,
  parallel dispatch patterns, and drift prevention for cross-agent file edits.
  Use when approaching Claude rate limits, routing coding tasks to Cursor agent,
  running parallel execution across Claude + Cursor, or verifying Cursor-applied edits.
  Trigger with phrases like "cursor agent chat", "switch to cursor", "rate limit",
  "cursor dispatch", "cursor model", "parallel cursor", "cursor_agent_chat",
  "route to cursor", "cursor bridge", "MCP bridge dispatch".
---

# Cursor Agent Dispatch

This skill defines how and when to use the `cursor_agent_chat` MCP bridge to route coding tasks from Claude Code to Cursor's agent. The bridge enables multi-AI provider orchestration: Claude handles planning, review, and orchestration while Cursor handles code execution — especially when Claude usage limits are approached or when parallel execution across providers adds value.

## Architecture

```
Claude Code (orchestrator)
  └── cursor_agent_chat (MCP tool)
       └── ~/.claude/mcp-servers/cursor-agent-mcp/server.js
            └── ~/.local/bin/agent (Cursor CLI)
                 └── Cursor Agent (Claude / GPT / Gemini)
                      └── Workspace: $HOME
```

**Key constraints:**
- Workspace is fixed to `$HOME` (not configurable per-call)
- Output is text-only — file edits are applied by Cursor but not surfaced in the MCP response
- No structured return format — output is a free-text completion summary
- No session persistence — each `cursor_agent_chat` call is stateless

## Task Routing Decision Tree

The primary decision: should this task be handled by Claude directly, or routed through `cursor_agent_chat`?

```
Is Claude approaching rate limits (Max 20x)?
|
+-- YES (>80% of session/daily limit)
|   |
|   +-- Is the task well-specified with clear file targets?
|   |   |
|   |   +-- YES --> cursor_agent_chat
|   |   +-- NO  --> Reduce scope, then cursor_agent_chat
|   |
|   +-- Is the task interactive (needs back-and-forth)?
|       |
|       +-- YES --> Stay on Claude (pair mode), reduce output
|       +-- NO  --> cursor_agent_chat
|
+-- NO (Claude capacity available)
    |
    +-- Is this a parallelizable coding task?
    |   |
    |   +-- YES --> cursor_agent_chat (parallel execution)
    |   +-- NO  --> Claude direct (lower overhead)
    |
    +-- Is this a Cursor-native task (IDE refactoring, symbol rename)?
    |   |
    |   +-- YES --> cursor_agent_chat
    |   +-- NO  --> Claude direct
    |
    +-- Does the task benefit from a different model (GPT, Gemini)?
        |
        +-- YES --> cursor_agent_chat with model selection
        +-- NO  --> Claude direct
```

### Rate Limit Waterfall

When Claude Max 20x limits are approached, tasks cascade through providers in this order:

| Priority | Provider | Trigger | Best For |
|----------|----------|---------|----------|
| 1 | Claude Code (direct) | Default — always try first | Planning, review, orchestration, complex reasoning |
| 2 | cursor_agent_chat (Claude model) | Claude at 80%+ usage | Code implementation, file edits, refactoring |
| 3 | cursor_agent_chat (GPT model) | Claude at 90%+ OR Cursor Claude quota exhausted | Code generation, structured output, API integration |
| 4 | cursor_agent_chat (Gemini model) | All other quotas near limit | Large-context tasks, broad codebase analysis |
| 5 | Tembo (background) | All interactive quotas exhausted | Well-specified async tasks that can wait |
| 6 | Codex CLI (OpenRouter) | Budget-conscious batch work | Bulk code generation, linting, formatting |

**Proactive threshold:** Start routing non-critical coding tasks to `cursor_agent_chat` at **80% usage** rather than waiting for hard limits. This preserves Claude capacity for orchestration, review, and complex reasoning that only Claude handles well.

### Task Type Routing Matrix

| Task Type | Route To | Rationale |
|-----------|----------|-----------|
| Spec drafting / PR-FAQ | Claude direct | Needs CCC methodology, skill awareness |
| Adversarial review | Claude direct | Needs persona agents, subagent dispatch |
| Planning / decomposition | Claude direct | Needs full context, multi-step reasoning |
| File creation / editing | cursor_agent_chat | Cursor excels at IDE-level file operations |
| Refactoring (rename, extract) | cursor_agent_chat | Cursor has IDE-native refactoring tools |
| Test writing (from spec) | cursor_agent_chat | Well-specified, file-target-clear |
| Bug fix (with reproduction) | cursor_agent_chat | Clear input/output, bounded scope |
| Config file updates | cursor_agent_chat | Simple, well-defined changes |
| Research / analysis | Claude direct | Needs MCP stack (S2, arXiv, Zotero) |
| Linear issue management | Claude direct | Needs Linear MCP, CCC lifecycle awareness |
| Git operations | Claude direct | cursor_agent_chat has no git context |
| Multi-file architectural change | Claude direct (plan) + cursor_agent_chat (execute) | Split: Claude plans, Cursor implements |

## Model Selection Within Cursor

Cursor Cloud Agents supports multiple models. Select based on task cognitive demand:

| Model | When to Use | Strengths | Limitations |
|-------|-------------|-----------|-------------|
| **Claude** (Cursor's Claude) | Default for most code tasks | Strong reasoning, good at following instructions | Shares quota pressure with Claude Code |
| **GPT** (GPT-5.x) | Alternative when Claude quota is stressed | Strong code generation, structured output | Different instruction-following style |
| **Gemini** | Large-context tasks, broad analysis | 1M+ context window, fast on large inputs | Less precise on small targeted edits |

### Model Selection Decision Tree

```
Is the task primarily code generation or editing?
|
+-- YES
|   |
|   +-- Is Claude quota stressed?
|   |   +-- YES --> GPT (avoids Claude quota entirely)
|   |   +-- NO  --> Claude (best instruction-following)
|   |
|   +-- Does the task involve >100K tokens of context?
|       +-- YES --> Gemini (largest context window)
|       +-- NO  --> Claude or GPT per above
|
+-- NO (analysis, review, planning)
    |
    +-- Keep on Claude Code (don't route to cursor_agent_chat)
```

**Model specification:** When calling `cursor_agent_chat`, include the model preference in the task description (Cursor's agent mode uses the model configured in the Cloud Agents dashboard — the MCP bridge does not accept a model parameter directly). If a specific model is needed, note it in the instructions and rely on the Cursor dashboard configuration.

## Context-Passing Template

The `cursor_agent_chat` MCP tool accepts a text prompt. Structure it for maximum clarity since Cursor has no access to Claude's session context, CCC skills, or Linear state.

### Standard Template

```markdown
## Task
{One-sentence summary of what to do}

## Target Files
- `{path/to/file1}` — {what to change}
- `{path/to/file2}` — {what to change}

## Acceptance Criteria
- [ ] {Specific, testable criterion 1}
- [ ] {Specific, testable criterion 2}

## Constraints
- Do not modify: {protected files or directories}
- Follow existing patterns in: {reference file for style}
- Test command: `{how to verify}`

## Context
{2-5 bullets of essential context that Cursor needs}
- This is part of {project/feature}
- Related files: {list}
- The current state: {brief description}
```

### Minimal Template (for simple tasks)

```markdown
## Task
{What to do}

## Files
- `{path}` — {change}

## Verify
`{test command}`
```

### Context-Passing Rules

1. **Always specify file paths.** Cursor workspace is `$HOME` — without explicit paths, Cursor may edit wrong files or search broadly.
2. **Include acceptance criteria.** Cursor has no access to the Linear issue. Inline the criteria from the spec.
3. **Reference existing patterns.** Instead of explaining coding style, point Cursor to a reference file: "Follow the pattern in `skills/tembo-dispatch/SKILL.md`."
4. **Keep context under 2000 tokens.** cursor_agent_chat works best with focused prompts. Long context dilutes instruction quality.
5. **No CCC jargon.** Cursor doesn't read CCC skills. Say "create a markdown file" not "create a SKILL.md with frontmatter."
6. **Include verification commands.** Cursor should verify its own work before returning.

## Output Verification Protocol

`cursor_agent_chat` returns text output describing what was done, but does not return structured file diffs. Verify edits after every call.

### Verification Steps

After each `cursor_agent_chat` call:

1. **Read modified files.** Use Claude's file read tools to inspect the files that Cursor claims to have modified.
2. **Run verification commands.** Execute the test/lint/build commands specified in the task.
3. **Check git diff.** Run `git diff` to see exactly what changed on disk.
4. **Validate against acceptance criteria.** Compare the actual changes against the criteria passed to Cursor.

### Verification Decision Tree

```
cursor_agent_chat returned successfully
|
+-- Read the target files
|   |
|   +-- Files match expectations?
|   |   +-- YES --> Run verification commands
|   |   +-- NO  --> Re-dispatch with corrected instructions
|   |
|   +-- Files unchanged (no edits applied)?
|       +-- Check if Cursor reported an error in output text
|       +-- Re-dispatch with more explicit file paths
|
+-- Run verification commands
    |
    +-- All pass?
    |   +-- YES --> Task complete, commit
    |   +-- NO  --> Fix via Claude (small) or re-dispatch to Cursor (large)
    |
    +-- Command not found / env issue?
        +-- Cursor's workspace differs from Claude's — run locally
```

### Output Parsing

`cursor_agent_chat` returns free text. Look for these patterns in the output:

| Pattern | Meaning | Action |
|---------|---------|--------|
| "I've updated/modified/created {file}" | Cursor applied edits | Verify the file |
| "I wasn't able to" / "I couldn't find" | Cursor failed | Check file paths, re-dispatch |
| Code blocks in output | Cursor showing proposed changes | Check if actually applied to disk |
| "Error" / "Permission denied" | Infrastructure issue | Check MCP server health |

## Parallel Dispatch Patterns

### Pattern 1: Claude Plans, Cursor Executes

The most common pattern. Claude handles the cognitive work, Cursor handles file manipulation.

```
Claude Code session:
  1. Read spec, plan approach (Claude direct)
  2. Decompose into file-level tasks
  3. For each file task:
     └── cursor_agent_chat(task prompt)
     └── Verify output
     └── Fix issues if needed
  4. Integration test (Claude direct)
  5. Commit and push (Claude direct)
```

**When to use:** Multi-file implementations where each file change is independent. Claude maintains the architectural view while Cursor does the mechanical editing.

### Pattern 2: Parallel Provider Execution

Run Claude and Cursor on independent subtasks simultaneously.

```
Claude Code session:
  1. Identify independent subtasks A, B, C
  2. Dispatch B to cursor_agent_chat (async)
  3. Work on A directly (Claude)
  4. When cursor_agent_chat returns, verify B
  5. Work on C (whichever provider is available)
  6. Reconcile and commit
```

**When to use:** When subtasks have no file overlap and both providers have capacity. The MCP call to `cursor_agent_chat` blocks Claude's execution, so true parallelism requires careful task decomposition.

**Important limitation:** `cursor_agent_chat` is a synchronous MCP call — Claude waits for the response. True parallelism requires dispatching Cursor tasks that are large enough to justify the overhead while Claude continues on non-tool-use reasoning work.

### Pattern 3: Rate-Limit Overflow

When Claude hits limits mid-session, gracefully hand off remaining work.

```
Claude Code session (approaching limit):
  1. Document remaining tasks in structured format
  2. For each remaining task:
     └── cursor_agent_chat(task prompt with full context)
     └── Verify output
  3. Final verification and commit (Claude, minimal tokens)
```

**When to use:** Reactive — when limits are hit unexpectedly. Proactive routing (Pattern 1) is preferred.

## Drift Prevention for Cross-Agent Edits

When Cursor edits files, Claude's in-memory context of those files becomes stale. This is the most dangerous failure mode of cross-agent dispatch.

### Mandatory Re-Read Protocol

After every `cursor_agent_chat` call that modifies files:

1. **Re-read all modified files.** Do not trust Claude's cached version. Use the Read tool on every file Cursor touched.
2. **Update mental model.** Note any differences between what was expected and what Cursor actually produced.
3. **Check for collateral edits.** Cursor may modify files beyond what was requested (e.g., auto-formatting, import reorganization). Inspect the full `git diff`, not just the target files.
4. **Anchor to spec.** Run the drift-prevention anchor protocol if the session has been running for 30+ minutes or if Cursor's changes diverged from expectations.

### Stale Context Indicators

| Signal | Risk | Mitigation |
|--------|------|------------|
| Claude references line numbers after Cursor edit | Line numbers shifted | Re-read file, recalculate positions |
| Claude proposes edit that conflicts with Cursor's changes | Stale file content in context | Re-read file before editing |
| Cursor reformatted or reorganized imports | Unexpected diff noise | Review full diff, accept or revert formatting |
| Cursor added unexpected dependencies | Scope creep | Review, discuss with user if significant |

### Integration with drift-prevention Skill

The existing **drift-prevention** skill's anchoring protocol applies after cross-agent edits with these additions:

- **Trigger:** Every `cursor_agent_chat` call that returns successfully (not just the 30-minute timer)
- **Additional check:** `git diff --stat` to enumerate all files changed by Cursor (may exceed the requested scope)
- **Re-anchor action:** Re-read the spec's acceptance criteria and compare against the actual state of all modified files

## Anti-Patterns

**Dispatching planning tasks to Cursor.** cursor_agent_chat is for code execution, not planning. Cursor doesn't have CCC context, Linear access, or research MCPs. Keep all planning, review, and orchestration on Claude.

**Trusting Cursor's text output without file verification.** The text response describes intent, not verified outcome. Always read the files and run tests after a cursor_agent_chat call.

**Over-specifying in the prompt.** Cursor's agent is capable — give it the "what" and "where," not the exact code to write. If you're writing the exact code in the prompt, just write it directly in Claude.

**Ignoring workspace path.** Cursor's workspace is `$HOME`. All file paths in the prompt must be absolute or relative to `$HOME`. Using repo-relative paths (e.g., `skills/foo/SKILL.md`) works only if Cursor correctly resolves the repo root.

**Chaining cursor_agent_chat calls without verification.** Each call is stateless. If call N depends on the output of call N-1, verify N-1's output before dispatching N.

**Using cursor_agent_chat for git operations.** Cursor's agent may not have the same git configuration, SSH keys, or branch context as Claude. Keep all git operations (commit, push, branch management) on Claude.

## MCP Bridge Health Check

Before first use in a session, verify the bridge is operational:

```bash
# Check MCP server exists
ls ~/.claude/mcp-servers/cursor-agent-mcp/server.js

# Check Cursor CLI agent exists
which agent || ls ~/.local/bin/agent

# Test with a trivial task
cursor_agent_chat("List the files in the current directory")
```

If the bridge fails:
- **ENOENT errors:** Check that `server.js` path and `agent` binary path are correct
- **Timeout:** Cursor agent may be starting up — retry after 30 seconds
- **Permission denied:** Check that `agent` binary is executable
- **Workspace errors:** The workspace is fixed to `$HOME` — verify this resolves correctly

## Cross-Skill References

- **execution-modes** skill — Determines when a task is cursor_agent_chat-appropriate. `exec:quick` and `exec:tdd` are the best candidates. `exec:pair` and `exec:checkpoint` should stay on Claude for human-in-the-loop interaction.
- **drift-prevention** skill — The mandatory re-read protocol after Cursor edits extends the standard anchoring triggers. Every cursor_agent_chat call is a drift-prevention trigger.
- **tembo-dispatch** skill — Alternative background execution path. Tembo is preferred for well-specified async tasks; cursor_agent_chat is preferred for synchronous tasks during an active Claude session.
- **parallel-dispatch** skill — Parallel provider execution (Pattern 2) follows the same coordination protocol as parallel session dispatch, adapted for in-session MCP-based parallelism.
- **platform-routing** skill — cursor_agent_chat adds a new dispatch surface to the platform routing table. Route coding tasks to Cursor when Claude capacity is constrained.
- **context-management** skill — cursor_agent_chat calls consume minimal Claude context (prompt + response text) compared to doing the work directly. This makes it a context-efficient delegation mechanism for large file edits.
