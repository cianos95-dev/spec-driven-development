# CCC Quick Start

Three commands to go from idea to closed issue:

```
/ccc:go              Pick up next unblocked task, or resume current work
/ccc:go --next       Skip current, grab next task from backlog
/ccc:go --status     Show full project status across all issues
```

## Common Workflows

| Goal | Command |
|------|---------|
| Start working | `/ccc:go` |
| Close an issue | `/close CIA-XXX` |
| Finish a branch | Say "finish branch" or "branch done" |
| Run adversarial review | `/ccc:review` |
| Decompose a large issue | `/ccc:decompose CIA-XXX` |
| Check dependencies | `/ccc:deps CIA-XXX` |
| Post project update | `/ccc:status-update` |

## Lifecycle at a Glance

```
/ccc:go → picks issue → marks In Progress → implements
       → branch-finish (verify + merge/PR)
       → /close (quality gate + closure rules + evidence)
       → Done
```

## Key References

- `references/closure-rules.md` — When to auto-close vs propose vs block
- `references/evidence-mandate.md` — What counts as evidence (and what doesn't)
