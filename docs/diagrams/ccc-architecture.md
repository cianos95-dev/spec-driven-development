# CCC Architecture: 9-Stage Funnel

The CCC plugin orchestrates work through a 9-stage funnel (S0-S8) with 3 quality gates. Skills, commands, agents, and hooks each play distinct roles at specific stages.

## Stage Funnel

```mermaid
flowchart TD
    subgraph S0["S0: Intake"]
        go_intake["/go + text description"]
    end

    subgraph S1["S1: Analytics"]
        planning[planning-preflight]
        codebase[codebase-awareness]
    end

    subgraph S2["S2: Spec Draft"]
        prfaq["/write-prfaq"]
        prfaq_method[prfaq-methodology]
        research[research-grounding]
        research_pipe[research-pipeline]
    end

    subgraph G1["Gate 1: Spec Approval"]
        g1_check{"spec:ready?"}
    end

    subgraph S3["S3: Adversarial Review"]
        review_cmd["/review"]
        adv_review[adversarial-review]
        sec[reviewer-security-skeptic]
        perf[reviewer-performance-pragmatist]
        arch[reviewer-architectural-purist]
        ux[reviewer-ux-advocate]
        debate[debate-synthesizer]
    end

    subgraph G2["Gate 2: Review Acceptance"]
        g2_check{"All Critical/Important\nfindings addressed?"}
        review_resp[review-response]
    end

    subgraph S4["S4: Decompose"]
        decompose_cmd["/decompose"]
    end

    subgraph S5["S5: Execute"]
        start_cmd["/start"]
        exec_engine[execution-engine]
        exec_modes[execution-modes]
        tdd[tdd-enforcement]
        debug[debugging-methodology]
        drift[drift-prevention]
        anchor_cmd["/anchor"]
        context[context-management]
        parallel[parallel-dispatch]
        tembo[tembo-dispatch]
    end

    subgraph S6["S6: PR Review"]
        pr_dispatch[pr-dispatch]
        code_reviewer[code-reviewer]
    end

    subgraph G3["Gate 3: PR Approval"]
        g3_check{"PR approved\n& CI green?"}
    end

    subgraph S7["S7: Verify"]
        ship[ship-state-verification]
        observe[observability-patterns]
    end

    subgraph S8["S8: Close"]
        close_cmd["/close"]
        quality[quality-scoring]
        outcome[outcome-validation]
        lifecycle[issue-lifecycle]
        branch[branch-finish]
    end

    S0 --> S1 --> S2 --> G1
    G1 -->|approved| S3
    G1 -->|rejected| S2
    S3 --> G2
    G2 -->|accepted| S4
    G2 -->|revise| S2
    S4 --> S5
    S5 --> S6 --> G3
    G3 -->|approved| S7
    G3 -->|changes requested| S5
    S7 --> S8
```

## Cross-Stage Skills

These skills operate across multiple stages rather than belonging to a single one:

```mermaid
flowchart LR
    subgraph Cross["Cross-Stage Skills"]
        direction TB
        go["/go — unified router"]
        hygiene["/hygiene — project health"]
        insights["/insights — observability"]
        deps["/deps — dependency tracking"]
        config["/config — preferences"]
        index["/index — codebase indexing"]
        session[session-exit]
        dispatch_ready[dispatch-readiness]
    end

    subgraph Maintenance["Maintenance Skills"]
        direction TB
        milestone_mgmt[milestone-management]
        milestone_fc[milestone-forecast]
        doc_life[document-lifecycle]
        proj_status[project-status-update]
        proj_cleanup[project-cleanup]
        resource_fresh[resource-freshness]
        pattern_agg[pattern-aggregation]
    end

    subgraph Domain["Domain Skills"]
        direction TB
        zotero[zotero-workflow]
        spec_workflow[spec-workflow]
        agent_intents[agent-session-intents]
        platform[platform-routing]
    end
```

## Enforcement Layer (Hooks)

```mermaid
flowchart LR
    subgraph SessionStart["SessionStart (3 hooks)"]
        ss1[session-start.sh]
        ss2[style-injector.sh]
        ss3[conformance-cache.sh]
    end

    subgraph PreToolUse["PreToolUse (2 hooks)"]
        ptu1[pre-tool-use.sh]
        ptu2[circuit-breaker-pre.sh]
    end

    subgraph PostToolUse["PostToolUse (3 hooks)"]
        post1[post-tool-use.sh]
        post2[circuit-breaker-post.sh]
        post3[conformance-log.sh]
    end

    subgraph Stop["Stop (3 hooks)"]
        stop1[ccc-stop-handler.sh]
        stop2[stop.sh]
        stop3[conformance-check.sh]
    end

    subgraph UserPrompt["UserPromptSubmit (1 hook)"]
        ups1[prompt-enrichment.sh]
    end

    subgraph Teams["Agent Teams (2 hooks)"]
        ti1[teammate-idle-gate.sh]
        tc1[task-completed-gate.sh]
    end
```

## Agent Roles

| Agent | Role | Stage |
|-------|------|-------|
| `spec-author` | Drafts specs from intake | S2 |
| `reviewer` | Base adversarial reviewer | S3 |
| `reviewer-security-skeptic` | Security-focused review | S3 |
| `reviewer-performance-pragmatist` | Performance-focused review | S3 |
| `reviewer-architectural-purist` | Architecture-focused review | S3 |
| `reviewer-ux-advocate` | UX-focused review | S3 |
| `debate-synthesizer` | Reconciles review personas | S3 |
| `implementer` | Executes spec-to-code | S5 |
| `code-reviewer` | PR-level code review | S6 |

## Command Quick Reference

| Command | Primary Stage | Purpose |
|---------|--------------|---------|
| `/go` | Router | Unified entry point — detects context, routes to stage |
| `/write-prfaq` | S2 | Interactive PR/FAQ spec generation |
| `/review` | S3 | Adversarial review with 4 personas + debate |
| `/decompose` | S4 | Break issue into ordered sub-tasks |
| `/start` | S5 | Begin execution of current task |
| `/anchor` | S5 | Re-anchor to spec (drift prevention) |
| `/close` | S8 | Evidence-based closure with quality scoring |
| `/hygiene` | Cross | Project health audit (7 check groups) |
| `/insights` | Cross | Observability and methodology metrics |
| `/deps` | Cross | Dependency tracking and resolution |
| `/config` | Cross | Preferences management |
| `/index` | Cross | Codebase indexing |
| `/self-test` | Cross | In-session plugin validation |
| `/template-validate` | Cross | Template structure validation |
| `/template-bootstrap` | Cross | First-time template provisioning |
| `/template-sync` | Cross | Template drift correction |
| `/status-update` | Cross | Weekly initiative status sync |
