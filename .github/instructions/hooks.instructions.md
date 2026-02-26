---
applyTo: "hooks/**"
---

# Hook Script Review Guidelines

When reviewing changes to hook scripts:

- Exit code 0 = allow/pass (fail-open default)
- Exit code 2 = explicit deny (for PermissionRequest/PreToolUse hooks)
- Non-zero (other) = hook failure
- Scripts must be idempotent (safe to run multiple times)
- Must handle missing dependencies gracefully (check for `jq`, `git`, etc.)
- No hardcoded paths — use environment variables or relative paths
- Verify the hook has a corresponding entry in `marketplace.json`
- Test with both success and failure paths
