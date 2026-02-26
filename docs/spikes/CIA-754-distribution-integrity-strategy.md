# Spike: Distribution Integrity Strategy for Multi-Channel Plugin Publishing (CIA-754)

**Status:** Complete
**Date:** 2026-02-26
**Issue:** CIA-754
**Related:** CIA-751 (5-persona debate synthesis), ADR-001 (plugin distribution architecture)

## Problem Statement

CCC aims to distribute across three channels: GitHub (primary), npm (additive), and Cowork Desktop ZIP. The 5-persona review on CIA-751 flagged that no cross-channel integrity binding exists — GitHub/npm/ZIP could contain different code with no provenance attestation (4/5 reviewers flagged this as M1 finding).

---

## Research Question 1: npm Provenance via GitHub Actions

### Finding: GO

npm provenance with GitHub Actions is production-ready and straightforward for CCC.

**How it works:**

1. npm trusted publishing uses OIDC (OpenID Connect) to create a trust relationship between GitHub Actions and the npm registry
2. Instead of long-lived `NPM_TOKEN` secrets, the workflow exchanges a short-lived OIDC token for npm publish credentials
3. Sigstore signs the provenance attestation, linking the published package to its source repo, commit SHA, and build workflow
4. The provenance badge appears on npmjs.com, and consumers can verify with `npm audit signatures`

**Requirements:**

| Requirement | CCC Status | Action Needed |
|-------------|-----------|---------------|
| npm CLI v11.5.1+ or Node.js v24+ | Not applicable yet | Use `actions/setup-node@v4` with `node-version: '24'` |
| GitHub Actions workflow | Exists (version-bump.yml) | New release workflow needed |
| `id-token: write` permission | Not set | Add to release workflow permissions |
| `--provenance` flag on `npm publish` | N/A | Add to publish command |
| `package.json` in repo | **Missing** | Must create one for npm distribution |
| npm account with trusted publisher configured | **Missing** | One-time setup on npmjs.com |
| Cloud-hosted runner (not self-hosted) | Using `ubuntu-latest` | Already satisfied |

**Minimal workflow snippet:**

```yaml
permissions:
  contents: read
  id-token: write

steps:
  - uses: actions/checkout@v4
  - uses: actions/setup-node@v4
    with:
      node-version: '24'
      registry-url: 'https://registry.npmjs.org'
  - run: npm publish --provenance --access public
```

