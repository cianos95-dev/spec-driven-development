# Velocity Math Reference

Detailed calculation methodology for the milestone-forecast skill. This reference covers the weighted rolling velocity formula, worked examples, normalization for fewer cycles, and coefficient of variation calculation.

## Weighted Rolling Velocity — Full Derivation

### Input Data

From Linear's `completedScopeHistory` field on each completed cycle, extract the velocity (points completed) per cycle:

```
velocity[i] = completedScopeHistory[last_day] - completedScopeHistory[first_day]
```

Where `completedScopeHistory` is an array of cumulative completed points, one entry per day of the cycle.

### Weight Table

| Index | Cycle | Weight | Cumulative |
|-------|-------|--------|------------|
| 0 | Most recent | 0.35 | 0.35 |
| 1 | n-1 | 0.25 | 0.60 |
| 2 | n-2 | 0.20 | 0.80 |
| 3 | n-3 | 0.12 | 0.92 |
| 4 | n-4 | 0.08 | 1.00 |

Sum of all weights = 1.00. No normalization needed when all 5 cycles are available.

### Worked Example (5 cycles)

Sample velocity data from 5 completed weekly cycles:

| Cycle | Points Completed | Weight | Weighted Contribution |
|-------|-----------------|--------|-----------------------|
| Cycle 12 (most recent) | 18 | 0.35 | 18 × 0.35 = 6.30 |
| Cycle 11 | 14 | 0.25 | 14 × 0.25 = 3.50 |
| Cycle 10 | 16 | 0.20 | 16 × 0.20 = 3.20 |
| Cycle 9 | 12 | 0.12 | 12 × 0.12 = 1.44 |
| Cycle 8 | 10 | 0.08 | 10 × 0.08 = 0.80 |

**Weighted velocity = 6.30 + 3.50 + 3.20 + 1.44 + 0.80 = 15.24 pts/cycle**

Simple average would be (18+14+16+12+10)/5 = 14.0. The weighted average (15.24) gives more credit to the recent upward trend.

### Date Projection (continued example)

Given:
- Weighted velocity: 15.24 pts/cycle
- Milestone total scope: 45 points
- Completed so far: 20 points
- Remaining: 25 points
- Cycle duration: 7 days
- Today: 2026-02-19

```
cycles_needed = 25 / 15.24 = 1.64 cycles

optimistic_cycles  = 1.64 × 0.60 = 0.98 cycles  →  7 days  → 2026-02-26
expected_cycles    = 1.64 × 1.00 = 1.64 cycles  → 12 days  → 2026-03-03
pessimistic_cycles = 1.64 × 1.40 = 2.30 cycles  → 16 days  → 2026-03-07
```

The ±40% buffer provides a range: optimistic assumes the team speeds up (completes 40% faster), pessimistic assumes slowdown (takes 40% longer).

## Normalization for Fewer Cycles

When fewer than 5 completed cycles are available, take the first N weights and normalize to sum to 1.0.

### 4 Cycles Available

Raw weights: [0.35, 0.25, 0.20, 0.12]
Sum: 0.92
Normalized: [0.35/0.92, 0.25/0.92, 0.20/0.92, 0.12/0.92] = [0.3804, 0.2717, 0.2174, 0.1304]

### 3 Cycles Available

Raw weights: [0.35, 0.25, 0.20]
Sum: 0.80
Normalized: [0.35/0.80, 0.25/0.80, 0.20/0.80] = [0.4375, 0.3125, 0.2500]

### 2 Cycles Available

Raw weights: [0.35, 0.25]
Sum: 0.60
Normalized: [0.35/0.60, 0.25/0.60] = [0.5833, 0.4167]

### 1 Cycle Available

Single cycle: weight = 1.00. Use raw velocity. Always flag Low confidence.

## Coefficient of Variation (CV)

CV measures velocity consistency across cycles. Used to determine forecast confidence.

```
mean = sum(velocities) / n
variance = sum((v - mean)² for v in velocities) / n
std_dev = sqrt(variance)
CV = std_dev / mean
```

### CV Worked Example

Using the 5-cycle velocities: [18, 14, 16, 12, 10]

```
mean = (18 + 14 + 16 + 12 + 10) / 5 = 14.0
variance = ((18-14)² + (14-14)² + (16-14)² + (12-14)² + (10-14)²) / 5
         = (16 + 0 + 4 + 4 + 16) / 5
         = 40 / 5 = 8.0
std_dev = sqrt(8.0) = 2.83
CV = 2.83 / 14.0 = 0.202
```

CV = 0.202 < 0.3 → **High confidence**

### CV Thresholds

| CV Range | Confidence | Interpretation |
|----------|------------|----------------|
| CV < 0.3 | High | Team velocity is consistent. Forecast is reliable. |
| 0.3 ≤ CV < 0.6 | Medium | Moderate variation. Forecast is reasonable but monitor actuals. |
| CV ≥ 0.6 | Low | High variation. Forecast is a rough guide. Investigate causes. |

## Velocity Trend Calculation

Compare most recent cycle velocity to the 3-cycle rolling average:

```
rolling_avg = sum(velocity[0:3]) / 3
ratio = velocity[0] / rolling_avg
```

| Ratio | Trend | Signal |
|-------|-------|--------|
| ratio > 1.10 | Increasing | Team is accelerating |
| 0.90 ≤ ratio ≤ 1.10 | Stable | Consistent delivery |
| ratio < 0.90 | Decreasing | Team is slowing down |

### Trend Example

Velocities: [18, 14, 16, 12, 10] (most recent first)

```
rolling_avg = (18 + 14 + 16) / 3 = 16.0
ratio = 18 / 16.0 = 1.125
```

1.125 > 1.10 → **Increasing** trend

## Scope Change Detection

When forecasting, also check if the milestone's total scope has changed since the last forecast. If `scopeHistory` shows scope additions mid-milestone:

```
scope_change = scopeHistory[latest] - scopeHistory[earliest]
```

If scope_change > 0, note in the output: "Scope increased by [N] points since milestone start." This helps users understand why projected dates may have shifted despite consistent velocity.

## Calendar Conversion

Convert fractional cycles to calendar dates:

```
days = cycles_needed × cycle_duration_days
projected_date = today + timedelta(days=ceil(days))
```

Always round up (ceil) to avoid projecting completion on a partial day. Use the team's actual cycle duration from Linear (typically 7 days for weekly sprints, 14 for biweekly).

### Weekend/Holiday Awareness

The basic projection uses calendar days. For teams wanting business-day awareness, note that Linear cycles run on calendar time (7-day weeks), so the projection naturally accounts for weekends already embedded in historical velocity data. Teams that don't work weekends will have lower velocity figures that already reflect the reduced working days.
