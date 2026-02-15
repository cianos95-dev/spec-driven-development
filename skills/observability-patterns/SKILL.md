---
name: observability-patterns
description: |
  Stage 7 verification tool selection, three-layer plugin monitoring stack, and structural validation
  integration. Covers when to use PostHog vs Sentry vs Honeycomb vs Vercel Analytics, how cc-plugin-eval
  gates releases, and how runtime /insights data feeds the adaptive methodology loop.
  Use when choosing observability tools for Stage 7 verification, setting up plugin structural validation,
  configuring CI gates for plugin releases, or understanding the monitoring stack layers.
  Trigger with phrases like "which monitoring tool", "Stage 7 verification", "observability setup",
  "plugin validation", "cc-plugin-eval", "structural validation", "monitoring stack", "analytics vs
  error tracking", "release gates", "plugin health check".
---

# Observability Patterns

Observability for SDD projects operates at two levels: **application-level** (monitoring the software you build) and **plugin-level** (monitoring the SDD plugin itself). This skill covers both, with emphasis on Stage 7 verification tool selection and the three-layer plugin monitoring stack.

## Application-Level Observability

### The Four-Tool Stack

Each tool in the decided stack fills a distinct role. Using the wrong tool for a task produces either blind spots or redundant data.

| Tool | Answers This Question | Does NOT Answer |
|------|----------------------|-----------------|
| **PostHog** | Are users doing what we expected? | Why is the server slow? |
| **Sentry** | What errors are users hitting? | Which features are popular? |
| **Honeycomb** | Where is latency hiding in the request path? | What do users click on? |
| **Vercel Analytics** | Are Core Web Vitals healthy? | Are API endpoints erroring? |

### Stage 7 Verification Patterns

Stage 7 (Verification) confirms that shipped code works in production. Different feature types require different verification approaches.

#### UI Feature Verification

```
PostHog: Create a cohort of users who accessed the new feature.
         Check: activation rate > 0, no rage clicks, session replay shows expected flow.
Vercel:  Check: LCP/CLS/FID within thresholds on affected pages.
Sentry:  Check: no new error groups from affected components.
```

**Evidence for `/sdd:close`:**
- PostHog screenshot showing feature activation rate
- Vercel Analytics screenshot showing stable web vitals
- Sentry confirmation: zero new issues from affected component

#### API Feature Verification

```
Honeycomb: Query traces for the new endpoint. Check: p50/p95/p99 latency within SLA.
Sentry:    Check: no new error groups from the endpoint handler.
PostHog:   Check: custom events fire correctly (if applicable).
```

**Evidence for `/sdd:close`:**
- Honeycomb trace query showing latency percentiles
- Sentry confirmation: zero 5xx errors from the endpoint
- PostHog event funnel (if user-facing analytics were part of the spec)

#### Infrastructure Feature Verification

```
Honeycomb: Trace the infrastructure change path. Compare before/after latency.
Sentry:    Monitor for regression: error rate should not increase post-deploy.
Vercel:    Check build times, edge function cold starts (if applicable).
```

**Evidence for `/sdd:close`:**
- Before/after Honeycomb comparison showing no latency regression
- Sentry error rate graph spanning deploy window

### When to Skip Tools

Not every verification needs all four tools. Use the minimum set that answers the spec's acceptance criteria.

| Acceptance Criterion Type | Minimum Tooling |
|--------------------------|-----------------|
| "Users can do X" | PostHog (did they?) |
| "Error rate stays below Y" | Sentry (did it?) |
| "Response time under Z ms" | Honeycomb (is it?) |
| "Page loads in under N seconds" | Vercel Analytics (does it?) |
| "Feature flag rollout to 10%" | PostHog (flag + analytics) |

If the acceptance criteria don't mention performance, skip Honeycomb. If they don't mention user behavior, skip PostHog. Over-instrumenting creates noise that obscures signal.

## Plugin-Level Monitoring: Three-Layer Stack

The SDD plugin itself needs monitoring to ensure methodology health. This operates at three layers, each independent but feeding into the next.

### Layer 1: Structural Validation (Pre-Release)

**Tool:** [cc-plugin-eval](https://github.com/sjnims/cc-plugin-eval)

**What it measures:** Do plugin components trigger correctly? Are there conflicts between skills? Do commands resolve to valid handlers?

**When it runs:** Before every plugin release. Optionally in CI on every PR that touches skills, commands, or agents.

> See [references/structural-validation.md](references/structural-validation.md) for cc-plugin-eval integration details, CI gate configuration, metrics definitions, and the four evaluation stages.

### Layer 2: Runtime Observability (Post-Session)

**Tool:** Claude Code `/insights`

**What it measures:** Which skills actually triggered during sessions. Where users got stuck (friction points). Context efficiency. Tool usage distribution.

**When it runs:** After sessions, on-demand via `/sdd:insights`.

**Key metrics from /insights:**
- Skill trigger frequency (which skills are used, which are dormant)
- Session friction points (errors, retries, context exhaustion)
- Tool usage distribution (MCP vs direct, delegation effectiveness)
- Session success rate (fully-achieved vs partially-achieved outcomes)

### Layer 3: Adaptive Methodology (Periodic)

**Tool:** The adaptive loop defined in CIA-303

**What it measures:** Should methodology rules change based on observed patterns? Are execution mode defaults correct? Should hook thresholds adjust?

**When it runs:** Periodically, driven by accumulated /insights data.

**Not yet implemented.** Layer 3 depends on structured /insights data extraction (CIA-303). Layers 1 and 2 are independently useful without it.

### How the Layers Connect

```
Layer 1 (Structural)          Layer 2 (Runtime)           Layer 3 (Adaptive)
   cc-plugin-eval                /insights                  Methodology loop
        |                            |                           |
   "Skill X triggers              "Skill X triggered          "Skill X triggers
    for prompt Y"                  in 12/50 sessions"          but sessions using
        |                            |                        it have 40% friction"
        v                            v                           v
   Pre-release gate              Usage report               Rule adjustment
   (CI blocks broken             (dormant skill              (retrigger criteria,
    triggers)                     detection)                  weight changes)
```

Layer 1 answers: "Can it trigger?" Layer 2 answers: "Does it trigger?" Layer 3 answers: "Should it trigger?"

## Practical Integration

### Adding Observability to a New Feature (Checklist)

Before marking a feature's Stage 7 as complete:

1. **Identify verification type** (UI, API, infrastructure) from the section above
2. **Select minimum tooling** based on acceptance criteria types
3. **Collect evidence** using the tool-specific patterns above
4. **Attach evidence to `/sdd:close`** — screenshots, query results, or metric summaries
5. **Record in `.sdd-progress.md`** — which tools were used and what they showed

### Adding Plugin Monitoring to a Release

Before bumping the plugin version:

1. **Run cc-plugin-eval** (Layer 1) — all components must pass structural validation
2. **Review latest /insights report** (Layer 2) — check for newly dormant skills or rising friction
3. **Update skill descriptions** if trigger patterns have drifted from actual usage
4. **Log release metrics** in the release notes: component count, trigger rate, known gaps

## Cross-Skill References

- **quality-scoring** -- Quality score dimensions can incorporate observability evidence (test coverage from Sentry error rates, verification from PostHog activation data)
- **insights-pipeline** -- Archives /insights reports that feed Layer 2 runtime observability
- **ship-state-verification** -- Structural validation (Layer 1) complements file existence checks; together they verify both content and behavior
- **execution-engine** -- Stage 7 verification happens after the execution loop completes; observability tools provide the evidence
- **issue-lifecycle** -- Closure evidence from observability tools feeds the `/sdd:close` protocol
