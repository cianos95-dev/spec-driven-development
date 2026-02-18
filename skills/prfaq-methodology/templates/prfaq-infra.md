# PR/FAQ: Infrastructure Template

> **Use for:** Internal infrastructure changes (tooling, MCP config, CI/CD, automation)
> **Label:** `template:prfaq-infra`
> **Formality:** Full

---

```yaml
---
linear: ~~PREFIX-XXX
exec: quick|tdd|pair|checkpoint|swarm|spike
status: draft
created: YYYY-MM-DDTHH:mm:ssZ
updated: YYYY-MM-DDTHH:mm:ssZ
---
```

# [Infrastructure Change Name]

## Internal Press Release

**[Change Name]: [One-sentence benefit for developer/agent workflow]**

*[Target completion timeframe]*

**Summary:** [2-4 sentences. What changes? What capability does it unlock or risk does it mitigate?]

**Problem:** [2-4 sentences. What friction, risk, or inefficiency exists today? Describe the concrete pain in the current workflow. Do NOT mention the solution here.]

**Solution:** [2-4 sentences. How does this change address the problem? What does the workflow look like after?]

**Before / After:**

| Aspect | Before | After |
|--------|--------|-------|
| [Workflow step or metric] | [Current state] | [Target state] |
| [Another aspect] | [Current state] | [Target state] |
| [Another aspect] | [Current state] | [Target state] |

---

## FAQ

### Operational

**Q1: What breaks if we do NOT do this?**
[Concrete risk of inaction -- what degrades, what fails, what gets harder over time]

**Q2: What breaks if we do this wrong?**
[Blast radius -- what systems are affected, how badly, for how long]

**Q3: What is the rollback plan?**
[Step-by-step rollback procedure. If not rollback-able, state that explicitly and explain why the risk is acceptable.]

**Q4: How do we verify success?**
[Specific verification commands, checks, or observable outcomes]

### Technical

**Q5: What systems are affected?**
[List of systems, configs, services, dependencies]

**Q6: What is the migration path?**
[Step-by-step with checkpoints. If no migration needed, state why.]

**Q7: What are the dependencies?**
[Ordered list of prerequisites that must be in place first]

**Q8: What is the effort estimate?**
[Time estimate with basis -- e.g., "~2 hours based on similar past work"]

---

## Pre-Mortem

_Imagine this change was deployed and something went wrong. What happened?_

| Failure Mode | Likelihood | Impact | Mitigation |
|-------------|-----------|--------|------------|
| [Failure scenario] | High/Med/Low | High/Med/Low | [Mitigation] |
| [Failure scenario] | High/Med/Low | High/Med/Low | [Mitigation] |
| [Failure scenario] | High/Med/Low | High/Med/Low | [Mitigation] |

---

## Acceptance Criteria

- [ ] [Verifiable criterion -- specific command or check]
- [ ] [Verifiable criterion]
- [ ] Rollback procedure documented and tested

## Non-Goals (Mandatory)

> **Why this section exists:** Infrastructure specs are especially prone to scope creep from models suggesting enterprise patterns for personal workflows. This section prevents over-engineering.

**Scale:** [personal | team | enterprise]

**This change deliberately does NOT:**

- [Explicit exclusion 1 -- what infrastructure scope is out of bounds]
- [Explicit exclusion 2 -- what adjacent system is NOT touched]

**MCP-first check:** [What existing MCP/plugin/tool overlaps with this? If none, state "No overlap found."]
