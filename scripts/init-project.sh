#!/usr/bin/env bash
# init-project.sh — Post-template initialization for claudian-platform forks
#
# Renames @claudian/* scope, provisions Doppler, links Vercel & Railway,
# applies GitHub rulesets, and runs initial CI validation.
#
# Usage: ./scripts/init-project.sh <project-name> [options]
#
# Arguments:
#   project-name    Hyphenated project name (e.g. "acme-app")
#
# Options:
#   --scope <name>  npm scope without @ (default: derived from GitHub org)
#   --vercel-team   Vercel team slug (default: current scope)
#   --railway-team  Railway workspace name (default: current workspace)
#   --skip-doppler  Skip Doppler provisioning
#   --skip-vercel   Skip Vercel project linking
#   --skip-railway  Skip Railway project creation
#   --dry-run       Print commands without executing
#
# Prerequisites:
#   - gh CLI authenticated (repo scope)
#   - doppler CLI authenticated (doppler login)
#   - vercel CLI authenticated (vercel login)
#   - railway CLI authenticated (railway login)
#
# Example:
#   ./scripts/init-project.sh acme-app --scope acme
#   # Renames @claudian/* → @acme/*, creates Doppler project, links Vercel & Railway

set -euo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
TEMPLATE_SCOPE="claudian"
TEMPLATE_ORG="cianos95-dev"
TEMPLATE_REPO="claudian-platform"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()   { echo "[init] $*"; }
warn()  { echo "[init] WARNING: $*" >&2; }
error() { echo "[init] ERROR: $*" >&2; exit 1; }

dry_run=false
run() {
  if [ "$dry_run" = true ]; then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}

check_tool() {
  command -v "$1" >/dev/null 2>&1 || error "$1 is required but not installed. See: $2"
}

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
PROJECT_NAME="${1:?Usage: $0 <project-name> [options]}"
shift

NEW_SCOPE=""
VERCEL_TEAM=""
RAILWAY_TEAM=""
SKIP_DOPPLER=false
SKIP_VERCEL=false
SKIP_RAILWAY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope)      NEW_SCOPE="$2"; shift 2 ;;
    --vercel-team) VERCEL_TEAM="$2"; shift 2 ;;
    --railway-team) RAILWAY_TEAM="$2"; shift 2 ;;
    --skip-doppler) SKIP_DOPPLER=true; shift ;;
    --skip-vercel)  SKIP_VERCEL=true; shift ;;
    --skip-railway) SKIP_RAILWAY=true; shift ;;
    --dry-run)      dry_run=true; shift ;;
    *) error "Unknown option: $1" ;;
  esac
done

# Derive scope from GitHub org if not provided
if [ -z "$NEW_SCOPE" ]; then
  REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
  if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/ ]]; then
    NEW_SCOPE="${BASH_REMATCH[1]}"
    log "Derived scope from git remote: @$NEW_SCOPE"
  else
    error "Cannot derive scope. Provide --scope <name> or ensure git remote is set."
  fi
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

log "Project:  $PROJECT_NAME"
log "Scope:    @${TEMPLATE_SCOPE}/* → @${NEW_SCOPE}/*"
log "Repo root: $REPO_ROOT"
echo ""

# ---------------------------------------------------------------------------
# Step 1: Scope rename (@claudian/* → @<new-scope>/*)
# ---------------------------------------------------------------------------
log "=== Step 1: Scope rename ==="

# Files where scope references appear (package.json, tsconfig, imports, configs)
SCOPE_FILES=(
  "package.json"
  "package-lock.json"
  "pnpm-lock.yaml"
  "yarn.lock"
  "tsconfig.json"
  "tsconfig.*.json"
  "next.config.*"
  "turbo.json"
  ".env.example"
  "docker-compose*.yml"
  "Dockerfile*"
)

# Patterns to search in source files
SOURCE_EXTENSIONS="ts,tsx,js,jsx,mjs,cjs,json,yaml,yml,toml,md"

renamed_count=0

