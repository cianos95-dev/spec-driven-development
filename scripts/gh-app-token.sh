#!/usr/bin/env bash
# gh-app-token.sh — Generate a GitHub App installation token for ClaudeGbot
#
# Usage:
#   GH_TOKEN=$(~/.claude/scripts/gh-app-token.sh) gh pr create ...
#   ~/.claude/scripts/gh-app-token.sh              # prints token to stdout
#   ~/.claude/scripts/gh-app-token.sh --verify     # verify token works
#
# Auth flow:
#   1. Read private key from macOS Keychain (claude/github-app-key)
#   2. Generate JWT (RS256, 10-min expiry)
#   3. Exchange JWT for installation token (60-min expiry) via GitHub API
#
# Requirements: openssl, curl, jq
#
# App: ClaudeGbot (App ID: 2901937)
# Installation: cianos95-dev (Installation ID: 111168025)

set -euo pipefail

APP_ID="2901937"
INSTALLATION_ID="111168025"
KEYCHAIN_SERVICE="claude/github-app-key"
KEYCHAIN_ACCOUNT="claudegbot"

# --- Read private key from Keychain ---
# Keychain returns hex-encoded data; decode it
PEM_HEX=$(security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" -w 2>/dev/null) || {
  echo "ERROR: Could not read private key from Keychain." >&2
  echo "Store it with: security add-generic-password -s '$KEYCHAIN_SERVICE' -a '$KEYCHAIN_ACCOUNT' -w \"\$(cat private-key.pem)\" -U" >&2
  exit 1
}

# Decode hex to PEM text
PEM=$(echo "$PEM_HEX" | xxd -r -p)

# Write to a temporary file (openssl needs a file path)
PEM_TMPFILE=$(mktemp /tmp/gh-app-key.XXXXXX)
trap 'rm -f "$PEM_TMPFILE"' EXIT
echo "$PEM" > "$PEM_TMPFILE"
chmod 600 "$PEM_TMPFILE"

# --- Generate JWT ---
NOW=$(date +%s)
IAT=$((NOW - 60))
EXP=$((NOW + 600))  # 10-minute expiry

b64url() {
  openssl base64 -e | tr -d '=' | tr '/+' '_-' | tr -d '\n'
}

HEADER=$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)
PAYLOAD=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' "$IAT" "$EXP" "$APP_ID" | b64url)
SIGNATURE=$(printf '%s.%s' "$HEADER" "$PAYLOAD" | openssl dgst -sha256 -sign "$PEM_TMPFILE" | b64url)

JWT="${HEADER}.${PAYLOAD}.${SIGNATURE}"

# --- Exchange JWT for installation token ---
RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $JWT" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/app/installations/${INSTALLATION_ID}/access_tokens")

TOKEN=$(echo "$RESPONSE" | jq -r '.token // empty')

if [ -z "$TOKEN" ]; then
  echo "ERROR: Failed to get installation token." >&2
  echo "Response: $RESPONSE" >&2
  exit 1
fi

# --- Verify mode ---
if [ "${1:-}" = "--verify" ]; then
  WHOAMI=$(curl -s -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github+json" https://api.github.com/user 2>/dev/null || true)
  # App tokens don't have a "user" but we can check the token works
  RATE=$(curl -s -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github+json" https://api.github.com/rate_limit | jq -r '.rate.limit // "error"')
  REPOS=$(curl -s -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github+json" https://api.github.com/installation/repositories | jq -r '.total_count // "error"')
  EXPIRES=$(echo "$RESPONSE" | jq -r '.expires_at // "unknown"')
  echo "Token valid. Rate limit: $RATE | Repos accessible: $REPOS | Expires: $EXPIRES" >&2
  echo "$TOKEN"
  exit 0
fi

echo "$TOKEN"
