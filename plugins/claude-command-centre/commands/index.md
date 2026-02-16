---
description: |
  Scan and index the current repository to produce a structured map of modules, patterns,
  and integration points. The index feeds into spec writing and prevents redundant implementations.
  Use when onboarding to a new codebase, before writing a PR/FAQ, after major refactors,
  or when you need to understand what already exists.
  Trigger with phrases like "index the codebase", "scan the repo", "what patterns exist",
  "map the modules", "what's in this repo".
argument-hint: "[--full for complete re-index, default is incremental]"
platforms: [cli]
---

# Index Codebase

Scan the repository and produce a structured codebase index that maps modules, patterns, and integration points.

## Step 1: Check for Existing Index

Look for a cached index:

1. Check `.claude/codebase-index.md` in the project root
2. If found, read the `Generated` date and `Commit` hash
3. Compare against current `git log --oneline -1` to determine staleness
4. If `--full` flag is passed, skip to Step 2 regardless of staleness

**If index exists and is fresh** (generated commit is an ancestor of HEAD with <50 files changed):
- Run incremental update (Step 3)

**If no index exists or `--full` flag:**
- Run full scan (Step 2)

## Step 2: Full Repository Scan

Execute the codebase-awareness skill's scanning protocol in order:

### 2a. Structure Scan
- Read `package.json` / `Cargo.toml` / `pyproject.toml` for dependencies and scripts
- Generate directory tree (2 levels deep)
- Read configuration files (tsconfig, eslint, prettier, tailwind, etc.)
- Read project CLAUDE.md and README.md for project-specific context

### 2b. Pattern Detection
- Sample 3-5 representative files from each major directory
- Identify naming conventions (file naming, variable naming, component naming)
- Identify import/export patterns and module boundaries
- Read test files to capture testing framework, assertion style, and fixture patterns

### 2c. Integration Mapping
- Search for API route definitions (REST, GraphQL, tRPC)
- Search for database schema/model definitions
- Search for environment variable usage (external service integration points)
- Search for event emitters, WebSocket handlers, message queue consumers

## Step 3: Incremental Update

For repos with an existing fresh index:

1. Run `git diff --stat [index-commit]..HEAD` to identify changed paths
2. Re-scan only the directories containing changed files
3. Update affected sections of the index (module map, patterns, integrations)
4. Preserve unchanged sections verbatim

## Step 4: Generate Index Document

Produce the index following the format defined in the `codebase-awareness` skill:

```markdown
## Codebase Index -- [repo name]

**Generated:** [ISO date] | **Commit:** [short hash]

### Module Map
[table of modules, purposes, exports, dependencies]

### Patterns
[bullet list of framework, styling, state, testing, naming conventions]

### Integration Points
[bullet list of database, auth, external APIs, event systems]
```

## Step 5: Cache the Index

1. Write the index to `.claude/codebase-index.md`
2. If `.claude/` is not in `.gitignore`, suggest adding it (the index is session-specific, not committed)

## Step 6: Report

Summarize what was indexed:

```
Indexed [repo name] at [commit hash]:
- [N] modules mapped
- [N] patterns detected
- [N] integration points identified
- Mode: [full / incremental]
```

## What If

| Situation | Response |
|-----------|----------|
| **Monorepo with multiple packages** | Index each package separately. Produce one index per package, stored as `.claude/codebase-index-{package}.md`. |
| **Very large repo (1000+ files)** | Limit sampling to 2 files per directory. Focus on `src/` and `lib/` over generated or vendor directories. |
| **No package manager file found** | Infer project type from file extensions and directory structure. Note the ambiguity in the index. |
| **Index is stale but `--full` not passed** | Run incremental. If >200 files changed since last index, warn and suggest `--full`. |
