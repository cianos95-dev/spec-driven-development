---
name: tembo-dispatch
description: |
  Dispatch a well-specified CCC issue to Tembo for background agent execution.
  Handles dispatch surface selection (MCP vs Linear delegation), prompt construction
  with the Dispatch Prompt Template v1 completion sequence, credit estimation, and
  post-dispatch monitoring. Use when an issue is well-specified (exec:quick or exec:tdd),
  the task doesn't require interactive pairing, and you want async background execution.
  Trigger with phrases like "dispatch to tembo", "tembo this", "send to tembo",
  "background implement", "delegate to tembo", "async dispatch", "tembo dispatch",
  "run this in background", "tembo execute".
---

# Tembo Dispatch

Tembo dispatch is the CCC pattern for sending well-specified implementation tasks to Tembo for background agent execution. Tembo spins up an isolated VM sandbox, runs a coding agent (Claude Code by default), and produces a PR automatically. The key value is async execution — you dispatch and move on to the next task without waiting.

## When to Dispatch to Tembo

Tembo dispatch is appropriate when ALL of these are true:

1. **Well-specified.** The issue has clear acceptance criteria. exec:quick or exec:tdd. If the spec is vague, Tembo will either guess wrong or stall.
2. **No interactive pairing needed.** exec:pair and exec:checkpoint require human checkpoints. Tembo runs unattended.
3. **Repo is Tembo-ready.** The target repo has a `tembo.md` config file and is authorized in Tembo's GitHub integration.
4. **Credit budget allows it.** Check credit balance before dispatching (see Credit Estimation below).

