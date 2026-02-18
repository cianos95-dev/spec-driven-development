# PR/FAQ: Research Template

> **Use for:** Features requiring literature grounding (psychology, education, methodology, science)
> **Label:** `template:prfaq-research`
> **Formality:** Full + mandatory research sections
> **Note:** Extends the feature template with research-specific sections. Use when `research:needs-grounding` label applies.

---

```yaml
---
linear: ~~PREFIX-XXX
exec: tdd|pair|checkpoint
status: draft
created: YYYY-MM-DDTHH:mm:ssZ
updated: YYYY-MM-DDTHH:mm:ssZ
research: needs-grounding
---
```

# [Research Feature Name]

## Press Release

**[Feature Name]: [One-sentence benefit grounded in research finding]**

*[Target timeframe]*

**Summary:** [2-4 sentences. What is this? Ground the benefit in specific research findings, not just intuition.]

**Problem:** [2-4 sentences. What gap exists in current tools or understanding? Cite the research that identifies this gap. Do NOT mention the solution here.]

**Solution:** [2-4 sentences. How does this feature operationalise the research findings into a user-facing capability?]

**Researcher Quote:** "[Why this research translation matters. What new capability does this unlock for practitioners or participants?]" -- [Role]

**Getting Started:** [1-3 sentences. How does a user begin?]

**Practitioner Quote:** "[Hypothetical testimonial from a practitioner or research participant. What outcome do they value?]" -- [Persona name, role]

---

## FAQ

### External (User-Facing)

**Q1: What research is this based on?**
[Plain-language summary of theoretical basis -- no jargon]

**Q2: How has this been validated?**
[Study design, sample sizes, effect sizes if available]

**Q3: What are the limitations of the underlying research?**
[Honest limitations -- generalisability, sample characteristics, methodology constraints]

**Q4: How does it work for me?**
[User experience description]

**Q5: What data is collected and why?**
[Research ethics, data handling, consent, anonymisation]

### Internal (Technical/Research)

**Q6: What is the theoretical framework?**
[Formal framework name and key constructs, with citations]

**Q7: What instruments/measures are used?**
[Validated instruments, psychometric properties (reliability, validity)]

**Q8: What are the statistical methods?**
[Analysis plan, power calculations, sample requirements]

**Q9: What ethical considerations apply?**
[IRB/ethics board requirements, informed consent protocol, data protection]

**Q10: How does this advance the research agenda?**
[Contribution to field, publication potential, replication value]

**Q11: Why build this now?**
[Research timing, data availability, strategic alignment]

**Q12: What are the key risks?**
[Technical, methodological, and adoption risks with mitigations]

---

## Research Base (Mandatory)

> **Minimum:** 3+ Evidence Objects required. At least 1 must be `type: empirical`. See `research-grounding` skill for full format specification.

### Theoretical Framework

[2-3 paragraph description of the theoretical foundation. Name the framework, key constructs, seminal authors, and how it applies to this feature.]

### Evidence Objects

```
[EV-001] Type: empirical | theoretical | methodological
Source: Author (Year). Title. Journal. DOI:xxx
Claim: "Specific factual claim supported by this source"
Confidence: high | medium | low
```

```
[EV-002] Type: empirical | theoretical | methodological
Source: Author (Year). Title. Journal. DOI:xxx
Claim: "Specific factual claim supported by this source"
Confidence: high | medium | low
```

```
[EV-003] Type: empirical | theoretical | methodological
Source: Author (Year). Title. Journal. DOI:xxx
Claim: "Specific factual claim supported by this source"
Confidence: high | medium | low
```

[Add more Evidence Objects as needed. Reference inline as [EV-001], [EV-002], etc.]

### Methodological Notes

- **Instruments:** [Validated instruments to be used, with published psychometric properties]
- **Statistical approach:** [Planned analyses -- e.g., mixed-effects models, Bayesian estimation]
- **Sample requirements:** [Minimum N based on power analysis, inclusion/exclusion criteria]
- **Effect sizes:** [Expected effect sizes based on prior literature, with references]

---

## Pre-Mortem

_Imagine it is 6 months after launch and this research feature has failed. What went wrong?_

| Failure Mode | Likelihood | Impact | Mitigation |
|-------------|-----------|--------|------------|
| Research basis invalidated by new findings | Med | High | Monitor literature; flag if contradicted |
| Instrument validity concerns in target population | Low | High | Use only validated instruments; pilot test with N>=10 |
| Sample recruitment failure | Med | Med | Multiple recruitment channels; conservative power estimates |
| [Feature-specific failure] | H/M/L | H/M/L | [Mitigation] |

---

## Inversion Analysis

_How would we guarantee this research feature fails?_

1. [e.g., "Ignore the validated instrument and build our own unvalidated measure"]
2. [e.g., "Skip the pilot study and go straight to full deployment"]
3. [e.g., "Assume our sample generalises to all populations without testing"]

_Therefore, we must ensure:_

1. [Concrete action derived from inverting anti-pattern 1]
2. [Concrete action derived from inverting anti-pattern 2]
3. [Concrete action derived from inverting anti-pattern 3]

---

## Acceptance Criteria

- [ ] Research base section contains 3+ Evidence Objects with IDs, types, sources, claims, and confidence levels
- [ ] At least 1 Evidence Object is `type: empirical`
- [ ] Instruments are validated (published psychometric properties referenced)
- [ ] Statistical methods documented with power analysis
- [ ] Ethical considerations addressed (consent, data protection)
- [ ] [Feature-specific criterion]
- [ ] [Feature-specific criterion]

## Non-Goals (Mandatory)

> **Why this section exists:** Research features attract suggestions for comprehensive measurement systems, enterprise analytics, and multi-population generalization. Constrain the scope explicitly.

**Scale:** [personal | team | enterprise]

**This feature deliberately does NOT:**

- [Explicit exclusion 1 -- what populations/contexts are out of scope]
- [Explicit exclusion 2 -- what measurement complexity is beyond scope]
- [Explicit exclusion 3 -- what scale of data collection/analysis is excluded]

**MCP-first check:** [What existing MCP/plugin/tool overlaps with this? If none, state "No overlap found."]
