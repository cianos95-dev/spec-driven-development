# Milestone Lifecycle

State transitions for CCC milestones, annotated with the skills and commands that trigger each transition.

## State Diagram

```mermaid
stateDiagram-v2
    [*] --> Created: /go (new idea intake)\nmilestone-management

    Created --> Active: First issue assigned\nmilestone-management

    Active --> Complete: All issues Done\n/close + milestone-management
    Active --> Overdue: Target date passed\nresource-freshness detects
    Active --> Carry_Forward: Cycle boundary\nmilestone-management

    Overdue --> Extended: Target date updated\nmilestone-management
    Overdue --> Carry_Forward: Open issues moved\nmilestone-management
    Overdue --> Complete: Remaining issues Done\n/close + milestone-management

    Extended --> Active: New target set
    Extended --> Overdue: New target passed

    Carry_Forward --> Active: Issues in new milestone\nmilestone-management

    Complete --> [*]: Archived\nmilestone-management

    note right of Created
        Triggered by /go (1D) or
        milestone-management skill.
        Auto-assigned if project has
        exactly one active milestone.
    end note

    note right of Overdue
        Detected by resource-freshness
        (Category 3: Milestone Health).
        Flagged as Warning in /hygiene.
    end note

    note right of Carry_Forward
        milestone-management handles
        carry-forward decisions at
        cycle boundaries (weekly).
    end note
```

## Transition Details

| Transition | Trigger | Skill/Command | Detection |
|-----------|---------|--------------|-----------|
| Created | New milestone created | `milestone-management` | Manual or auto via `/go` intake |
| Created -> Active | First issue assigned to milestone | `milestone-management` | Issue assignment event |
| Active -> Complete | All issues reach Done/Canceled | `/close` + `milestone-management` | Last issue closed |
| Active -> Overdue | Target date passes with open issues | `resource-freshness` | Category 3 check in `/hygiene` |
| Active -> Carry-Forward | Cycle boundary with incomplete issues | `milestone-management` | Weekly cycle start |
| Overdue -> Extended | Target date manually updated | `milestone-management` | User action |
| Overdue -> Carry-Forward | Decision to move open issues forward | `milestone-management` | User decision via `/hygiene` |
| Overdue -> Complete | Remaining issues completed | `/close` | All issues resolved |
| Extended -> Active | Returns to active tracking | Automatic | Target date now in future |
| Extended -> Overdue | New target also passes | `resource-freshness` | Category 3 re-check |
| Carry-Forward -> Active | Issues land in new milestone | `milestone-management` | Carry-forward protocol |
| Complete -> Archived | Milestone archived after completion | `milestone-management` | Manual or auto after retention period |

## Health Signals

The `resource-freshness` skill (Category 3: Milestone Health) monitors these signals:

| Signal | Severity | Threshold |
|--------|----------|-----------|
| Target date passed with open issues | Warning | `targetDate < today && openIssues > 0` |
| Due soon with low completion | Warning | Due in 3 days, <50% complete |
| Stalled (zero completion after threshold) | Warning | Issues exist but 0% Done after N days |
| Empty milestone | Info | Milestone has no issues assigned |
| All Done but not marked complete | Info | Target passed, 0 open issues, still active |

## Milestone Forecast Integration

The `milestone-forecast` skill provides predictive analysis:

```mermaid
flowchart LR
    A[Active Milestone] --> B{milestone-forecast}
    B --> C[On Track: current velocity\nprojects completion\nbefore target date]
    B --> D[At Risk: velocity trending\nbelow required pace]
    B --> E[Off Track: completion date\nprojects past target]

    C --> F[No action needed]
    D --> G[Warning in /hygiene]
    E --> H[Escalate: suggest\nextension or carry-forward]
```

## Cross-Skill References

| Skill | Role in Lifecycle |
|-------|------------------|
| `milestone-management` | Primary lifecycle manager — creation, assignment, carry-forward, completion, archival |
| `milestone-forecast` | Predictive analysis — velocity-based date projection, risk scoring |
| `resource-freshness` | Health monitoring — overdue detection, stall detection, empty milestone flagging |
| `issue-lifecycle` | Issue-level state management within milestones |
| `/go` | Entry point — auto-assigns milestones on issue creation (Step 1D) |
| `/hygiene` | Aggregates milestone health findings from resource-freshness and milestone-management |
| `/close` | Triggers milestone completion check when closing the last issue in a milestone |
