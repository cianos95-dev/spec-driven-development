# PR/FAQ: Feature Template

> **Use for:** Customer-facing product features
> **Label:** `template:prfaq-feature`
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

# [Feature Name]

## Press Release

**[Feature Name]: [One-sentence benefit for target user]**

*[Target launch timeframe]*

**Summary:** [2-4 sentences. What is this? Who is it for? What does it enable them to do that they could not do before?]

**Problem:** [2-4 sentences. What customer pain exists today? Be specific -- name the user type and the concrete frustration. Do NOT mention the solution here.]

**Solution:** [2-4 sentences. How does this feature address the problem? Focus on the user experience, not technical implementation.]

**Spokesperson Quote:** "[Why this matters to us. What gap in our mission does this fill? Why now?]" -- [Role]

**Getting Started:** [1-3 sentences. How does a user begin using this? What is the first action they take?]

**Customer Quote:** "[Hypothetical testimonial from the target user persona. What specific outcome delights them?]" -- [Persona name, role]

**Next Step:** [Call to action. What should an interested user do?]

---

## FAQ

### External (Customer-Facing)

**Q1: Who is this for?**
[Specific user persona(s) and their context]

**Q2: How does it work?**
[User-facing explanation, no jargon]

**Q3: What do I need to get started?**
[Prerequisites, onboarding steps]

**Q4: What are the limitations?**
[Honest constraints -- what this does NOT do]

**Q5: How is my data handled?**
[Privacy, security, data ownership]

**Q6: What happens if [common edge case]?**
[Graceful degradation, error handling from user perspective]

### Internal (Business/Technical)

**Q7: Why build this now?**
[Market timing, user signal, strategic alignment]

**Q8: What resources does this require?**
[Effort estimate, dependencies, timeline]

**Q9: What are the key risks?**
[Technical, market, adoption risks with mitigations]

**Q10: How will we measure success?**
[Specific metrics with targets, e.g., "DAU increases 20% within 30 days"]

**Q11: What alternatives did we consider?**
[Buy vs build, different approaches, why this one]

**Q12: What is the research basis?**
[Citations, literature references, evidence grounding]

---

## Pre-Mortem

_Imagine it is 6 months after launch and this feature has failed. What went wrong?_

| Failure Mode | Likelihood | Impact | Mitigation |
|-------------|-----------|--------|------------|
| [Specific failure scenario] | High/Med/Low | High/Med/Low | [Concrete preventive action] |
| [Another failure scenario] | High/Med/Low | High/Med/Low | [Concrete preventive action] |
| [Third failure scenario] | High/Med/Low | High/Med/Low | [Concrete preventive action] |

---

## Inversion Analysis

_How would we guarantee this feature fails?_

1. [Anti-pattern that guarantees failure]
2. [Another guaranteed failure mode]
3. [Third guaranteed failure mode]

_Therefore, we must ensure:_

1. [Opposite of anti-pattern 1 -- concrete design principle]
2. [Opposite of anti-pattern 2 -- concrete design principle]
3. [Opposite of anti-pattern 3 -- concrete design principle]

---

## Acceptance Criteria

- [ ] [Specific, testable criterion derived from PR/FAQ]
- [ ] [Another criterion]
- [ ] [Another criterion]

## Non-Goals (Mandatory)

> **Why this section exists:** Without explicit Non-Goals, adversarial reviewers and models consistently suggest production-grade solutions for personal-scale tools. This section sets the constraint boundary.

**Scale:** [personal | team | enterprise]

**This feature deliberately does NOT:**

- [Explicit exclusion 1 -- what this feature will NOT do, with rationale]
- [Explicit exclusion 2 -- what related capability is out of scope]
- [Explicit exclusion 3 -- what scale/complexity level is beyond scope]

**MCP-first check:** [What existing MCP/plugin/tool overlaps with this? If none, state "No overlap found."]
