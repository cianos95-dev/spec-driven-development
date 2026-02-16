# Companion Plugins

Claude Command Centre (CCC) is an **orchestration hub** -- it teaches the agent how to work through specs, reviews, multi-agent routing, and implementation. It deliberately does not cover code-level execution patterns, domain-specific best practices, or tactical development operations. The plugins below fill those gaps.

None of these are required. CCC works standalone. But each one extends a specific part of the funnel.

## Recommended Companions

### Process & Workflow

| Plugin | Marketplace | What It Adds to CCC | Install |
|--------|-------------|---------------------|---------|
| **superpowers** | superpowers-marketplace | Git worktrees, parallel agent dispatch, systematic debugging, brainstorming, code review request/response discipline | `claude plugins add superpowers@superpowers-marketplace` |
| **code-operations-skills** | mhattingpete-claude-skills | Bulk code execution, cross-file refactoring, file operations | `claude plugins add code-operations-skills@mhattingpete-claude-skills` |

### Domain Knowledge

| Plugin | Marketplace | What It Adds to CCC | Install |
|--------|-------------|---------------------|---------|
| **developer-essentials** | claude-code-workflows | Auth patterns, monorepo management, SQL optimization, e2e testing, debugging strategies | `claude plugins add developer-essentials@claude-code-workflows` |
| **backend-development** | claude-code-workflows | API design principles, microservices patterns, event sourcing, CQRS, saga orchestration | `claude plugins add backend-development@claude-code-workflows` |
| **python-development** | claude-code-workflows | Async patterns, testing strategies, packaging with uv, performance optimization | `claude plugins add python-development@claude-code-workflows` |

### Output & Documentation

| Plugin | Marketplace | What It Adds to CCC | Install |
|--------|-------------|---------------------|---------|
| **visual-documentation-skills** | mhattingpete-claude-skills | SVG architecture diagrams, flowcharts, timelines, dashboards | `claude plugins add visual-documentation-skills@mhattingpete-claude-skills` |
| **context7-plugin** | context7-marketplace | Up-to-date library documentation lookup during implementation | `claude plugins add context7-plugin@context7-marketplace` |

### SaaS Integration Packs

| Plugin | Marketplace | What It Adds to CCC | Install |
|--------|-------------|---------------------|---------|
| **supabase-pack** | claude-code-plugins-plus | Supabase schema design, RLS policies, migration patterns, debugging | `claude plugins add supabase-pack@claude-code-plugins-plus` |
| **vercel-pack** | claude-code-plugins-plus | Vercel deployment patterns, edge functions, performance tuning | `claude plugins add vercel-pack@claude-code-plugins-plus` |

### Meta

| Plugin | Marketplace | What It Adds to CCC | Install |
|--------|-------------|---------------------|---------|
| **plugin-dev** | claude-plugins-official | Plugin authoring: skill/command/hook/agent development guides | `claude plugins add plugin-dev@claude-plugins-official` |

## How Companions Fit the Funnel

```
Stage 0-2: Ideation & Analytics
  └── (CCC covers this)

Stage 3: PR/FAQ Draft
  └── superpowers:brainstorming → feeds divergent ideas INTO /sdd:write-prfaq

Stage 4: Adversarial Review
  └── (CCC covers this -- spec-level review)

Stage 5: Visual Prototype
  └── visual-documentation-skills → architecture diagrams, flowcharts

Stage 6: Implementation
  ├── superpowers:systematic-debugging → root cause methodology when stuck
  ├── superpowers:requesting-code-review → dispatch PR-level reviews
  ├── superpowers:receiving-code-review → respond to reviewer feedback
  ├── developer-essentials:code-review-excellence → conduct PR reviews
  ├── developer-essentials → auth, SQL, testing patterns
  ├── backend-development → API design, microservices
  ├── python-development → async, testing, packaging
  ├── code-operations-skills → bulk refactoring, file ops
  ├── context7-plugin → library documentation lookup
  ├── supabase-pack → database patterns
  └── vercel-pack → deployment patterns

Stage 7: Verification
  └── (CCC covers this -- quality scoring, evidence-based closure)
```

## Tier 3 Overlap Evaluation

These external skills partially overlap with CCC capabilities. We evaluated whether CCC needs its own custom version of each.

| External Skill | CCC Parallel | Decision | Rationale |
|----------------|-------------|----------|-----------|
| superpowers:`systematic-debugging` | execution-engine | **Companion** | CCC's execution-engine handles task loop orchestration (state machine, retries, context resets). Systematic-debugging handles root cause investigation (reproduce, pattern, hypothesis, implement). Different abstraction layers -- no conflict, no redundancy. |
| superpowers:`brainstorming` | prfaq-methodology | **Companion** | Brainstorming is pre-spec divergent exploration (ideas to design doc). PR/FAQ is post-idea convergent specification (press release to acceptance criteria). Sequential, not competing -- brainstorming feeds into `/sdd:write-prfaq`. |
| superpowers:`requesting-code-review` | adversarial-review | **Companion** | CCC adversarial-review is spec-level stress testing (Stage 4, before implementation). requesting-code-review is PR-level review dispatch (Stage 6, during implementation). Different funnel stages, complementary concerns. |
| superpowers:`receiving-code-review` | (none) | **Companion** | No CCC skill covers responding to reviewer feedback. This skill teaches verify-before-implement discipline and YAGNI pushback. Generic process skill that doesn't need CCC-specific framing. |
| developer-essentials:`code-review-excellence` | adversarial-review | **Companion** | code-review-excellence teaches PR review technique (severity labels, time-boxing, language-specific checklists). CCC adversarial-review is multi-perspective spec stress testing. Different targets (code vs specs), different methodology. |

**Summary:** All 5 evaluated as companions. CCC operates at the spec/methodology layer; these skills operate at the code/process layer. They complement rather than conflict.
