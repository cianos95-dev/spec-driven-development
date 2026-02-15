# Structural Validation with cc-plugin-eval

Plugin structural validation ensures that skills, commands, and agents trigger correctly after changes. This reference documents how to integrate [cc-plugin-eval](https://github.com/sjnims/cc-plugin-eval) into the SDD release process.

## What cc-plugin-eval Does

cc-plugin-eval is a 4-stage automated evaluation framework for Claude Code plugins:

| Stage | Name | What It Does |
|-------|------|-------------|
| 1 | **Analysis** | Parses plugin manifest, enumerates all skills/commands/agents, extracts trigger descriptions |
| 2 | **Generation** | Creates synthetic prompts designed to trigger each component based on its description |
| 3 | **Execution** | Runs prompts against the plugin and records which components actually triggered |
| 4 | **Evaluation** | Compares expected triggers vs actual triggers, scores accuracy, detects conflicts |

## Output Metrics

| Metric | Definition | Target |
|--------|-----------|--------|
| **Accuracy** | % of prompts that triggered the correct component | > 90% |
| **Trigger rate** | % of components triggered at least once across all prompts | 100% (no dormant components) |
| **Quality score** | Composite of accuracy, trigger rate, and response quality | > 80/100 |
| **Conflict count** | Number of prompts that triggered multiple conflicting components | 0 |

**Output format:** JUnit XML, compatible with GitHub Actions test reporting.

## CI Gate Configuration

### GitHub Actions Integration

Add to `.github/workflows/plugin-eval.yml`:

```yaml
name: Plugin Structural Validation
on:
  pull_request:
    paths:
      - 'skills/**'
      - 'commands/**'
      - 'agents/**'
      - '.claude-plugin/**'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run cc-plugin-eval
        uses: sjnims/cc-plugin-eval@v1
        with:
          plugin-path: '.'
          output-format: 'junit'
          output-file: 'eval-results.xml'

      - name: Publish Results
        uses: dorny/test-reporter@v1
        if: always()
        with:
          name: Plugin Eval Results
          path: eval-results.xml
          reporter: java-junit

      - name: Check Thresholds
        run: |
          # Parse JUnit XML for pass/fail
          # Fail if accuracy < 90% or any component has 0 triggers
          echo "Threshold check passed"
```

### Release Gate Rules

| Gate | Threshold | Blocks Release? |
|------|-----------|----------------|
| Accuracy below 90% | Hard gate | Yes — skill descriptions need updating |
| Any component with 0 trigger rate | Hard gate | Yes — dormant component must be fixed or removed |
| Conflict count > 0 | Soft gate | Warning — review conflicting descriptions, fix if possible |
| Quality score below 80 | Soft gate | Warning — investigate but does not block |

### When to Run

| Trigger | Scope | Rationale |
|---------|-------|-----------|
| PR touches skills/ | Full eval | Skill description changes can affect trigger accuracy |
| PR touches commands/ | Full eval | Command changes can introduce conflicts |
| PR touches agents/ | Full eval | Agent descriptions interact with skill triggers |
| Pre-release version bump | Full eval + threshold check | Gate check before publishing |
| Manual trigger | Full eval | On-demand validation |

## Interpreting Results

### Low Accuracy (< 90%)

The skill description does not match what prompts actually trigger it. Common causes:

- **Description too generic:** "Use for development tasks" matches too many prompts. Be specific about the skill's unique trigger.
- **Description too narrow:** Exact phrases like "run TDD workflow" miss natural variations. Include synonyms and related phrases.
- **Overlapping descriptions:** Two skills both claim to handle "code review." Differentiate by scope (pre-merge review vs post-merge audit).

### Zero Trigger Rate

A component was never triggered by any synthetic prompt. This means either:

- **Description is ineffective:** The trigger phrases don't match any real user intent. Rewrite.
- **Component is genuinely dormant:** No user scenario maps to it. Consider removal or merging into another skill.
- **Naming conflict:** Another component with a more specific description always wins. Adjust priority or description specificity.

### Conflicts

Multiple components trigger for the same prompt. Resolution:

1. **Check if both triggers are valid** — some prompts legitimately span two skills
2. **If not, sharpen the description** of the less-relevant component to exclude the conflicting prompt pattern
3. **If persistent, consider merging** the conflicting components

## Feeding Back into the Adaptive Loop

Structural validation results feed into the three-layer monitoring stack:

```
cc-plugin-eval results
       |
       v
Layer 1 baseline:
"Component X has 95% accuracy, Y has 72% accuracy"
       |
       v
Compare with Layer 2 (/insights runtime data):
"Component X triggered in 40/50 sessions, Y triggered in 2/50 sessions"
       |
       v
Layer 3 adaptive decision:
"Y has low structural accuracy AND low runtime usage — candidate for removal or rewrite"
```

Without Layer 1, you can't distinguish "low usage because users don't need it" from "low usage because the trigger description is broken." Structural validation provides the baseline that makes runtime data interpretable.
