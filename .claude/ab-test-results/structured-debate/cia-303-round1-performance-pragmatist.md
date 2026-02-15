# Round 1: Performance Pragmatist Review — CIA-303

**Reviewer:** Performance Pragmatist (Orange)
**Round:** 1 (Independent Review)
**Date:** 2026-02-15

---

## Performance Pragmatist Review: CIA-303

**Scaling Summary:** Spec introduces an insights-driven adaptive loop but omits critical performance constraints: HTML parsing at scale will bottleneck on large sessions, unbounded retrospective analysis lacks cardinality limits, and the "drift detection" mechanism has no event volume budget or rate-limiting strategy.

### Critical Findings

- **HTML Parsing as Primary Path**: Parsing `/insights` HTML output per-session creates O(n) parsing overhead with no caching strategy. Session graphs with 100+ tool calls will produce multi-KB HTML. -> **Suggested optimization**: Implement streaming JSON extraction from `/insights` stderr if available, or cache parsed insights per session ID with TTL. Add cardinality limit (e.g., "last 50 sessions") to prevent unbounded parsing.

- **References/ Read-Through Metric Unbounded**: Tracking `Read` tool calls to `references/*.md` across all sessions has no storage or query budget. 1000 sessions x 10 references = 10K correlation records. -> **Suggested optimization**: Define retention window (e.g., 30 days), aggregation strategy (daily summaries not raw events), and max cardinality (e.g., top 20 references by read count).

- **Adaptive Threshold Recomputation Cost**: "Hooks consume insights data for dynamic thresholds" implies recalculating thresholds on every hook trigger. If `PostToolUse` fires 50 times/session, this is 50 insights queries. -> **Suggested optimization**: Cache computed thresholds per session with invalidation trigger (e.g., new insights data or every N minutes), or pre-compute at session start.

- **Retrospective Correlation Query Explosion**: "Correlate friction points with Linear issue outcomes" requires joining insights data (large, unstructured) with Linear issues (paginated API). No query plan or index strategy specified. -> **Suggested optimization**: Pre-aggregate friction points into per-issue summary at session close, store in local SQLite index. Define max lookback window (e.g., 90 days).

### Important Findings

- **No Quality Score Budget**: Quality scoring rubric (test 40%, coverage 30%, review 30%) applied retrospectively to all issues has no performance gate. Calculating coverage for 100 files per issue at scale will timeout. -> **Suggested approach**: Define sampling strategy (e.g., score top 10 issues by priority per cycle) or async batch scoring with result caching.

- **Insights Archive Format Schema-Less**: Archiving insights without schema validation means future parsing will handle arbitrary HTML structure changes. Recovery cost from malformed archives is unbounded. -> **Suggested approach**: Define minimal JSON schema for archived insights (timestamp, tool_count, session_id, friction_events[]), validate on write, gracefully degrade on read failures.

- **Hook Trigger Mismatch (20 vs 30)**: Hook threshold at 20 files vs skill threshold at 30 min/50% context creates ambiguity. If a hook fires at 18 files but 60% context, which takes precedence? -> **Suggested approach**: Unify thresholds into single budget model: percentage of combined limits (e.g., (file_count/max_files + context_pct) > threshold).

- **PreToolUse Hook Stub**: Incomplete hook logic means no pre-validation of insights parsing. If `/insights` is unavailable, the adaptive loop degrades silently with no fallback metrics. -> **Suggested approach**: Add health check in PreToolUse: if insights unavailable, log warning and use static thresholds as fallback.

### Consider

- **Caching Layer for Insights Parsing**: Introduce in-memory LRU cache (max 10 parsed insights objects) keyed by session ID. TTL = session duration + 5 min. Reduces redundant parsing when adaptive hooks query same session multiple times. Cost: ~1KB per cached object, 10KB total.

- **Rate Limiting for Drift Detection**: If drift triggers fire on every session, the adaptive loop could thrash (e.g., adjusting thresholds hourly based on noisy data). Define minimum observation window (e.g., 20 sessions or 7 days) before recalibrating thresholds. Prevents oscillation.

- **Async Retrospective Analysis**: Move "correlate friction with outcomes" to background job (e.g., daily cron) instead of blocking on-demand. Uses agent subagent pattern with `run_in_background: true`. Reduces latency for `/sdd:insights` command from ~10s (Linear API calls) to <1s (read cached results).

- **References/ Access Heatmap**: Instead of raw read counts, compute weighted score: (read_count x session_success_rate). Surfaces which references actually correlate with good outcomes. Storage: 1 row per reference per day (max 100 references x 90 days = 9K rows). Query cost: single index scan.

### Quality Score (Performance Lens)

| Dimension | Score (1-5) | Notes |
|-----------|-------------|-------|
| Scaling characteristics | 2 | HTML parsing + correlation queries don't scale beyond 100 sessions. No cardinality limits. |
| Resource budget | 2 | No memory/storage budget for insights cache, archive, or retrospective index. |
| Latency impact | 3 | Adaptive hooks add per-trigger query overhead. `/sdd:insights` blocking on Linear API calls. |
| Caching strategy | 1 | Zero caching specified. Every hook trigger reparses insights. |
| Operational cost | 3 | Linear API calls in retrospective loop could hit rate limits at scale. No batch optimization. |

**Overall Performance Readiness: 2.2/5** -- Architecture is sound but implementation lacks resource guardrails. Will work for <50 sessions, degrade badly beyond 200.

### What the Spec Gets Right (Performance)

- **Layered Monitoring Model**: Separating structural (CI), runtime (insights), and adaptive (this issue) prevents conflating detection mechanisms. Clean separation of concerns reduces coupling overhead.

- **Modular Insights Integration**: Creating a dedicated `insights-integration` skill instead of hardcoding parsing into every hook allows centralized optimization (e.g., swapping HTML parser for JSON API when available).

- **Retrospective as Separate Concern**: Not making adaptive thresholds real-time (vs periodic retrospective) avoids hot-path complexity. Batch analysis is the right model for this use case.

- **References/ Read-Through Metric**: Tracking whether context docs are actually consumed is a high-signal, low-cost metric. Correlation with outcomes will surface documentation quality issues.

---

**Recommendation**: **CONDITIONAL APPROVE** -- Add performance constraints before implementation.
