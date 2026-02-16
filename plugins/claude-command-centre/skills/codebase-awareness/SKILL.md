---
name: codebase-awareness
description: |
  Repository scanning and indexing protocol that produces a structured map of modules, patterns,
  and integration points. Feeds into spec writing to prevent redundant implementations.
  Use when onboarding to a new codebase, before writing a PR/FAQ for a new feature, when the
  codebase index is stale, or when you need to understand existing patterns before implementation.
  Trigger with phrases like "index the codebase", "scan the repo", "what patterns does this project use",
  "map the modules", "update the codebase index", "what exists already".
---

# Codebase Awareness

Before writing specs or implementing features, the agent needs an accurate mental model of the existing codebase. This skill defines a scanning protocol that produces a structured index, preventing redundant implementations and ensuring new work integrates with existing patterns.

## What the Index Contains

### Module Map

A hierarchical view of the repository's structure:

- **Directories** -- Purpose of each top-level and key nested directory
- **Key exports** -- Public APIs, components, utilities, and their signatures
- **Internal dependencies** -- Which modules import from which (dependency graph)

### Pattern Summary

Conventions and frameworks already established in the codebase:

- **Frameworks** -- Runtime frameworks (React, Next.js, Express, etc.)
- **Conventions** -- Naming (camelCase, snake_case), file organization, import patterns
- **Test patterns** -- Test runner, assertion style, fixture patterns, coverage tooling
- **Naming schemes** -- Component naming, route naming, database table naming

### Integration Points

External boundaries and shared state:

- **APIs** -- REST endpoints, GraphQL schemas, RPC interfaces
- **Shared state** -- Databases, caches, message queues, global stores
- **Event buses** -- Pub/sub channels, webhooks, WebSocket events
- **External services** -- Third-party APIs, SaaS integrations, cloud services

## Scanning Protocol

### Step 1: Structure Scan

```
1. Read package.json / Cargo.toml / pyproject.toml (dependencies, scripts)
2. Read directory tree (2 levels deep)
3. Read configuration files (tsconfig, eslint, prettier, etc.)
4. Read CLAUDE.md / README.md for project-specific instructions
```

### Step 2: Pattern Detection

```
1. Sample 3-5 files from each major directory
2. Identify naming conventions, import patterns, export styles
3. Read test files to understand testing patterns
4. Check for shared utilities, hooks, or helper modules
```

### Step 3: Integration Mapping

```
1. Grep for API route definitions
2. Grep for database model/schema definitions
3. Grep for environment variable usage (integration points)
4. Grep for event emitters/listeners
```

### Step 4: Index Generation

Produce the index in a structured format that can be cached and referenced:

```markdown
## Codebase Index — [repo name]

**Generated:** [date] | **Commit:** [short hash]

### Module Map
| Module | Purpose | Key Exports | Dependencies |
|--------|---------|-------------|-------------|
| src/components | UI components | Button, Modal, Form | react, @radix-ui |
| src/api | API routes | /users, /auth, /data | express, prisma |
| src/lib | Shared utilities | cn(), formatDate() | clsx, date-fns |

### Patterns
- **Framework:** Next.js 14 (App Router)
- **Styling:** Tailwind CSS + cn() utility
- **State:** Zustand stores in src/stores/
- **Testing:** Vitest + Testing Library
- **Naming:** kebab-case files, PascalCase components

### Integration Points
- **Database:** PostgreSQL via Prisma (src/lib/prisma.ts)
- **Auth:** NextAuth.js (src/app/api/auth/)
- **External:** Stripe API (src/lib/stripe.ts), OpenAI (src/lib/ai.ts)
```

## Caching and Staleness

- The index is cached in the project's `.claude/` directory as `codebase-index.md`
- On subsequent runs, `/ccc:index` performs an incremental update:
  1. Check `git diff --stat` since the index's commit hash
  2. Re-scan only changed directories
  3. Update affected sections of the index
- Full re-index when: major dependency changes, new top-level directories, or manual trigger

## Integration with Spec Writing

When `/ccc:write-prfaq` runs, it automatically checks for a codebase index and includes it as a "Current Codebase Context" section in the spec. This ensures:

- New features reference existing patterns rather than inventing new ones
- Specs account for existing integration points
- Acceptance criteria include integration requirements (not just feature requirements)
- Reviewers can quickly assess whether the spec conflicts with existing architecture

## When to Re-Index

| Trigger | Action |
|---------|--------|
| First time working in a repo | Full index |
| Before writing a new PR/FAQ | Check staleness, incremental update |
| After major refactor or dependency update | Full re-index |
| After merging a large PR | Incremental update |
| Manual trigger (`/ccc:index`) | Full or incremental based on staleness |
