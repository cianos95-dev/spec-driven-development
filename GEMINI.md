# Gemini Instructions - Claude Command Centre

Claude Code plugin repo. YAML/Markdown content files, no TypeScript.

## Key Rules

- Branch protection on `main` — PR + squash merge only
- Run `bash tests/test-static-quality.sh` before completion
- One PR per Linear issue (CIA-XXX)
- Check existing 39 skills before creating new ones

## Session Feedback (Required)

Before ending any session on a Linear issue, post a structured comment:

```
## Session Report: Gemini CLI (gemini-2.5-pro)

### What was done
- [Deliverables]

### Decisions made
- [Choices with reasoning]

### Blockers found
- [Issues or "None"]

### Next steps
- [Remaining work]
```

Post via: `curl -X POST http://localhost:5679/linear-update -H 'Content-Type: application/json' -d '{"issueId":"CIA-XXX","body":"..."}'`

## Structure

agents/ commands/ skills/ hooks/ styles/ — all YAML/Markdown
.claude-plugin/plugin.json — plugin manifest (valid JSON required)