# Phase 1: Rename in known config files
for pattern in "${SCOPE_FILES[@]}"; do
  while IFS= read -r -d '' file; do
    if grep -q "@${TEMPLATE_SCOPE}/" "$file" 2>/dev/null; then
      log "  Renaming in: $file"
      if [ "$dry_run" = false ]; then
        # Use perl for reliable in-place replacement (handles edge cases better than sed)
        perl -pi -e "s/\@${TEMPLATE_SCOPE}\//\@${NEW_SCOPE}\//g" "$file"
      fi
      renamed_count=$((renamed_count + 1))
    fi
  done < <(find "$REPO_ROOT" -maxdepth 3 -name "$pattern" -not -path "*/node_modules/*" -not -path "*/.git/*" -print0 2>/dev/null)
done

# Phase 2: Rename in source files (imports, references)
while IFS= read -r -d '' file; do
  if grep -q "@${TEMPLATE_SCOPE}/" "$file" 2>/dev/null; then
    log "  Renaming in: $file"
    if [ "$dry_run" = false ]; then
      perl -pi -e "s/\@${TEMPLATE_SCOPE}\//\@${NEW_SCOPE}\//g" "$file"
    fi
    renamed_count=$((renamed_count + 1))
  fi
done < <(find "$REPO_ROOT/src" "$REPO_ROOT/apps" "$REPO_ROOT/packages" "$REPO_ROOT/libs" \
  -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.mjs" -o -name "*.cjs" \) \
  -not -path "*/node_modules/*" -not -path "*/.git/*" -print0 2>/dev/null || true)

# Phase 3: Also rename the org name in GitHub-specific files
for gh_file in "$REPO_ROOT/.github/workflows/"*.yml "$REPO_ROOT/.github/workflows/"*.yaml; do
  if [ -f "$gh_file" ] && grep -q "${TEMPLATE_ORG}" "$gh_file" 2>/dev/null; then
    CURRENT_ORG=$(git remote get-url origin 2>/dev/null | sed -n 's|.*github\.com[:/]\([^/]*\)/.*|\1|p')
    if [ -n "$CURRENT_ORG" ] && [ "$CURRENT_ORG" != "$TEMPLATE_ORG" ]; then
      log "  Updating org in: $gh_file"
      if [ "$dry_run" = false ]; then
        perl -pi -e "s/${TEMPLATE_ORG}/${CURRENT_ORG}/g" "$gh_file"
      fi
      renamed_count=$((renamed_count + 1))
    fi
  fi
done

log "Scope rename complete: $renamed_count files updated"

# Verification: check for any remaining template references
remaining=$(grep -rl "@${TEMPLATE_SCOPE}/" "$REPO_ROOT" \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
  --include="*.json" --include="*.yaml" --include="*.yml" \
  --exclude-dir=node_modules --exclude-dir=.git 2>/dev/null | wc -l || echo "0")

if [ "$remaining" -gt 0 ]; then
  warn "Found $remaining files still referencing @${TEMPLATE_SCOPE}/:"
  grep -rl "@${TEMPLATE_SCOPE}/" "$REPO_ROOT" \
    --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
    --include="*.json" --include="*.yaml" --include="*.yml" \
    --exclude-dir=node_modules --exclude-dir=.git 2>/dev/null | head -10
  warn "Review these files manually."
else
  log "Verification passed: no remaining @${TEMPLATE_SCOPE}/ references"
fi

echo ""

# ---------------------------------------------------------------------------
# Step 2: Doppler project provisioning
# ---------------------------------------------------------------------------
if [ "$SKIP_DOPPLER" = false ]; then
  log "=== Step 2: Doppler provisioning ==="
  check_tool "doppler" "https://docs.doppler.com/docs/install-cli"

  DOPPLER_PROJECT="$PROJECT_NAME"

  # Check if doppler-template.yaml exists (preferred path)
  if [ -f "$REPO_ROOT/doppler-template.yaml" ]; then
    log "Found doppler-template.yaml — importing project template"
    run doppler import --template "$REPO_ROOT/doppler-template.yaml"
    log "Doppler project imported from template"
  else
    # Fallback: create project manually via CLI
    log "Creating Doppler project: $DOPPLER_PROJECT"
    if doppler projects get "$DOPPLER_PROJECT" >/dev/null 2>&1; then
      log "Doppler project '$DOPPLER_PROJECT' already exists, skipping creation"
    else
      run doppler projects create "$DOPPLER_PROJECT" --description "Secrets for $PROJECT_NAME"
    fi
  fi

  # Setup local directory scoping
  log "Scoping Doppler to $DOPPLER_PROJECT/dev for this directory"
  run doppler setup --project "$DOPPLER_PROJECT" --config dev --no-interactive

  log "Doppler provisioning complete"
  log "  Project: $DOPPLER_PROJECT"
  log "  Environments: dev, stg, prd (default)"
  log "  Next: Add secrets via 'doppler secrets set KEY=VALUE' or Doppler dashboard"
else
  log "=== Step 2: Doppler provisioning (SKIPPED) ==="
fi

echo ""

# ---------------------------------------------------------------------------
# Step 3: Vercel project linking
# ---------------------------------------------------------------------------
if [ "$SKIP_VERCEL" = false ]; then
  log "=== Step 3: Vercel project linking ==="
  check_tool "vercel" "https://vercel.com/docs/cli"

  VERCEL_PROJECT="$PROJECT_NAME"
  VERCEL_SCOPE_ARG=""
  if [ -n "$VERCEL_TEAM" ]; then
    VERCEL_SCOPE_ARG="--scope=$VERCEL_TEAM"
  fi

  # Link project (creates if it doesn't exist)
  log "Linking Vercel project: $VERCEL_PROJECT"
  run vercel link --yes --project="$VERCEL_PROJECT" $VERCEL_SCOPE_ARG

  # Pull environment variables from Vercel (seeds .vercel/project.json)
  log "Pulling Vercel environment config"
  run vercel env pull --yes .env.local 2>/dev/null || true

  # Extract project ID for CI use
  if [ -f "$REPO_ROOT/.vercel/project.json" ]; then
    VERCEL_PROJECT_ID=$(jq -r '.projectId' "$REPO_ROOT/.vercel/project.json")
    VERCEL_ORG_ID=$(jq -r '.orgId' "$REPO_ROOT/.vercel/project.json")
    log "Vercel linked successfully"
    log "  Project ID: $VERCEL_PROJECT_ID"
    log "  Org ID:     $VERCEL_ORG_ID"
    log "  Tip: Add VERCEL_PROJECT_ID and VERCEL_ORG_ID as GitHub secrets for CI"
  fi

  log "Vercel project linking complete"
else
  log "=== Step 3: Vercel project linking (SKIPPED) ==="
fi

echo ""

# ---------------------------------------------------------------------------
# Step 4: Railway project creation
# ---------------------------------------------------------------------------
if [ "$SKIP_RAILWAY" = false ]; then
  log "=== Step 4: Railway project creation ==="
  check_tool "railway" "https://docs.railway.com/guides/cli"

  RAILWAY_PROJECT="$PROJECT_NAME"

  # Create project
  log "Creating Railway project: $RAILWAY_PROJECT"
  RAILWAY_INIT_OUTPUT=$(run railway init --name "$RAILWAY_PROJECT" 2>&1 || true)
  echo "$RAILWAY_INIT_OUTPUT"

  # Link to the project
  log "Linking Railway project"
  run railway link 2>/dev/null || log "  (link requires interactive selection — run 'railway link' manually)"

  log "Railway project creation complete"
  log "  Next: Deploy with 'railway up' or connect GitHub repo in Railway dashboard"
  log "  Tip: Create a RAILWAY_TOKEN project token and add as GitHub secret for CI"
else
  log "=== Step 4: Railway project creation (SKIPPED) ==="
fi

echo ""

# ---------------------------------------------------------------------------
# Step 5: GitHub repository setup
# ---------------------------------------------------------------------------
log "=== Step 5: GitHub repository setup ==="
check_tool "gh" "https://cli.github.com/"

CURRENT_REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || echo "")
if [ -n "$CURRENT_REPO" ]; then
  # Apply rulesets if they exist
  RULESETS_DIR="$REPO_ROOT/.github/rulesets"
  if [ -d "$RULESETS_DIR" ]; then
    for ruleset in "$RULESETS_DIR"/*.json; do
      [ -f "$ruleset" ] || continue
      name=$(basename "$ruleset" .json)
      log "  Applying ruleset: $name"
      run gh api "repos/$CURRENT_REPO/rulesets" --input "$ruleset" 2>/dev/null || {
        warn "Failed to apply ruleset $name (may already exist)"
      }
    done
  fi

  # Set required secrets reminder
  log ""
  log "Required GitHub secrets (set via 'gh secret set'):"
  log "  PAT_TOKEN         — Personal access token (for version bump workflow)"
  log "  LINEAR_API_KEY    — Linear API key (for PR eval L2 scoring)"
  log "  DOPPLER_TOKEN     — Doppler service token (for CI secret injection)"
  if [ "$SKIP_VERCEL" = false ]; then
    log "  VERCEL_TOKEN      — Vercel deploy token"
    log "  VERCEL_ORG_ID     — Vercel organization ID"
    log "  VERCEL_PROJECT_ID — Vercel project ID"
  fi
  if [ "$SKIP_RAILWAY" = false ]; then
    log "  RAILWAY_TOKEN     — Railway project token"
  fi
else
  warn "Not in a GitHub repo — skipping repository setup"
fi

echo ""

# ---------------------------------------------------------------------------
# Step 6: Verification
# ---------------------------------------------------------------------------
log "=== Step 6: Verification ==="

CHECKS_PASSED=0
CHECKS_TOTAL=0

# Check: scope rename
CHECKS_TOTAL=$((CHECKS_TOTAL + 1))
remaining=$(grep -rl "@${TEMPLATE_SCOPE}/" "$REPO_ROOT" \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
  --include="*.json" --include="*.yaml" --include="*.yml" \
  --exclude-dir=node_modules --exclude-dir=.git 2>/dev/null | wc -l || echo "0")
if [ "$remaining" -eq 0 ]; then
  log "  PASS: Scope rename (@${TEMPLATE_SCOPE} → @${NEW_SCOPE})"
  CHECKS_PASSED=$((CHECKS_PASSED + 1))
else
  warn "  FAIL: $remaining files still reference @${TEMPLATE_SCOPE}/"
fi

# Check: Doppler
if [ "$SKIP_DOPPLER" = false ]; then
  CHECKS_TOTAL=$((CHECKS_TOTAL + 1))
  if doppler configs get --project "$PROJECT_NAME" --config dev >/dev/null 2>&1; then
    log "  PASS: Doppler project '$PROJECT_NAME' with dev config exists"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  else
    warn "  FAIL: Doppler project or dev config not found"
  fi
fi

# Check: Vercel
if [ "$SKIP_VERCEL" = false ]; then
  CHECKS_TOTAL=$((CHECKS_TOTAL + 1))
  if [ -f "$REPO_ROOT/.vercel/project.json" ]; then
    log "  PASS: Vercel project linked (.vercel/project.json exists)"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  else
    warn "  FAIL: Vercel project not linked"
  fi
fi

# Check: package.json exists and has correct scope
CHECKS_TOTAL=$((CHECKS_TOTAL + 1))
if [ -f "$REPO_ROOT/package.json" ]; then
  PKG_NAME=$(jq -r '.name // ""' "$REPO_ROOT/package.json")
  if [[ "$PKG_NAME" == @${NEW_SCOPE}/* ]] || [[ "$PKG_NAME" == "$PROJECT_NAME" ]]; then
    log "  PASS: package.json name is '$PKG_NAME'"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  else
    warn "  WARN: package.json name '$PKG_NAME' may need updating"
  fi
else
  log "  SKIP: No package.json found"
  CHECKS_PASSED=$((CHECKS_PASSED + 1))
fi

echo ""
log "Verification: $CHECKS_PASSED/$CHECKS_TOTAL checks passed"

echo ""
log "=========================================="
log "  Init complete for: $PROJECT_NAME"
log "=========================================="
log ""
log "Next steps:"
log "  1. Review changed files:  git diff"
log "  2. Install dependencies:  npm install  (or pnpm install)"
log "  3. Run tests:             npm test"
log "  4. Commit init changes:   git add -A && git commit -m 'chore: init from template'"
log "  5. Push and verify CI:    git push"
