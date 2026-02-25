# 3-Tier Memory Extension (Loki-Inspired)

**Status:** Spike / design draft  
**Source:** Loki Mode episodic/semantic/procedural memory, adapted for CCC plugin constraints.

## Compatibility with CCC Plugin

CCC is a Claude Code plugin. It cannot ship a separate runtime or persistent daemon. All memory must be file-based and consumed by the agent during sessions. This constraint shapes the design.

### What CCC Has Today

| Tier | Loki | CCC Current |
|------|------|-------------|
| **Working** | CONTINUITY.md (session state) | .ccc-progress.md (Completed Tasks, Learnings, Current Task) |
| **Episodic** | .loki/memory/episodic/*.json (per-task traces) | .ccc-progress.md per-issue (single file, append-only) |
| **Semantic** | .loki/memory/semantic/patterns.json, anti-patterns.json | None |
| **Procedural** | .loki/memory/skills/ (extracted procedures) | None |
| **Connectors** | — | Linear, GitHub as external state (not memory) |

### Extension Approach (Plugin-Compatible)

**1. Episodic — Extend .ccc-progress.md**

- Add structured per-task blocks with: taskId, duration, commit, learnings[]
- Optionally: .ccc/memory/episodic/{issue-id}.json for richer traces (one file per issue)
- Load at session start when resuming an issue; append on task completion

**2. Semantic — .ccc/memory/semantic/**

- `patterns.json` — validated patterns (e.g. "prefer X over Y for Z")
- `anti-patterns.json` — known failure modes (e.g. "never do X because Y")
- Populated by: debugging-methodology on successful root-cause, tdd-enforcement on refactor patterns, adversarial-review on recurring findings
- Load during planning-preflight or before implementation tasks

**3. Procedural — .ccc/solutions/**

- `{category}/{slug}.md` — extracted solutions with YAML frontmatter (title, tags, symptoms, root_cause, prevention)
- Populated by: debugging-methodology when a bug is fixed; tdd-enforcement when a refactor pattern is reused
- Load on retrieval: "similar problem" → load relevant solutions

### Progressive Disclosure (Loki Pattern)

Loki loads memory in layers to reduce token usage:
- Index (~100 tokens) → Timeline (~500 tokens) → Full details on demand

**CCC adaptation:**
- Index: .ccc/memory/index.json — { "episodic": count, "semantic": count, "solutions": count }
- Timeline: Last N task completions, last N learnings
- Full: Load specific episodic/semantic/solution file when needed

### Plugin Constraints

- No background process: consolidation (episodic → semantic) runs during session, not async
- No vector search unless user adds sentence-transformers: retrieval is file-based, tag/keyword
- Gitignore: .ccc/memory/ and .ccc/solutions/ (project-local, not committed)
- Optional: Add .ccc/memory/ to .gitignore in CCC plugin defaults

### Integration Points

| Skill | Writes | Reads |
|-------|--------|-------|
| execution-engine | episodic (on TASK_COMPLETE) | episodic (on resume) |
| debugging-methodology | solutions/ (on successful fix) | solutions/ (on similar symptom) |
| tdd-enforcement | patterns (on refactor) | patterns (before RED) |
| drift-prevention | — | episodic + semantic (on anchor) |
| planning-preflight | — | semantic (before spec) |

## Spike Deliverables

1. Schema for .ccc/memory/ structure
2. Update debugging-methodology to write solutions/
3. Update execution-engine to write episodic traces
4. Add semantic population triggers (review findings, refactor patterns)
5. Document in context-management skill; add index/timeline load protocol
