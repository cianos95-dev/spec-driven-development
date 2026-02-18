# Copilot Code Review Instructions

## Code Quality

- Focus on security vulnerabilities, logic errors, and potential bugs
- Flag any hardcoded secrets, API keys, or credentials
- Check for proper error handling and edge cases
- Avoid style/formatting nitpicks (handled by linters)

## Plugin Architecture

- Skills must follow the skill schema: name, description, content fields
- Agent definitions must specify available tools correctly
- Hook scripts must handle exit codes properly (0 = pass, 1 = warn, 2 = block)
- YAML/JSON config files must validate against their schemas

## Claude Code Plugin Patterns

- Skills are loaded via the Skill tool, never via Read
- Plugin manifest must declare all skills, agents, and hooks
- Marketplace wrapper required for distribution
- `github` source = production, `directory` = dev-only

## Security

- Never expose API keys or tokens in plugin code
- Validate all external inputs (Linear API responses, GitHub API responses)
- No hardcoded credentials or secrets
- Environment variables preferred for sensitive configuration

## Testing

- Skill content should be self-contained and testable
- Hook scripts should be idempotent
- Agent definitions should specify clear boundaries

## Documentation

- Each skill should have clear trigger conditions documented
- Breaking changes require version bumps in manifest
