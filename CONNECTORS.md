# Connectors

This plugin works best with the following data sources connected. Configure them in `.mcp.json` or through your organization's MCP setup.

## Required

| Connector | Purpose | Funnel Stage | Default |
|-----------|---------|-------------|---------|
| **~~project-tracker~~** | Issue tracking, status transitions, label management | All stages | [Linear](https://mcp.linear.app/mcp) |
| **~~version-control~~** | Pull requests, code review, spec file management | Stages 3-7 | [GitHub](https://api.githubcopilot.com/mcp/) |

## Recommended

| Connector | Purpose | Funnel Stage | Examples |
|-----------|---------|-------------|----------|
| **~~ci-cd~~** | Automated spec review triggers, deployment checks | Stages 4, 7 | GitHub Actions |
| **~~deployment~~** | Preview deployments, production verification | Stages 5, 7 | Vercel, Netlify, Railway |
| **~~analytics~~** | Data-informed spec drafting, post-launch verification | Stages 2, 7 | PostHog, Amplitude, Mixpanel |
| **~~error-tracking~~** | Production error monitoring, auto-issue creation | Stage 7 | Sentry, Bugsnag |
| **~~component-gen~~** | UI component generation for visual prototyping | Stage 5 | v0.dev, Lovable |

## Optional

| Connector | Purpose | Funnel Stage | Examples |
|-----------|---------|-------------|----------|
| **~~research-library~~** | Literature grounding for research-based features | Stages 1-2 | Zotero |
| **~~web-research~~** | Web data for spec grounding and competitive analysis | Stages 1-2 | Firecrawl |
| **~~communication~~** | Stakeholder notifications, decision tracking | All stages | Slack |
| **~~design~~** | Visual prototyping handoff | Stage 5 | Figma, v0 |
| **~~observability~~** | Traces, metrics, health monitoring | Stage 7 | Honeycomb, Datadog |

## Customization

Replace `~~placeholder~~` values with your team's specific tools. The plugin's methodology is tool-agnostic -- it works with any project tracker, version control system, or CI/CD platform that has MCP support.

To customize, edit `.mcp.json` and update the server URLs to match your organization's tools.

---

## Tool-to-Funnel Reference

How each connector maps to the 9-stage funnel:

| Funnel Stage | Required Connectors | Recommended | Optional |
|---|---|---|---|
| Stage 0: Intake | project-tracker | -- | communication |
| Stage 1-2: Ideation + Analytics | project-tracker | analytics | research-library, web-research |
| Stage 3: PR/FAQ Draft | project-tracker, version-control | -- | -- |
| Stage 4: Adversarial Review | version-control | ci-cd | -- |
| Stage 5: Visual Prototype | -- | deployment, component-gen | design |
| Stage 6: Implementation | version-control | ci-cd | -- |
| Stage 7: Verification | version-control | deployment, analytics, error-tracking | observability |
| Stage 7.5: Closure | project-tracker | -- | -- |
| Stage 8: Handoff | project-tracker | -- | communication |

---

## Platform Configuration Checklist

When setting up your tools, verify these key settings. Misconfiguration here causes the most common integration failures.

### Version Control (GitHub example)

| Setting Area | Key Settings | Why It Matters |
|---|---|---|
| **Branches** | Default branch protection, required reviews | Gates for Stage 4 (adversarial review) and Stage 6 (PR review) |
| **Actions** | Workflow permissions, allowed actions | Enables Options A/C for adversarial review |
| **Copilot** | Code review rules, memory | Automated review quality in Option A |
| **Webhooks** | Linear sync, deployment triggers | Bidirectional issue tracking |
| **Environments** | Preview, production with required reviewers | Stage 7 deployment gates |

### Deployment Platform (Vercel example)

| Setting Area | Key Settings | Why It Matters |
|---|---|---|
| **Git integration** | PR comments, commit comments, verified commits | Stage 5 preview feedback loop |
| **Environment variables** | Separate preview/production secrets | Stage 7 verification accuracy |
| **Deployment protection** | Preview protection, production gates | Prevents premature production deployments |
| **Build settings** | Framework detection, output directory | Reliable Stage 7 deploys |

---

## Integration Wiring Guide

### Credential Storage Patterns

Choose the approach that matches your team size:

| Approach | Best For | Setup | Rotation |
|---|---|---|---|
| **OS Keychain** (macOS Keychain, Linux Secret Service) | Solo developer | `security add-generic-password` per key | Manual per key |
| **Secrets Manager** (Doppler, 1Password CLI, Vault) | Teams, multi-environment | Central config, CLI sync to local | One rotation propagates everywhere |
| **Environment files** (.env with .gitignore) | Quick prototyping only | Create `.env`, add to `.gitignore` | Manual, easy to forget |

**Recommendation:** Start with OS Keychain. Migrate to a secrets manager when you need multi-environment sync or team access.

### Bidirectional Sync Patterns

Common integration pairs and how to wire them:

| Integration | Direction | What Syncs | Setup |
|---|---|---|---|
| **Project tracker <-> Version control** | Bidirectional | Issue references in PRs, PR links in issues | Native integration (e.g., Linear-GitHub sync) |
| **Error tracking <-> Deployment** | Error tracking -> Deployment | Release tagging, source map upload | Marketplace integration (e.g., Sentry-Vercel) |
| **Error tracking <-> Project tracker** | Error tracking -> Project tracker | Auto-create issues from new error groups | Native integration (e.g., Sentry-Linear) |
| **Analytics <-> Project tracker** | Manual | Feature flag data informs spec drafting | No direct sync -- analyst reviews data during Stage 2 |

### Environment Variable Matrix

Track where each credential lives across environments:

| Variable | Local | Preview | Production | CI |
|---|---|---|---|---|
| Project tracker API token | Keychain | N/A (MCP only) | N/A | GitHub Secret |
| Version control token | Git config | N/A | N/A | Automatic |
| Deployment platform token | Keychain | Automatic | Automatic | GitHub Secret |
| Error tracking DSN | Keychain | Platform env var | Platform env var | GitHub Secret |
| Analytics key | Keychain | Platform env var | Platform env var | N/A |

---

## Secrets Management

### Decision Framework

| Factor | OS Keychain | Secrets Manager |
|---|---|---|
| Team size | 1 developer | 2+ developers |
| Environments | 1-2 (local + prod) | 3+ (local, preview, staging, prod) |
| Rotation frequency | Quarterly or less | Monthly or more |
| Audit requirements | None | Compliance/SOC2 |
| Cost | Free | Free tier available (Doppler, 1Password) |
| Migration effort from Keychain | N/A | ~1 hour per 20 keys |

### Migration Path

If you start with OS Keychain and later need a secrets manager:

1. Export current keys: `security dump-keychain` (filtered to your service prefix)
2. Import to secrets manager (most support bulk import)
3. Update CI/CD to pull from secrets manager instead of GitHub Secrets
4. Update local shell config to use secrets manager CLI
5. Verify all environments still work
6. Remove old Keychain entries
