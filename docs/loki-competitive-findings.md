# Loki Mode Competitive Analysis — Remaining Findings

**Created:** 2026-02-22  
**Updated:** 2026-02-22 — blind mode, anti-sycophancy, severity model incorporated; Linear issues created.

## Context

Competitive analysis of Loki Mode (asklokesh/loki-mode) v5.52.1 vs CCC. Treated as quasi-competitor: no dependencies or intended compatibility, but incorporate learnings where Loki supersedes.

## Incorporated (2026-02-22)

- **Blind mode, anti-sycophancy, severity model** — Added to `skills/adversarial-review/SKILL.md`. See "Blind Mode, Anti-Sycophancy, and Severity Model" section and Option E protocol updates.

## Linear Issues Created

| Issue | Title | URL |
|-------|-------|-----|
| CIA-651 | [CCC] Spike: Loki review patterns | https://linear.app/claudian/issue/CIA-651 |
| CIA-652 | [CCC] Spike: 3-tier memory extension (Loki-inspired) | https://linear.app/claudian/issue/CIA-652 |
| CIA-653 | [CCC] Spike: Dashboard/Metrics/Analytics - Loki vs PostHog stack | https://linear.app/claudian/issue/CIA-653 |
| CIA-654 | [CCC] Loki competitive analysis — remaining findings for review | https://linear.app/claudian/issue/CIA-654 |

## Findings Still to Incorporate

1. **Mock/mutation detection gates** — Loki Gates 8–9. Add as optional gates for `exec:tdd` in quality-scoring or tdd-enforcement.
2. **Compound learning** — Add `.ccc/solutions/` pattern when debugging succeeds (covered by CIA-652 3-tier memory spike).
3. **Phase transition criteria** — Document explicit transition rules per stage.
4. **RARV naming** — Adopt Reason-Act-Reflect-Verify naming in execution-engine and drift-prevention.
5. **Progressive skill loading** — Add 00-index or similar routing table for skills.
6. **CONTINUITY-style Mistakes & Learnings** — Extend `.ccc-progress.md` with structured error logging.

## Priority

- **High:** Mock/mutation gates (test quality gap)
- **Medium:** Compound learning (CIA-652), phase transition criteria, dashboard assessment (CIA-653)
- **Low:** RARV naming, progressive index, structured learnings

## Linear MCP / API Diagnosis

**Problem:** `plugin-linear-linear` MCP does not expose `create_issue` in this Cursor session. Available tools list includes `user-linear-create_issue` but `user-linear` server is not in available servers list.

**Workaround (verified):** Use Linear GraphQL API directly with `LINEAR_API_KEY`:
```bash
curl -s -X POST https://api.linear.app/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: $LINEAR_API_KEY" \
  -d '{"query":"mutation($teamId: String!, $title: String!, $description: String!) { issueCreate(input: { teamId: $teamId, title: $title, description: $description }) { success issue { identifier url } } }", "variables": {...}}'
```

**Doppler:** `doppler run -- env | grep LINEAR` requires a project (`-p` flag). Connectors use `doppler_key: LINEAR_API_KEY` — ensure Doppler project is configured for the repo. If not, set `LINEAR_API_KEY` in shell or `.env` for API-based issue creation.
