---
name: factory-dispatch
description: |
  Dispatch a well-specified CCC issue to Factory for background agent execution.
  Handles dispatch surface selection (Linear delegation vs REST API), Cloud Template
  routing, and post-dispatch monitoring. Use when an issue is well-specified
  (exec:quick or exec:tdd), the task doesn't require interactive pairing, and you
  want async background execution.
  Trigger with phrases like "dispatch to factory", "factory this", "send to factory",
  "background implement", "delegate to factory", "async dispatch", "factory dispatch",
  "run this in background", "factory execute".
compatibility:
  surfaces: [code, cowork, desktop]
  tier: universal
  degradation_notes: "Linear delegation works from any surface. REST API dispatch from Code only."
---

# Factory Dispatch

Factory dispatch is the CCC pattern for sending well-specified implementation tasks to Factory for background agent execution. Factory spins up an isolated cloud VM with a pre-built environment (Cloud Template), runs Claude Code, and produces a PR automatically. The key value is async execution -- you dispatch and move on to the next task without waiting.

## When to Dispatch to Factory

Factory dispatch is appropriate when ALL of these are true:

1. **Well-specified.** The issue has clear acceptance criteria. exec:quick or exec:tdd. If the spec is vague, Factory will either guess wrong or stall.
2. **No interactive pairing needed.** exec:pair and exec:checkpoint require human checkpoints. Factory runs unattended.
3. **Repo has a Cloud Template.** The target repo must have a Factory Cloud Template configured (see table below).
4. **Not a spike.** Spikes produce knowledge, not PRs. Use Claude Code interactive sessions for spikes.