**Do NOT dispatch to Tembo when:**
- The task requires interactive decision-making (exec:pair, exec:checkpoint)
- The spec is draft or needs grounding (spec:draft, research:needs-grounding)
- The task is a spike (type:spike) — spikes produce knowledge, not PRs
- The repo has no `tembo.md` (Tembo won't know the repo conventions)
- You need the result immediately (Tembo is async; latency is 5-30 minutes)

## Dispatch Surfaces

### Surface 1: MCP Dispatch (from Claude Code)

Use `mcp__tembo__create_task` with a structured prompt. This is the preferred surface when you're already in a Claude Code session and want to dispatch programmatically.

```
mcp__tembo__create_task({
  title: "feat: {summary} (CIA-XXX)",
  description: "{dispatch prompt — see template below}",
  repository: "{owner/repo}"
})
```

**Advantages:** Programmatic, can construct the prompt dynamically from Linear issue data, returns a task ID for monitoring.

### Surface 2: Linear Delegation

Assign the issue to "Tembo" in Linear's assignee field (or delegate via the UI). Tembo picks up delegated issues automatically, reads the issue description as the spec, and creates a PR.

**Advantages:** No Claude Code session needed, works from mobile/web, leverages Linear's native delegation UX.

**Disadvantages:** Less control over the prompt — Tembo reads the raw issue description. Ensure the description includes acceptance criteria and the completion sequence.

### Which Surface to Use

| Scenario | Surface | Reason |
|----------|---------|--------|
| Already in Claude Code session | MCP dispatch | Can inject structured prompt with template |
| Triaging from Linear UI | Linear delegation | No session needed |
| Dispatching from Cowork | Linear delegation | Cowork has no MCP access |
| Need custom prompt beyond issue description | MCP dispatch | Full prompt control |
| Batch dispatching multiple issues | Either | MCP for parallel, Linear for sequential |

## Dispatch Prompt Template v1

Every Tembo dispatch must include the completion sequence. Omitting steps 5-6 breaks the zero-touch loop (this was the root cause of CIA-492, CIA-326, and CIA-447).

```markdown
## Context
{Brief description of what needs to be done}
Linear issue: {CIA-XXX}
Branch: `tembo/{CIA-XXX}-{slug}`

## Acceptance Criteria
- [ ] {AC 1}
- [ ] {AC 2}
- [ ] {AC N}

## Constraints
- Verification command: `{pnpm typecheck && pnpm lint && pnpm test}`
- Do not modify: {protected paths, if any}

## Completion Sequence (REQUIRED -- do not omit any step)
After all acceptance criteria pass verification:
1. Run: `{verification command}` -- all must pass
2. Stage changes: `git add {specific files}`
3. Commit: `git commit -m "feat: {summary}\n\nCloses {CIA-XXX}\n\nCo-Authored-By: Claude Code <claude-code[bot]@users.noreply.github.com>"`
4. Push: `git push -u origin tembo/{CIA-XXX}-{slug}`
5. Create PR: `gh pr create --title "{title}" --body "Closes {CIA-XXX}\n\n## Summary\n{bullets}"`
6. Enable auto-merge: `gh pr merge --auto --squash`

## References
- Repo: {github-url}
- Spec: {linear-issue-url}
```

**Critical notes on the template:**
- Step 3: Must use `Closes` (not "Implements", "Fixes", or "References") for GitHub-Linear auto-close.
- Step 6: Must run AFTER step 5 (needs the PR number). This is the step that was missing in prior failures.
- Tembo natively handles steps 4-5 in most cases, but step 6 (auto-merge) must be explicitly instructed.
- The `tembo.md` file in each repo provides additional repo-specific context that Tembo reads automatically.

## Credit Estimation

Tembo Pro plan: 100 credits/month. Credits cover both infrastructure (VM time) and LLM API costs.

| Task Complexity | Estimated Credits | Examples |
|----------------|:-----------------:|---------|
| Trivial (1pt, config change) | ~1 | Update a config file, fix a typo |
| Small fix (1-2pt) | 1-3 | Bug fix, add a single function |
| Feature (3-5pt) | 3-8 | New component, API endpoint |
| Complex (8pt+) | 8-15+ | Multi-file refactor, new subsystem |

**Budget discipline:** At 100 credits/month, you can dispatch ~15-25 small-to-medium tasks or ~8-12 features. Don't dispatch 13pt tasks to Tembo — decompose them first, then dispatch the sub-tasks.

**Check balance:** Use `mcp__tembo__list_tasks` to see recent task history and estimate burn rate.

## Post-Dispatch Monitoring

After dispatching, monitor via:

1. **Linear:** Tembo updates the issue status (Backlog → In Progress) and posts a comment when the PR is ready.
2. **MCP:** `mcp__tembo__search_tasks` with the issue ID to check task status.
3. **GitHub:** Watch for the PR on the `tembo/*` branch.

**If Tembo stalls or fails:**
- Check Tembo service status (500 errors = Tembo infrastructure issue, not your fault)
- Verify the repo is authorized in Tembo's GitHub integration
- Check credit balance — zero credits = tasks silently fail
- Fallback: implement directly in a Claude Code session using the same dispatch prompt template

## Integration with CCC Pipeline

Tembo dispatch fits into the CCC pipeline as one of five entry points into the canonical zero-touch loop:

```
Entry Points:
  Claude Code (manual) ──┐
  GH Actions (label) ────┤
  Tembo (MCP/Linear) ────┤──→ Implement → Verify → Commit → Push → PR → Auto-merge → Linear Close
  Cowork (spec/review) ──┤
  @mention (review) ──────┘
```

After Tembo creates a PR with `Closes CIA-XXX` and `gh pr merge --auto --squash`:
1. CI runs → passes
2. PR auto-merges (squash)
3. Branch auto-deletes
4. GitHub-Linear sync fires `Closes CIA-XXX` → issue transitions to Done

No human intervention required for well-specified tasks.

## Multi-Project Routing

When dispatching from a Linear issue, the issue's **project** field determines which repository to target. All projects belong to the **Claudian** team.

| Linear Project | Repository | Working Directory | Notes |
|----------------|------------|-------------------|-------|
| Claude Command Centre (CCC) | `claude-command-centre` | `/` (repo root) | Markdown/config only — no build chain |
| Alteri | `alteri` | `/` (repo root) | Next.js + R — run `pnpm install` post-clone |
| Ideas & Prototypes | `prototypes` | `/` (repo root) | Turborepo monorepo — app selection via task prompt |
| Cognito SoilWorx | `prototypes` | `apps/soilworx` | Monorepo sub-app — scope work to this directory |
| Cognito Playbook | `prototypes` | `apps/job-search` | Monorepo sub-app — scope work to this directory |

**Routing rules:**
1. Read the issue's project field from Linear before dispatching.
2. Map project → repository using the table above.
3. For monorepo sub-apps (Cognito SoilWorx, Cognito Playbook): include the working directory in the task prompt so Tembo scopes changes to the correct app.
4. Unrecognized projects: do not dispatch. Flag for human review.
5. Cross-project issues: rare. If an issue spans multiple repos, create separate Tembo tasks per repo.

**For MCP dispatch**, use the repository URL from the table below in the `repositories` parameter:

```
mcp__tembo__create_task({
  prompt: "...",
  repositories: ["https://github.com/cianos95-dev/{repo-name}"]
})
```

## Tembo-Ready Repos

| Repo | `tembo.md` | GitHub Auth | Ready |
|------|:----------:|:-----------:|:-----:|
| claude-command-centre | Yes | Yes | Yes |
| alteri | Yes | Yes | Yes |
| prototypes | No | Yes | Partial (needs `tembo.md`) |

## Anti-Patterns

**Dispatching vague specs.** Tembo cannot ask clarifying questions. If the acceptance criteria are ambiguous, the PR will be wrong. Spec first, dispatch second.

**Dispatching spikes.** Spikes produce knowledge (documents, findings, recommendations), not PRs. Tembo is optimized for code output. Use Claude Code interactive sessions for spikes.

**Skipping the completion sequence.** The template exists because every prior failure traced back to missing steps 5-6. Include all six steps, every time.

**Ignoring credit costs.** Tembo credits are a shared resource. Don't dispatch a 1pt typo fix that you could do in 30 seconds locally.

**Not checking Tembo health.** If Tembo's API is returning 500s, delegation will silently fail. Check `mcp__tembo__list_tasks` before assuming dispatch succeeded.

## Cross-Skill References

- **execution-modes** -- Determines whether a task is Tembo-appropriate (exec:quick/tdd = yes, exec:pair/checkpoint = no)
- **branch-finish** -- The post-merge protocol. Tembo handles steps 1-6 of the completion sequence; branch-finish's post-completion protocol (Linear status, closing comment, spec update, context archival) still applies.
- **platform-routing** -- Decision tree for choosing between Claude Code, Tembo, GH Actions, Cowork, and @mention surfaces.
- **issue-lifecycle** -- Closure rules apply to Tembo-created PRs. Agent assignee + single PR + merged + CI green = auto-close.
- **parallel-dispatch** -- For dispatching multiple Tembo tasks simultaneously. Each gets its own branch and PR.
- **drift-prevention** -- Tembo PRs should be checked against spec ACs before merge, especially for complex tasks.
