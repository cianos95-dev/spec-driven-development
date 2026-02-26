---
linear: CIA-662
exec: pair
status: ready
template: prfaq-quick
review-gate: architectural-purist, security-skeptic
created: 2026-02-25T00:00:00Z
updated: 2026-02-25T00:00:00Z
---

# Alteri → Claudian-Platform Migration Spec

## One-Liner

**For** the Claudian engineering team, **who** manages Alteri and SoilWorx as separate repositories with diverging dependencies, **this** monorepo migration **will** enable shared packages (@claudian/ai, @claudian/db, @claudian/shared), unified CI/CD, and coordinated releases. **Unlike** the current multi-repo setup, **this** eliminates cross-repo dependency drift and provides a single source of truth.

## Press Release (Internal)

**Alteri migrates from standalone repository to claudian-platform monorepo**, enabling shared packages (@claudian/ai, @claudian/db, @claudian/shared), unified CI/CD, and coordinated releases with SoilWorx. The migration preserves all existing functionality — XState conversation flows, R analysis environment, Supabase database, and Linear agent session pipeline — while eliminating cross-repo dependency drift.

## Current Architecture

Alteri is already a Turborepo monorepo (pnpm workspaces):

* **apps/web/** — Next.js 15.1.3, React 19, App Router
* **packages/ai/** — Vercel AI SDK v6 (streamText, generateText), Anthropic + OpenAI providers
* **packages/database/** — Supabase PostgreSQL, dual client (browser anon + server service role), RLS policies, migrations
* **packages/shared/** — Cross-package TypeScript types (FrameworkId, AlignmentFramework, Participant, SessionContext)
* **packages/state-machines/** — XState v5 conversation orchestration (8 machines, @xstate/test coverage)
* **packages/r-analysis/** — R network analysis (renv, 371 packages, MCP servers r-btw + r-session)
* **.github/workflows/** — agent-session-worker.yml (Linear agent intent routing)

## Source Path Mapping

| Current (alteri/) | Target (claudian-platform/) | Notes |
|---|---|---|
| apps/web/ | apps/alteri/ | Rename for clarity in monorepo |
| packages/ai/ | packages/ai/ | → @claudian/ai (shared, pending CIA-626) |
| packages/database/ | packages/database/ | → @claudian/db (shared, pending Supabase decision) |
| packages/shared/ | packages/shared/ | → @claudian/shared (merge with SoilWorx types) |
| packages/state-machines/ | packages/alteri-state-machines/ | Alteri-specific, not shared |
| packages/r-analysis/ | packages/alteri-r-analysis/ | Alteri-specific, isolated R env |
| .github/workflows/ | .github/workflows/ | Add path filters for monorepo |
| .claude/ | .claude/ (root, merge) | Merge skills with monorepo root |
| docs/ | apps/alteri/docs/ | App-specific docs |
| turbo.json | turbo.json (root, merge) | Merge task pipelines |
| pnpm-workspace.yaml | pnpm-workspace.yaml (root) | Already defined in claudian-platform |

## Package Extraction Plan

### Phase 1: Shared Packages (pending CIA-626 + CIA-627 spikes)

**@claudian/ai** (from packages/ai/):

* AI SDK v6 streaming utilities, model initialization, provider config
* System prompts stay Alteri-specific (DO NOT extract — they encode alignment philosophies)
* Shared: createStreamLine(), MultiFrameworkStream type, model registry
* **Blocked by** CIA-626 — spike determines final API surface and Langfuse integration pattern

**@claudian/db** (from packages/database/):

* Supabase dual client pattern (browser + server)
* Migration infrastructure, RLS policy framework
* **Decision needed:** shared Supabase project or separate projects per app?
* Schema types auto-generated — each app has its own schema

**@claudian/shared** (from packages/shared/):

* Merge Alteri types (FrameworkId, AlignmentFramework, Participant) with SoilWorx types
* Namespace: @claudian/shared/alteri, @claudian/shared/soilworx, @claudian/shared/common

### Phase 2: Alteri-Specific Packages (lift and shift)

**@alteri/state-machines** (from packages/state-machines/):

* 8 XState v5 machines: session (parent), consent, demographics, scenario, reflection, framework, evaluation, config
* Snapshot persistence via Supabase session_snapshots table
* Tests via @xstate/test path coverage
* Lift-and-shift — no architectural changes needed
* Update imports from local workspace refs to @claudian/* packages

**@alteri/r-analysis** (from packages/r-analysis/):

* Isolated R environment (no JS runtime dependency)
* renv.lock with 371 packages (network analysis, multilevel modeling, visualization)
* MCP servers (r-btw, r-session) need path updates in .mcp.json
* Data via symlinks — symlink targets must be updated for new location
* Scripts: 00_setup.R, 01_data_prep.R, psynets/ course scripts

## XState Migration Strategy

**Approach:** Lift-and-shift. No refactoring.

XState v5 setup() pattern is already correct. Machine hierarchy:

* sessionMachine (parent) orchestrates 6 phases: consent → demographics → scenario → comparison → reflection → results
* Each phase has a child machine with its own context, events, and states
* configMachine (standalone) manages feature flags and experiment variants

**Migration checklist:**

- [ ] Update all imports from `@alteri/state-machines` to workspace reference
- [ ] Verify snapshot persistence with Supabase after path change
- [ ] Run @xstate/test path coverage — all transitions must pass
- [ ] Verify streamingActor invocation (fromPromise) connects to AI SDK correctly

**Risk:** Snapshot restoration. Existing snapshots in production Supabase reference old module paths. Migration must handle backward-compatible deserialization or migrate existing snapshots.

## R Analysis Handling

**Approach:** Isolated lift-and-shift with path updates only.

R analysis has ZERO runtime coupling to the Next.js app. It is a co-located data science environment.

**Migration steps:**

- [ ] Move packages/r-analysis/ → packages/alteri-r-analysis/
- [ ] Update renv project path in .Rprofile
- [ ] Update data/ symlinks to new Obsidian vault paths
- [ ] Update .mcp.json r-btw and r-session server paths
- [ ] Run scripts/00_setup.R to verify environment
- [ ] Verify renv::restore() succeeds in new location

**Risk:** Low. renv.lock is committed. Environment is fully reproducible. No breaking changes expected.

## Agent Session Pipeline Migration

**Current:** GitHub Actions workflow_dispatch → Node.js agent-session-worker → LinearAgentClient → intent routing (status/expand/help/unknown) → response posted to Linear.

**Migration impact:**

* Workflow file moves to monorepo .github/workflows/
* Must add path filter: `paths: ['packages/alteri-agent-session/**', 'apps/alteri/**']`
* Package @alteri/agent-session needs workspace reference updates
* LINEAR_AGENT_TOKEN GitHub secret: already org-level, no change needed
* LinearAgentClient imports: update to monorepo paths

**Risk:** Medium. Workflow_dispatch does not use path filters (manual trigger), but if auto-testing triggers are added later, path filters matter.

## CI Workflow Migration

**Current workflows (1 confirmed):**

| Workflow | Trigger | Purpose | Migration Action |
|---|---|---|---|
| agent-session-worker.yml | workflow_dispatch | Process Linear agent sessions | Add monorepo path context, update pnpm filter |

**New workflows needed:**

* Typecheck (pnpm --filter @alteri/* typecheck)
* Lint (pnpm --filter @alteri/* lint)
* Test (pnpm --filter @alteri/* test)
* E2E (Playwright against apps/alteri/)
* R setup verification (renv::restore() + 00_setup.R)

**Turborepo integration:**

* turbo.json task pipeline: build → typecheck → lint → test
* Shared package changes trigger downstream app rebuilds
* R analysis excluded from Turbo pipeline (not a JS package)

## Environment Variables & Secrets

| Variable | Scope | Migration Action |
|---|---|---|
| NEXT_PUBLIC_SENTRY_DSN | Browser | Move to apps/alteri/.env |
| SENTRY_DSN | Server | Move to apps/alteri/.env |
| SENTRY_ORG / SENTRY_PROJECT | Build | Keep as GitHub secret |
| SENTRY_AUTH_TOKEN | Build | Keep as GitHub secret |
| NEXT_PUBLIC_SUPABASE_URL | Browser | Move to shared env or apps/alteri/.env |
| NEXT_PUBLIC_SUPABASE_ANON_KEY | Browser | Same |
| SUPABASE_SERVICE_ROLE_KEY | Server | CRITICAL: server-only, never in client bundle |
| ANTHROPIC_API_KEY | Server | Move to shared env (used by @claudian/ai) |
| OPENAI_API_KEY | Server | Move to shared env |
| LINEAR_AGENT_TOKEN | CI | Keep as GitHub org secret |

**Credential management:** All secrets in Doppler (claude-tools/dev). Vercel env vars configured per-project.

## Breaking Change Risk Matrix

| Risk | Severity | Likelihood | Mitigation |
|---|---|---|---|
| Import path breakage across all packages | High | Certain | Automated find-and-replace, TypeScript compilation as gate |
| XState snapshot deserialization failure | High | Medium | Migration script for existing snapshots, backward-compat layer |
| Supabase project isolation decision | High | N/A | Decision gate: shared vs separate projects |
| R renv restoration failure in new path | Low | Low | renv.lock is portable; test in CI |
| CI workflow path filter misconfiguration | Medium | Medium | Test workflow_dispatch manually post-migration |
| Turborepo cache invalidation on shared package changes | Medium | Likely | Configure correct task dependencies in turbo.json |
| AGENTS.md / CLAUDE.md conflicts when merging | Low | Certain | Manual merge, keep app-specific skills in apps/alteri/.claude/ |

## Rollback Plan

1. Keep alteri repo read-only (archive, do not delete) for 30 days post-migration
2. Vercel deployment rollback: revert to last alteri-repo deployment
3. Supabase: no schema changes in migration — rollback is deploy from old repo
4. GitHub Actions: old workflows still in archived repo
5. R analysis: renv.lock in both repos — environment is reproducible from either

## Acceptance Criteria

- [ ] AC1: All packages compile in claudian-platform (pnpm typecheck passes)
- [ ] AC2: All unit tests pass (pnpm test)
- [ ] AC3: All E2E tests pass (participant flow: consent → results)
- [ ] AC4: XState snapshot persistence works (save + restore cycle)
- [ ] AC5: R analysis environment verifies (scripts/00_setup.R passes)
- [ ] AC6: Agent session worker processes intents correctly (manual workflow_dispatch test)
- [ ] AC7: Vercel deployment succeeds from monorepo (apps/alteri/)
- [ ] AC8: Zero credential exposure in client bundle (audit NEXT_PUBLIC_* vars)
- [ ] AC9: Streaming responses work (3 framework multiplexed NDJSON)
- [ ] AC10: Old alteri repo archived on GitHub

## Open Questions (Pending Spikes)

1. **@claudian/ai API surface** — pending CIA-626 (AI SDK spike). Determines what is shared vs app-specific.
2. **Observability wiring** — pending CIA-627 (Sentry + PostHog + Langfuse + Honeycomb). Determines @claudian/analytics package shape.
3. **Supabase project model** — shared project (cost-efficient, schema coupling) vs separate projects (isolation, independent scaling)?

## Dependencies

* **Blocked by:** CIA-626 (AI SDK spike), CIA-627 (observability spike) — for shared package API surfaces only
* **Can proceed without blockers:** Source path mapping, XState lift-and-shift, R analysis move, CI workflow setup, env var migration
* **Blocks:** Alteri migration implementation, Conference Demo (May 15)
