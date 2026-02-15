# Round 1: Security Skeptic Review — CIA-303

**Reviewer:** Security Skeptic (Red)
**Round:** 1 (Independent Review)
**Date:** 2026-02-15

---

## Security Skeptic Review: CIA-303

**Threat Model Summary:** This spec introduces automated scraping of Claude Code internals (/insights HTML), dynamic rule modification based on parsed session data, and persistent storage of session metadata--all without authentication boundaries, input validation, or adversarial input consideration. The adaptive loop creates a privileged feedback mechanism that an attacker with session access could poison.

---

### Critical Findings

- **HTML Parsing Attack Surface**: Spec assumes /insights HTML is safe to parse without validation. If Claude Code's /insights output ever reflects user-controlled content (file paths, commit messages, tool parameters), you've created an HTML injection vector. An attacker who can influence session content could inject malicious payloads that your parser treats as legitimate metrics.
  - **Mitigation**: Treat /insights output as untrusted. Use strict HTML parsing with allowlist-only tag/attribute filtering. Define expected schema and reject malformed input. Never `eval()` or execute extracted strings.

- **Insights Archive Poisoning**: "Insights archive format has no schema validation" means an attacker with filesystem access can inject fabricated session data. Your adaptive loop will then modify methodology rules based on fake patterns--effectively letting an attacker reprogram your plugin's behavior.
  - **Mitigation**: Sign insights archives with HMAC (key in Keychain). Validate schema on read with strict JSON Schema. Add tamper detection--if archive fails validation, alert user and refuse to apply adaptive changes.

- **Dynamic Threshold Manipulation**: Adaptive hooks adjust thresholds based on observed patterns. If an attacker can influence what gets logged (e.g., by triggering specific tool sequences), they can train your system to lower safety thresholds. Example: repeatedly trigger expensive operations just below current threshold -> system learns to raise limit -> attacker now has higher ceiling for resource exhaustion.
  - **Mitigation**: Hard caps on adaptive ranges (never allow thresholds >2x default). Require human approval for threshold changes >20%. Log all adaptive adjustments with justification for audit trail.

- **No Authentication on /sdd:insights Command**: Anyone with access to the Claude Code session can run `/sdd:insights` and see aggregated methodology metrics. If these include file paths, issue IDs, or commit references from private repos, you're leaking project structure to anyone with terminal access.
  - **Mitigation**: Sanitize output--redact absolute paths (show relative or `<repo>/...`), anonymize issue IDs (show counts only), strip commit hashes. Consider rate limiting or session-scoped caching to prevent reconnaissance.

---

### Important Findings

- **Secrets in Tool Parameters**: /insights likely logs tool calls with parameters. If a developer accidentally passes an API key as a tool parameter (e.g., `Bash` with inline curl), your insights archive now contains a secret. Even worse, if your adaptive loop analyzes "successful patterns," it might flag that session as high-quality and recommend similar approaches.
  - **Mitigation**: Pre-filter tool parameters for common secret patterns (regex for API keys, tokens, passwords) before storage. Redact matches. Add secrets scanner to insights archive pipeline.

- **Drift Detection False Positives Leading to Privilege Escalation**: Drift detection triggers methodology changes when patterns deviate. An attacker could deliberately create anomalous patterns (e.g., run 100 Read calls in a session) to trigger drift alerts. If the adaptive response is to "relax validation" (thinking it's a legitimate new workflow), you've just lowered defenses.
  - **Mitigation**: Drift responses should **never weaken validation**--only tighten or alert. Implement anomaly quarantine: if behavior is >3 sigma from baseline, flag for human review before applying any adaptation.

- **References/ Read-Through Metric as Reconnaissance Signal**: Tracking whether `references/*.md` files are read correlates with session quality--but also tells an attacker which reference docs are actually used vs ignored. This reveals which parts of your methodology are actually enforced vs aspirational, letting them target gaps.
  - **Mitigation**: Aggregate read-through metrics at file-class level (e.g., "70% of security references read") not per-file. Don't expose which specific files were skipped. Store metrics in anonymized form.

- **No Rate Limiting on Insights Extraction**: Spec doesn't mention limits on how often insights can be extracted/parsed. An attacker with session access could spam `/sdd:insights` calls to exfiltrate data or trigger resource exhaustion in HTML parser.
  - **Mitigation**: Cache parsed insights per session (1 parse per 5 minutes). Implement exponential backoff for repeated calls. Log excessive access attempts.

---

### Consider

- **Audit Logging for Adaptive Changes**: When the adaptive loop modifies thresholds or rules, there's no mention of logging *why* that decision was made. For security incidents, you'll need to reconstruct what inputs led to a configuration change.
  - **Enhancement**: Log every adaptive decision with: trigger data (anonymized), old/new values, timestamp, affected rules. Store in append-only log with integrity checks.

- **Rollback Mechanism for Bad Adaptations**: If the adaptive loop makes a poor decision (lowers a critical threshold, misinterprets friction), how do you undo it? Without rollback, a single poisoned session could degrade plugin behavior permanently.
  - **Enhancement**: Version all adaptive changes. Provide `/sdd:rollback <version>` command. Auto-rollback if next 3 sessions show >50% quality score drop.

- **Compliance Implications of Session Metadata Storage**: GDPR/CCPA treat session metadata (timestamps, actions, file paths) as personal data if tied to identifiable individuals. Your insights archive stores this indefinitely without retention policy or anonymization.
  - **Enhancement**: Anonymize metrics before storage (strip user identifiers, generalize timestamps to hour-level). Define retention policy (auto-delete insights >90 days old). Document data handling in plugin privacy notice.

- **Least Privilege for Insights Access**: The insights-integration skill will have read access to parsed session data. Does it need write access to adaptive configs? Could you separate read-only analytics from write-capable adaptation?
  - **Enhancement**: Split into two skills: `insights-reader` (read-only, used by reporting) and `insights-adapter` (write access, used only by adaptive loop). Require explicit user consent before adapter runs.

---

### Quality Score (Security Lens)

| Dimension | Score (1-5) | Notes |
|-----------|-------------|-------|
| Data flow security | **2** | No validation on /insights HTML input, no integrity checks on stored archives, no sanitization of tool parameters |
| Auth boundaries | **1** | Zero authentication--anyone with session access can read insights, trigger adaptations, extract methodology metadata |
| Input validation | **1** | "No schema validation" explicitly stated; HTML parsing without sanitization; no rate limiting |
| Secrets management | **2** | No mention of secret detection in logged tool calls; insights archive could contain leaked credentials |
| Attack surface | **2** | New HTML parser (attack vector), new command endpoint (/sdd:insights, unauthenticated), dynamic rule modification (privilege escalation risk) |

**Overall Security Posture: 1.6/5 (High Risk)**

---

### What the Spec Gets Right (Security)

- **Separation of Monitoring Layers**: Three-layer stack (structural, runtime, adaptive) correctly isolates concerns--if Layer 3 is compromised, Layers 1-2 still provide baseline safety. This is good defense-in-depth architecture.

- **Retrospective Correlation**: Mapping friction points to Linear outcomes is read-only analysis, not live intervention--lower risk than real-time adaptive systems.

- **References/ Read-Through as Process Signal**: Using reference doc engagement as a quality indicator is clever--it's a behavioral metric an attacker can't easily game without also improving their attack.

- **Adaptive Loop as Periodic, Not Real-Time**: "Periodic" suggests batch processing, not instant feedback. This gives you a window to detect poisoned data before it affects methodology.

---

**Recommendation**: **REVISE** -- Critical findings must be addressed before implementation.
