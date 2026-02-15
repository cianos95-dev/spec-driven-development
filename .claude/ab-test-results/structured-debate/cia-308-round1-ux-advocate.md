# CIA-308 Round 1: UX Advocate (Green)

## Review Metadata
- **Persona:** UX Advocate (Green)
- **Focus:** User journey, error experience, cognitive load, discoverability
- **Date:** 2026-02-15
- **Codebase scan:** cia-308-codebase-scan.md

---

## Executive Summary

This spec proposes PM/Dev workflow extensions through new commands, skills, and connector integrations, plus reconciliation of README documentation debt. From a user experience perspective, the proposal reveals significant usability concerns: outdated README creates misleading documentation, analytics connectors add complexity without clear user value, proposed new commands lack clear use cases, and the 12 commands / 21 skills surface creates overwhelming choice architecture.

**Key concern:** The spec focuses on *completeness* (document all features, reconcile counts) without addressing *discoverability* (how do users find features?), *learnability* (what's the onboarding path?), or *progressive disclosure* (what's essential vs. advanced?). A plugin with 12 commands and 21 skills is powerful, but for a new user, it's paralyzing.

**Recommendation:** APPROVE with CRITICAL usability mitigations required before extending the feature surface.

---

## Critical Findings (Block Until Resolved)

### C1: README Undercounting Creates Misleading Documentation

**Evidence:**
- Codebase scan: "README claims 8 commands (actual: 12) — undercounts by 4"
- Codebase scan: "README claims 10 skills (actual: 21) — undercounts by 11"
- User journey breakdown:
  1. New user reads README to learn plugin capabilities
  2. README says "8 commands available"
  3. User learns those 8 commands
  4. User discovers `/sdd:insights` exists but wasn't documented
  5. User loses trust: "What else is missing?"
  6. User must check `marketplace.json` to verify truth

**User impact:**
- **Hidden features** — 4 commands and 5 skills are invisible to users who only read README
- **Trust erosion** — Documentation inaccuracy signals low quality
- **Discovery failure** — Users can't find features that exist
- **Cognitive overhead** — Must cross-reference README vs. marketplace.json vs. actual usage

**Specific missing commands from README:**
- `/sdd:config` — Configuration management (useful for troubleshooting)
- `/sdd:go` — Session replanning (useful for multi-session work)
- `/sdd:insights` — Insights report archival (useful for continuous improvement)
- `/sdd:self-test` — Plugin validation (useful for debugging)

**Specific missing skills from README:**
- `insights-pipeline` — Insights archival patterns
- `parallel-dispatch` — Subagent orchestration
- `session-exit` — End-of-session cleanup
- `ship-state-verification` — Release validation
- `observability-patterns` — Monitoring stack

**Mitigation required:**
1. Add all 4 missing commands to README command table with descriptions
2. Add all 5 missing skills to README skill table with trigger phrases
3. Add CI check: `npm run verify-readme` fails if counts mismatch
4. Add command/skill usage examples for newly-documented features
5. Add "Hidden Features" section to README for advanced commands (prevent re-hiding)

**Without mitigation:** Users operate with incomplete mental model of plugin capabilities.

### C2: 12 Commands + 21 Skills = Overwhelming Choice Architecture

**Evidence:**
- Current: 12 commands, 21 skills (33 total components)
- Spec proposes: Add up to 4 new commands, 5 new skills (potential 16 commands, 26 skills = 42 components)
- No prioritization: All commands appear equal in README table
- No progressive disclosure: Beginner vs. advanced distinction not marked
- No workflow paths: "If you want to do X, use these 3 commands in this order"

**User journey breakdown:**
1. New user: "I want to write a spec."
2. Reads README command table: 12 options
3. Unclear which command is for spec writing
4. Guesses `/sdd:write-prfaq` (correct) vs. `/sdd:index` (wrong) — 50/50 chance
5. If guessed wrong, wasted 10 minutes on wrong command

