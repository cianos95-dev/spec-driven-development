---
name: milestone-forecast
description: |
  Velocity-based milestone completion date projection using Linear cycle history.
  This skill should be used when the user asks to "forecast milestone completion",
  "predict when milestone finishes", "project milestone dates", "estimate milestone timeline",
  "milestone velocity report", "when will this milestone be done", "milestone ETA",
  or mentions velocity-based date projection for Linear milestones.
---

# Milestone Forecast

Project milestone completion dates using weighted rolling velocity from Linear cycle history. Produces optimistic, expected, and pessimistic date estimates with confidence levels, formatted as markdown tables suitable for Linear comments.

## When to Use

- Before sprint planning, to set realistic milestone target dates
- During session-exit, when milestone health shows "At Risk" or "Overdue"
- On demand, when the user asks for a milestone ETA or completion forecast
- In status updates, to provide data-driven delivery projections

## Data Source

Query Linear's `Cycle.completedScopeHistory` for the last 3-5 completed cycles in the target team. This field returns an array of daily scope snapshots per cycle, from which completed points per cycle can be derived.

### Fetching Cycle Data

Use the Linear GraphQL API (via MCP or direct query) to retrieve cycle velocity:

```graphql
query CycleVelocity($teamId: String!) {
  team(id: $teamId) {
    cycles(
      filter: { isCompleted: { eq: true } }
      orderBy: { endsAt: "DESC" }
      first: 5
    ) {
      nodes {
        number
        startsAt
        endsAt
        completedScopeHistory
        scopeHistory
      }
    }
  }
}
```

For each cycle, derive velocity as: `completedScopeHistory[last] - completedScopeHistory[first]` — the total points completed during that cycle.

If fewer than 3 completed cycles exist, warn the user that the forecast has low confidence and fall back to the available data.

## Weighted Rolling Velocity

Calculate velocity as a weighted average of the last 3-5 cycles, giving more weight to recent performance.

### Weight Distribution

| Cycle Position | Weight | Rationale |
|---------------|--------|-----------|
| Most recent (n) | 0.35 | Strongest signal for current capacity |
| n-1 | 0.25 | Recent but allows for anomalies |
| n-2 | 0.20 | Baseline confirmation |
| n-3 | 0.12 | Historical context |
| n-4 | 0.08 | Long-term trend anchor |

When fewer than 5 cycles are available, redistribute weights proportionally across available cycles. For example, with 3 cycles: normalize [0.35, 0.25, 0.20] to sum to 1.0 → [0.4375, 0.3125, 0.25].

### Formula

```
weighted_velocity = sum(weight[i] * velocity[i] for i in range(n_cycles))
```

Where `velocity[i]` is the points completed in cycle `i`, and `weight[i]` is drawn from the table above (normalized if fewer than 5 cycles).

> See **`references/velocity-math.md`** for the full worked example with sample data and edge case handling.

## Date Projection

Given the weighted velocity and remaining points in the milestone, project completion across three scenarios using a ±40% buffer:

```
remaining_points = total_scope - completed_points
cycles_needed = remaining_points / weighted_velocity

optimistic_cycles = cycles_needed * 0.60    (40% faster than expected)
expected_cycles   = cycles_needed * 1.00    (at current velocity)
pessimistic_cycles = cycles_needed * 1.40   (40% slower than expected)
```

Convert cycles to calendar dates using the team's cycle duration (typically 7 days).

### Confidence Levels

Assign a confidence level based on data quality:

| Condition | Confidence | Label |
|-----------|------------|-------|
| 5 cycles, low variance (CV < 0.3) | High | Stable velocity, reliable forecast |
| 3-4 cycles, moderate variance (CV 0.3-0.6) | Medium | Reasonable estimate, monitor closely |
| < 3 cycles or high variance (CV > 0.6) | Low | Insufficient data, treat as rough guide |

CV = coefficient of variation = standard deviation / mean of cycle velocities.

## Output Format

Format the forecast as a markdown table for Linear milestone comments:

```markdown
### Milestone Forecast — [Milestone Name]

**Velocity:** [weighted_velocity] pts/cycle (based on [N] cycles)
**Remaining:** [remaining] of [total] points ([completed] done)
**Confidence:** [High/Medium/Low] — [rationale]

| Scenario | Cycles | Projected Date | Buffer |
|----------|--------|---------------|--------|
| Optimistic | [n] | [YYYY-MM-DD] | -40% |
| Expected | [n] | [YYYY-MM-DD] | baseline |
| Pessimistic | [n] | [YYYY-MM-DD] | +40% |

*Forecast generated [YYYY-MM-DD] from [N] completed cycles.*
*Velocity trend: [increasing/stable/decreasing] over last [N] cycles.*
```

### Velocity Trend Detection

Compare the most recent cycle velocity to the 3-cycle rolling average:

- **Increasing**: Recent velocity > rolling average * 1.10
- **Stable**: Within ±10% of rolling average
- **Decreasing**: Recent velocity < rolling average * 0.90

Include the trend in the output to help users contextualize the forecast.

## Edge Cases

| Scenario | Handling |
|----------|----------|
| Zero remaining points | Report "Milestone complete — no forecast needed" |
| Zero velocity (all cycles had 0 completions) | Report "Cannot forecast — no velocity data. Check if estimation is enabled." |
| Single cycle available | Use raw velocity with Low confidence, note "only 1 cycle of history" |
| Milestone has no scope (0 total points) | Report "Milestone has no estimated scope — cannot forecast" |
| Cycle in progress (not completed) | Exclude from velocity calculation. Only use completed cycles. |

## Integration Points

- **milestone-management** skill — Provides milestone health data. This skill adds date projections on top of health status.
- **session-exit** skill — Forecast tables can be included in session summary when milestones are At Risk.
- **project-status-update** skill — Forecasts feed into weekly status reports.
- **planning-preflight** skill — Step 3b (Zoom Out) can consume forecast data for capacity planning.

## DO NOT Patterns

- **DO NOT** include in-progress cycles in velocity calculation. Only completed cycles provide reliable velocity data.
- **DO NOT** forecast with zero velocity. Report the issue instead of projecting infinity.
- **DO NOT** auto-update milestone target dates based on forecasts. Forecasts are advisory — date changes require human decision.
- **DO NOT** use `scopeHistory` alone. Always pair with `completedScopeHistory` to calculate actual completion velocity.

## Cross-Skill References

- **milestone-management** skill — Owns milestone CRUD and health reporting. This skill extends it with date projections.
- **session-exit** skill — May include forecast in session summary tables.
- **project-status-update** skill — Consumes forecast data for weekly reporting.
- **planning-preflight** skill — Reads forecast for capacity planning context.
