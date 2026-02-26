---
applyTo: "skills/**"
---

# Skill Review Guidelines

When reviewing changes to skill files:

- YAML frontmatter must include `name` and `description` fields
- `description` must contain trigger phrases for skill matching
- `compatibility` must list valid surfaces: `code`, `cowork`, `desktop`
- Skill content must be >= 8192 characters (CI enforced)
- Cross-references to other skills must use backtick-quoted names (e.g., `execution-modes` skill)
- Verify cross-referenced skill names exist in `marketplace.json`
- Reference files under `references/` must be linked from the main SKILL.md
- No duplicate skill names across the manifest
