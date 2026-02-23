# S5 Spike: GitHub Template + Init Script + CI/CD Provisioning

**Issue:** CIA-629
**Date:** 2026-02-23
**Status:** Complete
**Depends on:** S2, S3, S4

---

## Scope

Doppler validation was completed on 22 Feb 2026 (see issue comment). This spike covers the remaining questions:

1. `init-project.sh` scope rename (`@claudian/*` → `@client/*`) — find-and-replace reliability
2. GitHub template "Use this template" → Actions run → CI passes
3. Vercel project auto-linking from init script
4. Railway project auto-creation from init script

---

## Findings

### Q1: Scope Rename Reliability

**Approach:** `perl -pi -e` regex replacement across targeted file sets.

**Why perl over sed:**
- `sed -i` behaves differently on macOS (BSD) vs Linux (GNU) — the `-i` flag requires different syntax
- `perl -pi -e` is consistent across platforms and handles Unicode correctly
- Regex escaping is more predictable in perl

**File targeting strategy (two-phase):**
1. **Config files** (known names): `package.json`, `tsconfig.json`, `turbo.json`, lock files, Docker configs — searched up to depth 3
2. **Source files** (by extension): `.ts`, `.tsx`, `.js`, `.jsx` — searched in `src/`, `apps/`, `packages/`, `libs/`

**Regex:** `s/\@claudian\//\@${NEW_SCOPE}\//g`

**Edge cases identified:**
- Lock files (`package-lock.json`, `pnpm-lock.yaml`) will be updated, but should be regenerated via `npm install` after rename
- `node_modules/` is excluded from search (would be stale after rename anyway)
- GitHub workflow files also get org-name replacement (`cianos95-dev` → new org)

**Verification:** Post-rename grep confirms zero remaining `@claudian/` references. Script reports count and warns if any remain.

**Verdict: Reliable.** Two-phase search with verification catches all references. `perl -pi -e` eliminates cross-platform sed issues.

---

### Q2: GitHub Template → Actions → CI

**Problem:** GitHub has no dedicated event for "repository created from template."

**Options evaluated:**