**CCC-specific consideration:** CCC has no `package.json` today (it's a Claude Code plugin, not an npm package). Creating one is trivial — the package would contain the plugin's YAML/Markdown content files. The `files` field would whitelist `agents/`, `commands/`, `hooks/`, `skills/`, `styles/`, `.claude-plugin/`. No build step needed.

**Verdict:** GO. npm provenance via GitHub Actions OIDC is GA since July 2025, well-documented, and zero-cost. The only setup is a one-time trusted publisher configuration on npmjs.com and creating a `package.json`.

---

## Research Question 2: Minimal Viable Checksum Strategy

### Finding: Use GitHub Artifact Attestations (not GPG)

GPG-signed checksums are the traditional approach, but GitHub now offers a superior alternative: **artifact attestations** via `actions/attest-build-provenance`.

**Why artifact attestations over GPG:**

| Aspect | GPG-Signed Checksums | GitHub Artifact Attestations |
|--------|---------------------|------------------------------|
| Key management | Manual GPG key generation, rotation, distribution | Automatic via Sigstore + OIDC (no keys to manage) |
| Verification | `gpg --verify` (requires importing public key) | `gh attestation verify` (built into GitHub CLI) |
| Trust chain | Web of Trust / keyservers (declining ecosystem) | Sigstore transparency log (modern, append-only) |
| CI integration | Custom scripts to generate/sign checksums | First-party GitHub Action |
| SLSA compliance | Manual claim | Automatic SLSA v1.0 Build Level 2 (Level 3 with reusable workflows) |
| Release asset digests | Must generate manually | GitHub auto-computes SHA256 since June 2025 |

**Recommended strategy (layered):**

1. **Layer 1 — GitHub auto-digests (free, zero-config):** GitHub automatically computes and exposes SHA256 digests for all release assets. Available in the UI, REST API, GraphQL API, and `gh` CLI. This is already active for any GitHub Release.

2. **Layer 2 — Artifact attestations (recommended):** Add `actions/attest-build-provenance` to the release workflow. Creates Sigstore-backed provenance attestation for each release artifact (ZIP, tarball). Consumers verify with:
   ```bash
   gh attestation verify ccc-v1.10.0.zip --repo cianos95-dev/claude-command-centre
   ```

3. **Layer 3 — `SHA256SUMS` file (optional, for non-GitHub consumers):** Generate a `SHA256SUMS` file as a release asset for environments without `gh` CLI access. No GPG signing needed — the attestation in Layer 2 covers provenance.

**Minimal workflow snippet for Layer 2:**

```yaml
permissions:
  contents: write       # upload release assets
  id-token: write       # Sigstore OIDC
  attestations: write   # create attestations

steps:
  - uses: actions/checkout@v4
  - name: Build release ZIP
    run: |
      zip -r ccc-v${{ github.ref_name }}.zip \
        agents/ commands/ hooks/ skills/ styles/ \
        .claude-plugin/ LICENSE README.md \
        -x '*.git*' 'tests/*' 'scripts/*' 'docs/*'
  - name: Attest build provenance
    uses: actions/attest-build-provenance@v2
    with:
      subject-path: ccc-v${{ github.ref_name }}.zip
  - name: Upload to GitHub Release
    run: gh release upload ${{ github.ref_name }} ccc-v${{ github.ref_name }}.zip
    env:
      GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Verdict:** Skip GPG. Use GitHub artifact attestations (Layer 2) + auto-digests (Layer 1). Modern, zero key management, built-in verification via `gh` CLI, SLSA-compliant.

---

## Research Question 3: Manifest Hash in ZIP for Cross-Channel Parity

### Finding: YES — embed `MANIFEST.sha256` in ZIP and npm package

A manifest hash file ensures that consumers of any channel can verify their content matches the canonical source.

**Strategy:**

1. At release build time, compute SHA256 hashes of every file that ships in the plugin:
   ```bash
   find agents/ commands/ hooks/ skills/ styles/ .claude-plugin/ \
     -type f | sort | xargs sha256sum > MANIFEST.sha256
   ```

2. Include `MANIFEST.sha256` in:
   - The GitHub Release ZIP asset
   - The npm package (via `files` field in `package.json`)
   - The Cowork Desktop ZIP

3. The same `MANIFEST.sha256` file appears in all three channels. Consumers can verify parity:
   ```bash
   # After downloading from any channel:
   sha256sum -c MANIFEST.sha256
   ```

4. Add the manifest hash itself (SHA256 of `MANIFEST.sha256`) to the GitHub Release body for a single cross-channel verification point:
   ```
   ## Integrity
   Manifest hash: sha256:a1b2c3d4...
   Verify: `sha256sum -c MANIFEST.sha256` after extraction
   ```

**Cross-channel verification flow:**

```
GitHub Release ZIP ──extract──> MANIFEST.sha256 ──compare──┐
npm package       ──extract──> MANIFEST.sha256 ──compare──┤ All must match
Cowork Desktop ZIP──extract──> MANIFEST.sha256 ──compare──┘
```

**Why this works for CCC:** CCC's content is deterministic — YAML and Markdown files with no build step. The same source files produce identical hashes regardless of packaging format. The only difference between channels is the packaging envelope (ZIP structure, npm tarball metadata, etc.), not the content.

**Verdict:** YES. Embed `MANIFEST.sha256` in all distribution artifacts. It's the cross-channel integrity binding that the CIA-751 review flagged as missing. Cheap to implement, easy to verify.

---

## Research Question 4: Publish-or-Fail-All Workflow

### Finding: Staged draft-release pattern with rollback

A true atomic multi-channel publish is impossible (you can't un-publish from npm after `npm publish` succeeds). Instead, use a **staged draft-release pattern** that minimizes the window of inconsistency.

**Pseudocode:**

```yaml
name: Release
on:
  push:
    tags: ['v*']

permissions:
  contents: write
  id-token: write
  attestations: write

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      manifest-hash: ${{ steps.manifest.outputs.hash }}
    steps:
      - uses: actions/checkout@v4

      # Step 1: Generate canonical manifest
      - name: Generate MANIFEST.sha256
        id: manifest
        run: |
          find agents/ commands/ hooks/ skills/ styles/ .claude-plugin/ \
            -type f | sort | xargs sha256sum > MANIFEST.sha256
          HASH=$(sha256sum MANIFEST.sha256 | cut -d' ' -f1)
          echo "hash=$HASH" >> "$GITHUB_OUTPUT"

      # Step 2: Build all artifacts from same source
      - name: Build GitHub Release ZIP
        run: |
          zip -r ccc-${{ github.ref_name }}.zip \
            agents/ commands/ hooks/ skills/ styles/ \
            .claude-plugin/ MANIFEST.sha256 LICENSE README.md \
            -x '*.git*' 'tests/*' 'scripts/*' 'docs/*'

      # Step 3: Create DRAFT GitHub Release (not visible to consumers yet)
      - name: Create draft release
        run: |
          gh release create ${{ github.ref_name }} \
            --draft \
            --title "CCC ${{ github.ref_name }}" \
            --notes "## Integrity
          Manifest hash: sha256:${{ steps.manifest.outputs.hash }}
          Verify: \`sha256sum -c MANIFEST.sha256\` after extraction" \
            ccc-${{ github.ref_name }}.zip
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      # Step 4: Attest build provenance for ZIP
      - name: Attest ZIP provenance
        uses: actions/attest-build-provenance@v2
        with:
          subject-path: ccc-${{ github.ref_name }}.zip

      # Step 5: Publish to npm (with provenance)
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '24'
          registry-url: 'https://registry.npmjs.org'
      - name: Publish to npm
        run: npm publish --provenance --access public

      # Step 6: If npm succeeded, undraft the GitHub Release
      #         If npm failed, the release stays as draft (invisible)
      - name: Publish GitHub Release
        if: success()
        run: gh release edit ${{ github.ref_name }} --draft=false
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  # Rollback job: if the release job fails after npm publish,
  # npm unpublish within the 72-hour window
  rollback:
    runs-on: ubuntu-latest
    needs: build
    if: failure()
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '24'
          registry-url: 'https://registry.npmjs.org'
      - name: Attempt npm unpublish (72hr window)
        run: |
          VERSION=$(jq -r '.version' package.json)
          npm unpublish "claude-command-centre@$VERSION" || true
        continue-on-error: true
      - name: Delete draft release
        run: gh release delete ${{ github.ref_name }} --yes || true
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Key design decisions:**

| Decision | Rationale |
|----------|-----------|
| Draft release first, undraft last | GitHub Release is the most visible channel — keep it invisible until all channels succeed |
| npm publish before undraft | npm is the most likely failure point (auth, network, naming conflicts) — fail early |
| Rollback job with `npm unpublish` | npm allows unpublish within 72 hours for packages with <300 weekly downloads (CCC's expected range) |
| Single job, not parallel | Sequential ordering ensures we can abort before later channels if an early one fails |
| Tag-triggered | Version tag (`v1.10.0`) is the release trigger — matches existing version-bump workflow output |

**Cowork Desktop ZIP handling:** The Cowork Desktop ZIP is the same artifact as the GitHub Release ZIP. Cowork downloads from the GitHub Release URL (per ADR-001, `github` source). No separate publish step needed — when the GitHub Release is undrafted, Cowork can fetch it.

**Failure scenarios:**

| Failure Point | State | Recovery |
|--------------|-------|----------|
| Build/ZIP creation fails | Nothing published | Re-run workflow |
| Draft release creation fails | Nothing published | Re-run workflow |
| npm publish fails | Draft release exists (invisible) | Rollback job deletes draft. Re-run after fixing. |
| Undraft fails | npm published, release still draft | Manual `gh release edit --draft=false`. Consumers see npm but not GitHub Release temporarily. |
| Attestation fails | Release may be published without attestation | Non-blocking — add attestation manually or re-release |

**Verdict:** The draft-release pattern provides effective publish-or-fail-all semantics. True atomicity is impossible across independent registries, but the draft/undraft pattern keeps the consumer-visible surface consistent.

---

## Decisions Summary

| Question | Decision | Confidence |
|----------|----------|------------|
| npm provenance for CCC? | **GO** — OIDC-based, zero-cost, GA since July 2025 | High |
| Checksum strategy? | **GitHub artifact attestations** (not GPG) + auto-digests + `MANIFEST.sha256` | High |
| Manifest hash in ZIP? | **YES** — embed `MANIFEST.sha256` in all channels for cross-channel parity | High |
| Publish-or-fail-all? | **Draft-release pattern** — build all, draft GitHub Release, publish npm, undraft on success | High |

## Prerequisites Before Implementation

1. **Create `package.json`** — minimal, listing `files` to include in npm package
2. **npm account setup** — register package name `claude-command-centre`, configure trusted publisher
3. **Repository settings** — ensure `id-token: write` and `attestations: write` permissions are available
4. **Tag convention** — decide if version tags (`v1.10.0`) are created by version-bump workflow or manually

## Implementation Effort Estimate

| Item | Effort |
|------|--------|
| `package.json` creation | 1 point |
| npm trusted publisher setup | 1 point (manual, one-time) |
| Release workflow (build + publish + attest) | 3 points |
| `MANIFEST.sha256` generation | 1 point (part of release workflow) |
| End-to-end testing (dry-run publish) | 2 points |
| **Total** | **8 points** |

---

## References

- [npm Provenance Documentation](https://docs.npmjs.com/generating-provenance-statements/)
- [npm Trusted Publishing with OIDC (GA announcement)](https://github.blog/changelog/2025-07-31-npm-trusted-publishing-with-oidc-is-generally-available/)
- [GitHub Artifact Attestations](https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations)
- [GitHub Release Asset Digests (GA)](https://github.blog/changelog/2025-06-03-releases-now-expose-digests-for-release-assets/)
- [actions/attest-build-provenance](https://github.com/actions/attest-build-provenance)
- [Sigstore](https://www.sigstore.dev/)
- [SLSA Framework](https://slsa.dev/)
- ADR-001: Plugin Distribution Architecture (`docs/adr/001-plugin-distribution.md`)
- CIA-751: 5-persona debate synthesis (source of this spike)
