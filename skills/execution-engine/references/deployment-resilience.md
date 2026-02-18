# Deployment Resilience Protocol

Clarifies the `[DEPLOYMENT]` CLAUDE.md rule for deployment-specific retry behavior within the execution engine.

## Retry Budget

**2 failed attempts means 2 failed approaches total, not 2 per strategy.**

Available deployment approaches (CLI, config-based, API, platform dashboard) are a menu of options, not a sequential chain. Pick one; if it fails, pick a different one. After 2 total failures, escalate.

Do not cycle through all available strategies. The budget is 2 total, regardless of how many options exist.

## Health-Check Confirmation

Confirm deployment success using the platform's native verification:

1. Deploy command exits 0, **AND**
2. Platform status check returns healthy

Do NOT rely solely on HTTP 200 from a preview URL — error pages can return 200. Use the platform's own status or health endpoint to confirm the deployment is serving correctly.

## Escalation

After 2 failed approaches:

- **Inside the execution loop:** Signal `REPLAN` with both failure reports documented in `.ccc-progress.md` under Learnings.
- **Outside the loop:** Surface to the human with both failure reports and ask for direction before attempting a third approach.

## Per-Project Extension Point

Project-specific deployment approaches and health-check commands should be documented in the project's `CLAUDE.md` or `.ccc-agents.md`, not in this reference. This protocol defines the budget and escalation rules; projects define the concrete commands.