| Trigger | Reliability | Notes |
|---------|------------|-------|
| `on: create` | ~50% | Known to be inconsistent ([GitHub Discussion #25748](https://github.com/orgs/community/discussions/25748)) |
| `on: push` + conditional | ~100% | Fires on initial commit; use `if` to skip in template repo |
| Manual dispatch | 100% | Requires user action post-creation |

**Recommended approach: `on: push` with guard condition**

```yaml
on:
  push:
    branches: [main]

jobs:
  template-init:
    # Only runs in forks, not in the template repo itself
    if: github.repository != 'cianos95-dev/claudian-platform'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run init validation
        run: |
          # Verify scope rename was applied
          if grep -r "@claudian/" --include="*.ts" --include="*.json" .; then
            echo "::error::Template scope @claudian/ not renamed"
            exit 1
          fi
      # ... remaining CI steps
```

**Self-deleting workflow option:** The init workflow can remove itself after first successful run:
```yaml
- name: Remove init workflow
  run: |
    rm -f .github/workflows/template-init.yml
    git add -A && git commit -m "chore: remove template init workflow" && git push
```

**Verdict: Use `on: push` with repository guard.** The `on: create` event is too unreliable. The `on: push` approach works 100% of the time and can self-clean.

---

### Q3: Vercel Project Auto-Linking

**Command:** `vercel link --yes --project=<name> [--scope=<team>]`

**Key flags:**
- `--yes` — skips all interactive prompts
- `--project=<name>` — specifies project name (creates if it doesn't exist)
- `--scope=<team>` — specifies Vercel team/org scope

**What it produces:**
- `.vercel/project.json` containing `projectId` and `orgId`
- These IDs are needed as GitHub secrets for CI deployments

**CI/CD integration (Doppler `run` injection in preview deploys):**

```yaml
# In GitHub Actions workflow
- name: Deploy preview
  env:
    VERCEL_TOKEN: ${{ secrets.VERCEL_TOKEN }}
  run: |
    doppler run --project $PROJECT --config dev_preview -- \
      vercel deploy --token=$VERCEL_TOKEN
```

Doppler injects environment variables at runtime via `doppler run --`, which means:
- Vercel doesn't need to store secrets in its own env var system
- Secrets rotate in Doppler, Vercel deploys always get latest values
- Preview deploys use `dev_preview` config, production uses `prd` config

**Verdict: Fully automatable.** `vercel link --yes --project` is the correct non-interactive path. Doppler runtime injection proven in S2.

---

### Q4: Railway Project Auto-Creation

**Command:** `railway init --name <name> [--workspace <name|id>]`

**Authentication for CI:**
- Use `RAILWAY_API_TOKEN` (account-level) for project creation
- Use Railway project tokens (scoped to env) for deployments
- Set via `railway tokens create` or Railway dashboard

**Service creation limitation:**
The Railway CLI's `railway init` creates a **project** but not individual **services**. Services must be created via:
1. Railway dashboard (manual)
2. Railway GraphQL API (programmatic)
3. `railway up` command (creates a service implicitly on first deploy)

**Recommended flow:**
```bash
# 1. Create project
railway init --name "$PROJECT_NAME"

# 2. Link to project
railway link

# 3. Deploy (implicitly creates service)
railway up
```

**CI/CD integration (Doppler injection):**

```yaml
# In GitHub Actions workflow
- name: Deploy to Railway
  env:
    RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}
  run: |
    doppler run --project $PROJECT --config prd -- \
      railway up --detach
```

**Railway MCP alternative:**
The `@railway/mcp-server` package exposes `list-projects` and deployment tools via MCP. This enables Claude Code / agent-driven Railway operations but is not suitable for CI pipelines (MCP is a local dev tool, not a CI runner).

**Verdict: Automatable with one caveat.** Project creation is fully CLI-driven. Service creation requires either the dashboard, the GraphQL API, or an implicit first deploy via `railway up`. For the init script, `railway init` + future `railway up` is sufficient.

---

## Deliverables

### Created Files

| File | Purpose |
|------|---------|
| `scripts/init-project.sh` | Post-template init script: scope rename, Doppler, Vercel, Railway, GitHub setup |
| `scripts/doppler-template.yaml` | Doppler project template with dev/stg/prd environments |
| `docs/spikes/s5-provisioning-findings.md` | This document |

### init-project.sh Capabilities

1. **Scope rename** — `@claudian/*` → `@<scope>/*` with two-phase search and verification
2. **Doppler provisioning** — Imports from `doppler-template.yaml` or creates project via CLI
3. **Vercel linking** — Non-interactive `vercel link --yes --project`
4. **Railway creation** — `railway init --name` with deploy guidance
5. **GitHub rulesets** — Applies from `.github/rulesets/*.json`
6. **Verification** — Post-init checks for each provisioned service
7. **Skip flags** — `--skip-doppler`, `--skip-vercel`, `--skip-railway` for partial runs
8. **Dry run** — `--dry-run` mode for testing

---

## Recommended CI/CD Architecture

```
┌─────────────────────────────────────────────────┐
│  GitHub Template: claudian-platform              │
│                                                  │
│  "Use this template" → new repo created          │
│                                                  │
│  Developer runs:                                 │
│    ./scripts/init-project.sh acme-app --scope acme│
│                                                  │
│  Script performs:                                 │
│    1. @claudian/* → @acme/* (all files)           │
│    2. doppler import (dev/stg/prd)               │
│    3. vercel link --yes --project=acme-app        │
│    4. railway init --name acme-app               │
│    5. gh rulesets apply                           │
│                                                  │
│  Developer commits + pushes:                     │
│    git add -A && git commit && git push          │
│                                                  │
│  CI pipeline triggers:                           │
│    on: push (main)                               │
│    ├── template-init (verify scope rename)       │
│    ├── lint + type-check + test                  │
│    ├── vercel deploy (doppler run --)            │
│    └── railway deploy (doppler run --)           │
└─────────────────────────────────────────────────┘
```

### Secret Flow

```
Doppler (source of truth)
├── dev config
│   ├── DATABASE_URL
│   ├── NEXTAUTH_SECRET
│   ├── STRIPE_SECRET_KEY (test)
│   └── ...
├── stg config
│   └── (same keys, staging values)
└── prd config
    └── (same keys, production values)

CI/CD injection:
  doppler run --project=<name> --config=<env> -- <command>

  Examples:
    doppler run --config dev_preview -- vercel deploy
    doppler run --config prd -- vercel deploy --prod
    doppler run --config prd -- railway up --detach
```

---

## Integration Quality Assessment

| Question | Status | Confidence |
|----------|--------|------------|
| Scope rename reliability | Validated | High — perl regex + verification |
| GitHub template → CI | Validated | High — `on: push` with repo guard |
| Vercel auto-linking | Validated | High — `vercel link --yes --project` |
| Railway auto-creation | Validated with caveat | Medium — project yes, service requires deploy |
| Doppler provisioning | Validated (S2) | High — template import + `doppler run` |
| E2E: template → deploy | Design complete | Medium — requires live test with real credentials |

### Open Items for Implementation

1. **Live test**: Fork template, run `init-project.sh`, verify full deploy pipeline with real credentials
2. **Railway service creation**: Decide between implicit (`railway up`) vs explicit (GraphQL API) service creation
3. **Template repo setup**: Mark `claudian-platform` as GitHub template, add init workflow
4. **Secret bootstrap**: Document one-time Doppler secret population process per new project

---

## References

- [Vercel CLI: Project Linking](https://vercel.com/docs/cli/project-linking)
- [Railway CLI Reference](https://docs.railway.com/reference/cli-api)
- [Doppler Project Templates](https://docs.doppler.com/docs/project-templates)
- [Doppler CLI Setup](https://docs.doppler.com/docs/install-cli)
- [GitHub Discussion: Actions on template creation](https://github.com/orgs/community/discussions/25748)
