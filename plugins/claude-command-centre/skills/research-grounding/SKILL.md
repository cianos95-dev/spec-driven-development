---
name: research-grounding
description: |
  Research readiness progression for issues that require academic evidence. Defines the
  needs-grounding to expert-reviewed label hierarchy, grounding requirements for PR/FAQ specs,
  and citation standards for research-heavy features.
  Use when writing specs for research-backed features, evaluating research readiness of issues,
  deciding whether an issue needs literature review, or ensuring PR/FAQs have adequate citations.
  Trigger with phrases like "is this grounded", "needs literature review", "research readiness",
  "add citations to spec", "research labels", "grounding requirements", "methodology validation".
---

# Research Grounding

Research-backed features require evidence. This skill defines the progression from ungrounded claims to expert-reviewed methodology, and the citation standards that specs must meet.

## Research Readiness Labels

Issues that make claims requiring evidence progress through four stages:

| Label | State | Transition Criteria |
|-------|-------|-------------------|
| `research:needs-grounding` | Claims made without evidence | Default for any issue referencing psychological constructs, measurement instruments, or statistical methods |
| `research:literature-mapped` | Evidence gathered | 3+ peer-reviewed papers cited in the issue description or linked spec |
| `research:methodology-validated` | Methods documented | Instruments identified, statistical approaches documented, sample size justified |
| `research:expert-reviewed` | Human sign-off | A domain expert (human) has reviewed and approved the methodology |

### Transition Rules

**needs-grounding to literature-mapped:**
- Minimum 3 peer-reviewed papers cited
- Citations include DOI or stable URL
- Papers are relevant (not tangential padding)
- Literature covers the core construct being measured/used

**literature-mapped to methodology-validated:**
- Measurement instruments identified with psychometric properties (reliability, validity)
- Statistical approach documented (test type, assumptions, effect size expectations)
- Sample size justified (power analysis or precedent from cited studies)
- Limitations acknowledged

**methodology-validated to expert-reviewed:**
- Human decision always. Agent cannot auto-transition.
- Domain expert reviews the methodology section
- Sign-off documented as a comment on the issue

## PR/FAQ Research Base Requirements

When writing PR/FAQs for research-backed features (using `template:prfaq-research`):

### Minimum Citation Standards

| Section | Requirement |
|---------|-------------|
| Problem Statement | 1+ citation establishing the problem exists |
| Solution | 2+ citations supporting the approach |
| Research Base | 3+ citations total, including at least 1 meta-analysis or systematic review if available |
| Methodology | Instrument citations with psychometric properties |
| Pre-Mortem | 1+ citation per identified risk where applicable |

### Citation Format

In PR/FAQ documents, use inline citations with DOI:

```markdown
Limerence has been associated with attachment anxiety (Wakin & Vo, 2008; DOI:10.1080/00224490802400129)
and shows overlap with obsessive-compulsive symptomatology (Willmott & Bentley, 2015; DOI:10.1556/2006.4.2015.028).
```

### Discovery Workflow

When populating the Research Base section:

1. **Semantic Scholar** `search_papers` for focused keyword search with citation count filter
2. **OpenAlex** `get_top_cited_works` for foundational/seminal papers
3. **arXiv** `search_papers` for recent preprints (especially CS/ML methodology)
4. **Zotero** `zotero_semantic_search` to check if papers already in library
5. **Cross-reference** citation counts and recency to select the strongest evidence

## Grounding Assessment Checklist

When evaluating whether an issue needs the `research:needs-grounding` label:

- [ ] Does the issue reference a psychological construct (e.g., limerence, attachment, personality)?
- [ ] Does the issue propose measuring something (surveys, scales, instruments)?
- [ ] Does the issue make causal claims ("X causes Y", "X improves Y")?
- [ ] Does the issue reference statistical methods?
- [ ] Does the issue design an intervention or therapeutic approach?

**If any checkbox is yes**, the issue needs the `research:needs-grounding` label.

## When NOT to Apply

Research grounding is for issues that make empirical claims. It does NOT apply to:

- Infrastructure issues (`Configure Supabase`, `Set up CI/CD`)
- UI issues without empirical claims (`Build settings page`, `Add dark mode`)
- Pure engineering decisions (`Choose React over Vue`, `Use PostgreSQL`)
- Administrative tasks (`Update README`, `Clean up labels`)

## Integration with Other Skills

- **prfaq-methodology**: Research Base section in PR/FAQ templates uses these citation standards
- **adversarial-review**: Reviewers check research grounding during spec review
- **issue-lifecycle**: Research labels coexist with other label types (spec, exec, type)
- **research-pipeline**: The pipeline skill handles the mechanics of finding papers; this skill handles the standards they must meet
