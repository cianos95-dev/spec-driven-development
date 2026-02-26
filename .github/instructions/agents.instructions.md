---
applyTo: "agents/**"
---

# Agent Definition Review Guidelines

When reviewing changes to agent definition files:

- Must specify `name`, `description`, and `allowedTools`
- `allowedTools` should follow principle of least privilege
- Agent frontmatter may include: `model`, `memory`, `skills`, `hooks`, `mcpServers`
- `memory: user` enables persistent cross-session knowledge (used by persona agents)
- Verify the agent has a corresponding entry in `marketplace.json`
- Persona agents (adversarial review) must reference the `adversarial-review` skill
- No hardcoded credentials, API keys, or user-specific IDs in agent definitions