**Hick's Law violation:**
- Decision time increases logarithmically with number of choices
- 12 commands → ~3.6 seconds decision time (per Hick's Law: T = b × log₂(n+1), b ≈ 1 second)
- 16 commands → ~4.1 seconds decision time
- Adds 0.5 seconds per decision × 10 decisions/session = 5 seconds/session overhead

**Mitigation required:**
1. Add command categorization to README:
   - **Essential** (5 commands): `write-prfaq`, `review`, `start`, `close`, `anchor`
   - **Workflow** (3 commands): `decompose`, `go`, `hygiene`
   - **Observability** (2 commands): `insights`, `index`
   - **Meta** (2 commands): `config`, `self-test`
2. Add skill categorization:
   - **Core** (5 skills): `spec-workflow`, `execution-modes`, `prfaq-methodology`, `adversarial-review`, `issue-lifecycle`
   - **Quality** (3 skills): `quality-scoring`, `drift-prevention`, `ship-state-verification`
   - **Advanced** (remaining 13 skills)
3. Add README section: "New User Quick Start" — lists only Essential commands + Core skills
4. Add README section: "Common Workflows" with command sequences:
   - "Write and ship a feature: `/sdd:write-prfaq` → `/sdd:review` → `/sdd:start` → `/sdd:close`"
   - "Debug slow sessions: `/sdd:insights --review` → check friction points"

**Without mitigation:** Feature bloat creates paradox of choice, users abandon plugin due to complexity.

### C3: Analytics Connectors Add Complexity Without Clear User Value

**Evidence:**
- CONNECTORS.md Stage 2: "analytics — Data-informed spec drafting"
- User workflow: Read analytics → inform prioritization
- **BUT:** What specific analytics inform what decisions?
- Example: PostHog shows 1,000 pageviews for Feature A, 100 for Feature B. Does this mean build Feature A? Or Feature B needs improvement?
- No decision framework documented
- User must interpret data → high cognitive load

**User journey breakdown:**
1. User runs `/sdd:write-prfaq` for new feature
2. Plugin says: "Check analytics first (Stage 2)"
3. User opens PostHog, sees 50 metrics
4. Unclear which metrics matter
5. User spends 20 minutes analyzing data
6. User still unsure: "Should I build this?"

**Spec proposes:** Add `analytics-integration` skill
**Problem:** Skill doesn't solve decision framework gap, just provides integration guidance

**Mitigation required:**
1. Add decision framework to Stage 2 documentation:
   - "High usage + low satisfaction → improvement candidate"
   - "Low usage + high satisfaction → niche feature, low priority"
   - "High usage + high satisfaction → core feature, maintain but don't extend"
   - "Low usage + low satisfaction → deprecation candidate"
2. Add analytics checklist to `/sdd:write-prfaq`:
   - "Check pageviews: >1K/month = high usage"
   - "Check bounce rate: >60% = low satisfaction"
   - "Check feature flag adoption: <10% = low confidence"
3. Add example: "Feature A has 5K pageviews/month but 70% bounce. Decision: Improve UX, not add features."

**Without mitigation:** Analytics adds work (fetch data, interpret) without clear output (decision).

### C4: Enterprise Search and Developer Marketing Skills Lack Use Case Definition

**Evidence:**
- Spec proposes: `enterprise-search-patterns` skill
- Spec proposes: `developer-marketing` skill
- Codebase scan verdict: "CLARIFY SCOPE" for both
- No user stories provided
- No example workflows

**User confusion:**
- "What is 'enterprise search'?" — Is this for finding code? Documentation? Issues? Linear comments?
- "What is 'developer marketing'?" — Is this for writing blog posts? Launch plans? Social media? Developer relations?
- Without use cases, users can't decide if they need these skills

**Example missing user story for enterprise search:**
- As a developer, I want to search across Linear issues + GitHub PRs + Notion docs + Slack threads
- So that I can find context for a bug without switching tools
- Acceptance: Search "auth bug" returns relevant results from all 4 sources

**Example missing user story for developer marketing:**
- As a PM, I want to generate a launch checklist for a new feature
- Including: Blog post outline, demo script, social media posts, changelog entry
- So that I don't forget marketing steps

**Mitigation required:**
1. Add 3 user stories per proposed skill
2. Add example workflow: "User invokes `/sdd:search 'auth bug'`, enterprise-search skill activates, returns results from Linear + GitHub + Notion"
3. Add acceptance criteria: What makes a search result "good"?
4. Block skill creation until use cases validated with 3+ users

**Without mitigation:** Skills created without user need, add bloat without value.

---

## Important Findings (Strongly Recommend)

### I1: Skill Activation Is Opaque to Users

**Evidence:**
- README line 186: "Skills are passive knowledge that Claude surfaces automatically when relevant context appears in conversation."
- "Automatically" = black box to users
- No indication when skill activated
- No indication why skill activated
- No way to force-activate skill if needed

**User confusion:**
- User says: "Help me with research grounding"
- `research-grounding` skill should activate
- But does it? User can't tell.
- If skill doesn't activate, user doesn't know if phrase was wrong or skill is broken

**Mitigation recommendation:**
1. Add skill activation feedback: "[✓] research-grounding skill activated"
2. Add skill activation log: "Skills activated this session: research-grounding, prfaq-methodology, spec-workflow"
3. Add force-activation syntax: "Use skill: research-grounding" → guarantees activation
4. Add to `/sdd:self-test`: List all skills and their trigger phrases

### I2: Error Messages Lack Actionable Guidance

**Evidence:**
- No error message examples in spec or codebase scan
- Common plugin errors:
  - "Command not found" — User typo `/sdd:wirte-prfaq`
  - "MCP connection failed" — Linear/GitHub MCP offline
  - "Spec file not found" — User in wrong directory
- If errors don't provide next steps, users stuck

**User frustration:**
- User runs `/sdd:review`
- Error: "Spec file not found"
- User: "Where should spec file be? What should it be named? How do I create one?"
- No guidance provided

**Mitigation recommendation:**
1. Add error message template: "Error: <problem>. Try: <solution>. Docs: <link>"
2. Example: "Error: Spec file not found. Try: Create `docs/specs/<issue-id>.md` or run `/sdd:write-prfaq` first. Docs: README.md#spec-workflow"
3. Add common errors section to README with solutions
4. Add `/sdd:doctor` command: Diagnoses common setup issues and suggests fixes

### I3: Multi-Step Commands Lack Progress Indication

**Evidence:**
- `/sdd:review` (adversarial review): Multi-step process (read spec, call 4 models, synthesize findings)
- `/sdd:index` (codebase scan): Large repos take 1-16 minutes
- `/sdd:decompose` (task breakdown): Complex specs generate 50+ tasks
- No progress indication documented

**User anxiety:**
- User runs `/sdd:index` on large repo
- Terminal silent for 5 minutes
- User: "Is it working? Should I cancel? Did it freeze?"

**Mitigation recommendation:**
1. Add progress indicators: "[1/4] Reading spec... [2/4] Calling GPT-4... [3/4] Calling Claude..."
2. Add time estimates: "Indexing 10,000 files... estimated 8 minutes remaining"
3. Add cancellation safety: "Press Ctrl+C to cancel safely. Progress will be saved."
4. Add to long-running commands: `--quiet` flag to suppress progress for CI environments

### I4: Connector Setup Instructions Are Scattered

**Evidence:**
- CONNECTORS.md documents 14 connector placeholders
- Setup instructions for each tool in different sections
- Example: PostHog setup requires:
  1. API key from PostHog dashboard
  2. Add to `.env.local`
  3. Configure MCP in `.mcp.json`
  4. Verify with test event
- These 4 steps are documented in 3 different files (CONNECTORS.md, README, `.mcp.json` comments)

**User frustration:**
- User: "How do I set up PostHog?"
- Searches README: Finds PostHog mentioned, but no setup steps
- Searches CONNECTORS.md: Finds PostHog description, but no detailed setup
- Searches `.mcp.json`: Finds example config, but no explanation

**Mitigation recommendation:**
1. Add "Connector Setup" section to CONNECTORS.md with step-by-step guides per tool
2. Add setup checklist:
   - [ ] Create PostHog account
   - [ ] Generate API key
   - [ ] Add `POSTHOG_API_KEY` to `.env.local`
   - [ ] Test connection: `curl <posthog-api>` with key
   - [ ] Verify in Stage 2: `/sdd:write-prfaq` should fetch analytics
3. Add setup troubleshooting: "If analytics unavailable, check: API key valid? Network reachable? Rate limit exceeded?"

### I5: Onboarding Path Is Unclear

**Evidence:**
- README "Getting Started in 5 Minutes" (line 5-20) provides installation steps
- But after install: "Tell Claude about your feature idea. Run `/sdd:write-prfaq`. The plugin guides you from there."
- This assumes user knows:
  - What a PR/FAQ is
  - What a "feature idea" means (vs. bug fix, chore, research spike)
  - What happens after `/sdd:write-prfaq`

**New user confusion:**
- User installs plugin
- Reads "Tell Claude about your feature idea"
- User: "I have a bug to fix, not a feature. Should I still use `/sdd:write-prfaq`?"
- User: "What's a PR/FAQ? Is that Amazon's thing?"

**Mitigation recommendation:**
1. Add onboarding tutorial to README: "First Time? Start Here"
2. Tutorial workflow:
   - Step 1: Run `/sdd:index` to scan your codebase
   - Step 2: Create a Linear issue for your task
   - Step 3: Run `/sdd:write-prfaq` to draft spec
   - Step 4: Run `/sdd:review` to get feedback
   - Step 5: Run `/sdd:start` to begin implementation
3. Add task type guidance: "Feature → `/sdd:write-prfaq`. Bug fix → `/sdd:start` (skip spec). Research → `/sdd:write-prfaq` with `prfaq-research` template."
4. Add interactive setup: `claude plugins setup sdd` walks through Linear/GitHub/PostHog config

---

## Consider Items (Optional Improvements)

### R1: Command Names Are Developer-Centric, Not User-Centric

**Evidence:**
- `/sdd:write-prfaq` — "PR/FAQ" is Amazon jargon, not universal
- `/sdd:anchor` — "Anchor" is plugin jargon, unclear to new users
- `/sdd:hygiene` — Implies "cleanup", but actually audits issues

**User confusion:**
- New user: "I want to write a spec."
- Correct command: `/sdd:write-prfaq`
- User searches README for "spec" — doesn't find it in command name
- User tries `/sdd:write-spec` (doesn't exist)

**Mitigation suggestion:**
- Add command aliases: `/sdd:write-spec` → `/sdd:write-prfaq`
- Add command aliases: `/sdd:refocus` → `/sdd:anchor`
- Add command aliases: `/sdd:audit` → `/sdd:hygiene`
- Document in README: "Aliases available for common terms"

### R2: Success Criteria Are Implicit

**Evidence:**
- `/sdd:close` evaluates quality score (0-100)
- Score ≥80 = success, <60 = failure
- But this threshold isn't shown to user until closure
- User doesn't know during implementation: "Am I on track for 80+?"

**User anxiety:**
- User implements feature
- Runs `/sdd:close`
- Score: 58 (failure)
- User: "I wish I knew earlier. Now I have to rework."

**Mitigation suggestion:**
- Add `/sdd:status` command: Shows current quality score estimate mid-session
- Add proactive warnings: "Test coverage 20% (target 80%). Add tests before closing."
- Add to `/sdd:start`: "This task targets 80+ quality score. Ensure: tests, docs, review."

### R3: Keyboard Shortcuts Missing for Common Commands

**Evidence:**
- All commands invoked via `/sdd:<command>` syntax
- No keyboard shortcuts
- Frequent commands: `/sdd:anchor` (drift prevention), `/sdd:start` (begin task)

**User friction:**
- Typing `/sdd:anchor` = 11 keystrokes
- If used 10 times/session, 110 keystrokes
- Could be reduced to 2-3 keystrokes with alias

**Mitigation suggestion:**
- Add command aliases: `/a` → `/sdd:anchor`, `/s` → `/sdd:start`, `/c` → `/sdd:close`
- Document in README: "Short aliases: `/a` (anchor), `/s` (start), `/c` (close)"
- Make configurable: User can set custom aliases in `.claude/sdd-config.json`

---

## Quality Score

| Dimension | Score | Rationale |
|-----------|-------|-----------|
| **Discoverability** | 35/100 | README undercounts features by 4 commands + 5 skills (C1), no progressive disclosure (C2), skill activation opaque (I1). |
| **Learnability** | 40/100 | 33 components overwhelming (C2), no onboarding tutorial (I5), analytics lacks decision framework (C3). |
| **Error Experience** | 45/100 | No error message examples (I2), no troubleshooting guide, connector setup scattered (I4). |
| **Cognitive Load** | 35/100 | 12 commands flat list (C2), enterprise search/dev marketing lack use cases (C4), command names jargon-heavy (R1). |
| **Feedback** | 50/100 | No progress indication for long commands (I3), skill activation silent (I1), success criteria implicit (R2). |
| **Accessibility** | 65/100 | No keyboard shortcuts (R3), but commands are text-based (accessible by default). |

**Overall UX Score: 42/100**

**Confidence:** High (8/10) — README undercounting and component proliferation are directly observable. User journey breakdowns are inferred from typical onboarding patterns.

---

## What This Spec Gets Right

1. **Progressive disclosure in skills** — Skills have `SKILL.md` (core) + `references/` (advanced). This prevents overwhelming users with all details upfront.

2. **"Getting Started in 5 Minutes"** — README line 5-20 provides fast installation path. This respects user time.

3. **Execution mode routing** — 5 modes (quick/tdd/pair/checkpoint/swarm) give users explicit control over ceremony level. Reduces friction for simple tasks.

4. **Quality scoring transparency** — 0-100 score with 3 dimensions (test/coverage/review) gives users clear success criteria. Not implicit.

5. **Example files** — `examples/` directory provides concrete references (sample PR/FAQ, sample review findings, sample closure comment). Users can learn by example.

6. **Ship-state verification** — `ship-state-verification` skill prevents "marked Done but not shipped" errors. This protects users from false success.

---

## Recommendation

**APPROVE** with the following **CRITICAL mitigations required** before any implementation:

1. **BLOCK C1:** Add 4 missing commands + 5 missing skills to README tables, add CI verification check, add usage examples
2. **BLOCK C2:** Add command/skill categorization (Essential/Workflow/Observability/Meta + Core/Quality/Advanced), add "New User Quick Start" section, add common workflow sequences
3. **BLOCK C3:** Add analytics decision framework to Stage 2 docs, add analytics checklist to `/sdd:write-prfaq`, add example decision
4. **BLOCK C4:** Add 3 user stories per proposed skill (enterprise-search, developer-marketing), add example workflows, block creation until validated

**Important recommendations (strongly encourage, not blocking):**
- Add skill activation feedback and force-activation syntax (I1)
- Add error message template with actionable guidance (I2)
- Add progress indicators for long-running commands (I3)
- Add connector setup section with step-by-step guides (I4)
- Add onboarding tutorial with task type guidance (I5)

**Consider recommendations (optional):**
- Add command aliases for common terms (R1)
- Add `/sdd:status` command for mid-session quality score estimate (R2)
- Add keyboard shortcuts for frequent commands (R3)

**Rationale:** The spec addresses real gaps (README accuracy, connector coverage), but adding 4+ commands and 5+ skills without improving discoverability will create feature bloat. The plugin already has 33 components — adding more without categorization, onboarding improvements, or use case validation will overwhelm new users. The mitigations are primarily documentation (README restructuring, decision frameworks), making them low-effort, high-value improvements.