**Do NOT dispatch to Factory when:**
- The task requires interactive decision-making (exec:pair, exec:checkpoint)
- The spec is draft or needs grounding (spec:draft, research:needs-grounding)
- The task is a spike (type:spike) -- spikes produce knowledge, not PRs
- The repo has no Cloud Template (Factory won't have the right environment)
- You need the result immediately (Factory is async; latency is 5-30 minutes)

## Dispatch Surfaces

### Surface 1: Linear Delegation (Preferred)

Assign the issue to Factory in Linear's assignee field or set the Delegate field. Factory picks up delegated issues automatically via its native Linear integration, reads the issue description as the spec, and creates a PR.

**Advantages:** Works from any surface (Cowork, Desktop, mobile, web). No Claude Code session needed. Leverages Linear's native delegation UX. No prompt construction required -- Factory reads the issue directly.

**How to delegate:**
1. Open the Linear issue
2. Set Assignee or Delegate field to "Factory"
3. Factory picks up the issue, clones the repo using the Cloud Template, and executes

### Surface 2: REST API Dispatch (from Claude Code)

For cases requiring custom prompt construction beyond the issue description:

```
POST https://api.factory.ai/api/v0/machines/templates
Authorization: Bearer <FACTORY_API_KEY>
```

**Advantages:** Full prompt control, can inject structured context. Returns a task ID for monitoring.

**Disadvantages:** Requires Claude Code session, API key management, more complex setup.

### Which Surface to Use

| Scenario | Surface | Reason |
|----------|---------|--------|
| Standard issue implementation | Linear delegation | Simplest path, works from anywhere |
| Triaging from Cowork/Linear UI | Linear delegation | No session needed |
| Need custom prompt beyond issue description | REST API | Full prompt control |
| Batch dispatching multiple issues | Linear delegation | Assign each to Factory |

## Cloud Templates

Factory Cloud Templates pre-configure the development environment for each repository. Templates define: repo URL, setup script, environment variables, and base image.

| Template Name | Template ID | Repository | Setup | Status |
|--------------|-------------|------------|-------|--------|
| `ccc-dev` | `SxWZvGdi6AyExQnGxDSC` | claude-command-centre | No-op (markdown only) | Active |
| `claudian-platform-dev` | `xofMgV7UE42DGjpwhv9a` | claudian-platform | `pnpm install` | Active |

**Template gotchas:**
- `environmentVariables` must be `[]` (array), not `{}` (object)
- Repos must use personal account URL (`cianos95-dev/`), NOT org URL
- Templates auto-detect `AGENTS.md` during build (step 15/16 in build log)
- Build takes ~50-60 seconds
- No rebuild endpoint -- must delete + recreate to retrigger build

## Dispatch Prompt Template

When using REST API dispatch (not Linear delegation), include the completion sequence. For Linear delegation, ensure the issue description contains acceptance criteria -- Factory reads the description directly.

```markdown
## Context
{Brief description of what needs to be done}
Linear issue: {CIA-XXX}
Branch: `factory/{CIA-XXX}-{slug}`

## Acceptance Criteria
- [ ] {AC 1}
- [ ] {AC 2}
- [ ] {AC N}

## Constraints
- Verification command: `{pnpm typecheck && pnpm lint && pnpm test}`
- Do not modify: {protected paths, if any}

## Completion Sequence (REQUIRED)
After all acceptance criteria pass verification:
1. Run: `{verification command}` -- all must pass
2. Stage changes: `git add {specific files}`
3. Commit: `git commit -m "feat: {summary}\n\nCloses {CIA-XXX}\n\nCo-Authored-By: Claude Code <claude-code[bot]@users.noreply.github.com>"`
4. Push: `git push -u origin factory/{CIA-XXX}-{slug}`
5. Create PR: `gh pr create --title "{title}" --body "Closes {CIA-XXX}\n\n## Summary\n{bullets}"`
6. Enable auto-merge: `gh pr merge --auto --squash`

## References
- Repo: {github-url}
- Spec: {linear-issue-url}
```

**Critical notes:**
- Step 3: Must use `Closes` (not "Implements", "Fixes", or "References") for GitHub-Linear auto-close.
- Step 6: Must run AFTER step 5 (needs the PR number).

## Multi-Project Routing

When dispatching from a Linear issue, the issue's **project** field determines which repository to target. All projects belong to the **Claudian** team.

| Linear Project | Repository | Cloud Template | Notes |
|----------------|------------|---------------|-------|
| Claude Command Centre (CCC) | `claude-command-centre` | `ccc-dev` | Markdown/config only |
| Claudian Platform | `claudian-platform` | `claudian-platform-dev` | pnpm monorepo |

**Routing rules:**
1. Read the issue's project field from Linear before dispatching.
2. Map project -> repository -> Cloud Template using the table above.
3. Unrecognized projects: do not dispatch. Flag for human review.
4. Cross-project issues: rare. If an issue spans multiple repos, create separate tasks per repo.

## Overflow Agents

When Factory is unavailable or budget-constrained, use these alternatives:

| Agent | Dispatch Method | Cost | Best For |
|-------|----------------|------|----------|
| **Amp** | GitHub issue assignment or direct session | Free ($15/day grant) | Implementation overflow |
| **cto.new** | GitHub issue or web UI | Free | Code-only tasks, architecture review |
| **Copilot** | GitHub issue assignment | Included (Education budget) | CI fixes, small changes |

## Post-Dispatch Monitoring

After dispatching, monitor via:

1. **Linear:** Factory updates the issue status and posts a comment when the PR is ready.
2. **GitHub:** Watch for the PR on the `factory/*` branch.
3. **Factory dashboard:** Check task status in the Factory web UI.

**If Factory stalls or fails:**
- Verify the repo has an active Cloud Template
- Check Factory service status
- Fallback: implement directly in a Claude Code session using the same dispatch prompt template

## Integration with CCC Pipeline

Factory dispatch fits into the CCC pipeline as one of multiple entry points into the zero-touch loop:

```
Entry Points:
  Claude Code (manual) ---+
  GH Actions (label) -----+
  Factory (Linear deleg) --+---> Implement -> Verify -> Commit -> Push -> PR -> Auto-merge -> Linear Close
  Cowork (spec/review) ----+
  @mention (review) -------+
```

After Factory creates a PR with `Closes CIA-XXX` and auto-merge enabled:
1. CI runs -> passes
2. Copilot auto-reviews
3. PR auto-merges (squash)
4. Branch auto-deletes
5. GitHub-Linear sync fires `Closes CIA-XXX` -> issue transitions to Done

No human intervention required for well-specified tasks.

## Anti-Patterns

**Dispatching vague specs.** Factory cannot ask clarifying questions. If the acceptance criteria are ambiguous, the PR will be wrong. Spec first, dispatch second.

**Dispatching spikes.** Spikes produce knowledge (documents, findings, recommendations), not PRs. Factory is optimized for code output. Use Claude Code interactive sessions for spikes.

**Skipping the completion sequence.** The template exists because every prior failure traced back to missing steps 5-6. Include all six steps, every time.

**Not verifying dispatch.** Always verify Factory picked up the task within 30 minutes. Silent failures are possible.

## Cross-Skill References

- **execution-modes** -- Determines whether a task is Factory-appropriate (exec:quick/tdd = yes, exec:pair/checkpoint = no)
- **branch-finish** -- The post-merge protocol. Factory handles the completion sequence; branch-finish's post-completion protocol (Linear status, closing comment) still applies.
- **platform-routing** -- Decision tree for choosing between Claude Code, Factory, Cowork, and @mention surfaces.
- **issue-lifecycle** -- Closure rules apply to Factory-created PRs. Agent assignee + single PR + merged + CI green = auto-close.
- **parallel-dispatch** -- For dispatching multiple Factory tasks simultaneously. Each gets its own branch and PR.
- **drift-prevention** -- Factory PRs should be checked against spec ACs before merge, especially for complex tasks.
