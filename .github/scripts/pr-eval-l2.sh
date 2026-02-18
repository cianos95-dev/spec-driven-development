#!/usr/bin/env bash
# L2: Acceptance Criteria Adherence Scoring
#
# Reads the linked Linear issue's ACs from the PR body (Closes CIA-XXX),
# fetches them via Linear API, compares against PR diff using GitHub Models API,
# and produces a star-graded quality score.
#
# Required env vars:
#   GITHUB_TOKEN   — GitHub token (automatic in Actions, also used for Models API)
#   LINEAR_API_KEY — Linear API key (repo secret)
#   PR_NUMBER      — Pull request number
#   REPO_OWNER     — Repository owner
#   REPO_NAME      — Repository name
#
# Outputs (via GITHUB_OUTPUT):
#   total_score, star_grade, grade_label, issue_id
#
# Artifacts:
#   /tmp/pr-eval-results.json — full scoring details
#   /tmp/pr-eval-summary.json — summary for comment script

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
MAX_DIFF_CHARS=100000
NEUTRAL_SCORE=70
MODELS_API_URL="https://models.github.ai/inference/chat/completions"
MODEL_ID="openai/gpt-4o-mini"

# Star grade thresholds (from CCC quality-scoring skill)
# 90-100: Exemplary (5 stars)
# 80-89:  Strong (4 stars)
# 70-79:  Acceptable (3 stars)
# 60-69:  Needs Work (2 stars)
# <60:    Inadequate (1 star)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() { echo "[L2] $*"; }
warn() { echo "::warning::[L2] $*"; }
err()  { echo "::error::[L2] $*"; }

score_to_stars() {
    local score=$1
    if   (( score >= 90 )); then echo "5"
    elif (( score >= 80 )); then echo "4"
    elif (( score >= 70 )); then echo "3"
    elif (( score >= 60 )); then echo "2"
    else echo "1"
    fi
}

score_to_label() {
    local score=$1
    if   (( score >= 90 )); then echo "Exemplary"
    elif (( score >= 80 )); then echo "Strong"
    elif (( score >= 70 )); then echo "Acceptable"
    elif (( score >= 60 )); then echo "Needs Work"
    else echo "Inadequate"
    fi
}

stars_display() {
    local count=$1
    local stars=""
    for ((i=0; i<count; i++)); do stars+="★"; done
    echo "$stars"
}

write_neutral_result() {
    local reason="$1"
    local issue_id="${2:-unknown}"
    log "Neutral score: $reason"

    cat > /tmp/pr-eval-results.json <<EOF
{
  "issue_id": "$issue_id",
  "total_score": $NEUTRAL_SCORE,
  "test_score": $NEUTRAL_SCORE,
  "coverage_score": $NEUTRAL_SCORE,
  "review_score": $NEUTRAL_SCORE,
  "star_count": $(score_to_stars $NEUTRAL_SCORE),
  "star_grade": "$(stars_display "$(score_to_stars $NEUTRAL_SCORE)")",
  "grade_label": "$(score_to_label $NEUTRAL_SCORE)",
  "skip_reason": "$reason",
  "per_ac": [],
  "gaps": []
}
EOF

    cat > /tmp/pr-eval-summary.json <<EOF
{
  "issue_id": "$issue_id",
  "total_score": $NEUTRAL_SCORE,
  "skip_reason": "$reason"
}
EOF

    # Set outputs
    {
        echo "total_score=$NEUTRAL_SCORE"
        echo "star_grade=$(stars_display "$(score_to_stars $NEUTRAL_SCORE)")"
        echo "grade_label=$(score_to_label $NEUTRAL_SCORE)"
        echo "issue_id=$issue_id"
    } >> "$GITHUB_OUTPUT"
}

# ---------------------------------------------------------------------------
# Step 1: Extract CIA-XXX from PR body
# ---------------------------------------------------------------------------
log "Fetching PR #$PR_NUMBER body..."

PR_BODY=$(curl -sf \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/pulls/$PR_NUMBER" \
    | jq -r '.body // ""')

if [[ -z "$PR_BODY" ]]; then
    write_neutral_result "PR body is empty — no linked issue found"
    exit 0
fi

# Match patterns: "Closes CIA-XXX", "closes CIA-XXX", "CIA-XXX" in title/body
ISSUE_ID=$(echo "$PR_BODY" | grep -oiE 'CIA-[0-9]+' | head -1 || true)

if [[ -z "$ISSUE_ID" ]]; then
    write_neutral_result "No CIA-XXX issue ID found in PR body"
    exit 0
fi

log "Linked issue: $ISSUE_ID"

# ---------------------------------------------------------------------------
# Step 2: Fetch issue from Linear API
# ---------------------------------------------------------------------------
if [[ -z "${LINEAR_API_KEY:-}" ]]; then
    write_neutral_result "LINEAR_API_KEY not configured — cannot fetch ACs" "$ISSUE_ID"
    exit 0
fi

log "Fetching $ISSUE_ID from Linear..."

LINEAR_RESPONSE=$(curl -sf \
    -H "Authorization: $LINEAR_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"query\": \"{ issueSearch(filter: { identifier: { eq: \\\"$ISSUE_ID\\\" } }) { nodes { identifier title description } } }\"}" \
    "https://api.linear.app/graphql" 2>/dev/null || echo '{"error": true}')

if echo "$LINEAR_RESPONSE" | jq -e '.error' &>/dev/null && [[ "$(echo "$LINEAR_RESPONSE" | jq -r '.error')" != "null" ]]; then
    warn "Linear API error — falling back to neutral score"
    write_neutral_result "Linear API request failed" "$ISSUE_ID"
    exit 0
fi

ISSUE_DESC=$(echo "$LINEAR_RESPONSE" | jq -r '.data.issueSearch.nodes[0].description // ""')

if [[ -z "$ISSUE_DESC" ]]; then
    write_neutral_result "Issue $ISSUE_ID has no description" "$ISSUE_ID"
    exit 0
fi

# Extract acceptance criteria (lines matching - [ ] pattern)
AC_LIST=$(echo "$ISSUE_DESC" | grep -E '^\s*-\s*\[[ x]\]' || true)

if [[ -z "$AC_LIST" ]]; then
    write_neutral_result "No acceptance criteria found in $ISSUE_ID description" "$ISSUE_ID"
    exit 0
fi

AC_COUNT=$(echo "$AC_LIST" | wc -l | tr -d ' ')
log "Found $AC_COUNT acceptance criteria"

# ---------------------------------------------------------------------------
# Step 3: Get PR diff
# ---------------------------------------------------------------------------
log "Fetching PR diff..."

PR_FILES=$(curl -sf \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/pulls/$PR_NUMBER/files?per_page=100")

# Concatenate patches into a single diff
DIFF=$(echo "$PR_FILES" | jq -r '.[].patch // "" ' | head -c "$MAX_DIFF_CHARS")

if [[ -z "$DIFF" ]]; then
    write_neutral_result "PR diff is empty" "$ISSUE_ID"
    exit 0
fi

DIFF_SIZE=${#DIFF}
log "Diff size: $DIFF_SIZE chars (max: $MAX_DIFF_CHARS)"

TRUNCATED="false"
if (( DIFF_SIZE >= MAX_DIFF_CHARS )); then
    TRUNCATED="true"
    warn "Diff truncated to $MAX_DIFF_CHARS chars"
fi

# Also get the list of changed files for context
CHANGED_FILES=$(echo "$PR_FILES" | jq -r '.[].filename' | sort)

# ---------------------------------------------------------------------------
# Step 4: Build LLM prompt and call GitHub Models API
# ---------------------------------------------------------------------------
log "Calling GitHub Models API for scoring..."

# Escape special chars for JSON embedding
AC_LIST_ESCAPED=$(echo "$AC_LIST" | jq -Rsa .)
DIFF_ESCAPED=$(echo "$DIFF" | jq -Rsa .)
FILES_ESCAPED=$(echo "$CHANGED_FILES" | jq -Rsa .)

SYSTEM_PROMPT="You are a PR quality evaluator for the Claude Command Centre project.
Score this pull request against the linked Linear issue's acceptance criteria.

Use these three scoring dimensions (from the CCC quality-scoring rubric):

1. Test (40% weight): Are there tests or test-related changes for the acceptance criteria? Look for test files, test scripts, CI workflow additions, or validation logic. Score 0-100.
2. Coverage (30% weight): Is each acceptance criterion addressed in the PR diff? Check for explicit implementation of each AC item. Score 0-100.
3. Review (30% weight): Is the code well-structured, are edge cases handled, and does the implementation follow good practices? Since no prior review data exists, assess code quality directly. Score 0-100.

IMPORTANT: Return ONLY valid JSON. No markdown, no explanation, no code fences."

USER_PROMPT="## Acceptance Criteria
$AC_LIST

## Changed Files
$CHANGED_FILES

## PR Diff
$DIFF

## Required JSON Output Format
{
  \"test_score\": <0-100>,
  \"coverage_score\": <0-100>,
  \"review_score\": <0-100>,
  \"per_ac\": [
    {\"ac\": \"criterion text (without checkbox)\", \"addressed\": true or false, \"evidence\": \"brief explanation of where/how it's addressed\"}
  ],
  \"gaps\": [\"description of each gap or missing item\"]
}"

REQUEST_BODY=$(jq -n \
    --arg model "$MODEL_ID" \
    --arg system "$SYSTEM_PROMPT" \
    --arg user "$USER_PROMPT" \
    '{
        model: $model,
        messages: [
            { role: "system", content: $system },
            { role: "user", content: $user }
        ],
        temperature: 0.1,
        max_tokens: 4096
    }')

LLM_RESPONSE=$(curl -sf \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$REQUEST_BODY" \
    "$MODELS_API_URL" 2>/dev/null || echo '{"error": true}')

# Check for API error
if echo "$LLM_RESPONSE" | jq -e '.error' &>/dev/null && [[ "$(echo "$LLM_RESPONSE" | jq -r '.error')" != "null" ]]; then
    ERRMSG=$(echo "$LLM_RESPONSE" | jq -r '.error.message // .error // "unknown"')
    warn "GitHub Models API error: $ERRMSG"
    write_neutral_result "LLM API call failed: $ERRMSG" "$ISSUE_ID"
    exit 0
fi

# Extract the LLM's JSON response
RAW_CONTENT=$(echo "$LLM_RESPONSE" | jq -r '.choices[0].message.content // ""')

if [[ -z "$RAW_CONTENT" ]]; then
    warn "LLM returned empty response"
    write_neutral_result "LLM returned empty response" "$ISSUE_ID"
    exit 0
fi

# Strip markdown code fences if the model wrapped the JSON
CLEANED_CONTENT=$(echo "$RAW_CONTENT" | sed 's/^```json//;s/^```//;s/```$//' | tr -d '\r')

# Parse and validate LLM output
SCORES=$(echo "$CLEANED_CONTENT" | jq '{
    test_score: (.test_score // 70),
    coverage_score: (.coverage_score // 70),
    review_score: (.review_score // 70),
    per_ac: (.per_ac // []),
    gaps: (.gaps // [])
}' 2>/dev/null || echo '{"test_score":70,"coverage_score":70,"review_score":70,"per_ac":[],"gaps":["LLM output parsing failed"]}')

# ---------------------------------------------------------------------------
# Step 5: Calculate total score and map to grade
# ---------------------------------------------------------------------------
TEST_SCORE=$(echo "$SCORES" | jq -r '.test_score')
COVERAGE_SCORE=$(echo "$SCORES" | jq -r '.coverage_score')
REVIEW_SCORE=$(echo "$SCORES" | jq -r '.review_score')

# Clamp scores to 0-100
clamp() { local v=$1; (( v < 0 )) && v=0; (( v > 100 )) && v=100; echo "$v"; }
TEST_SCORE=$(clamp "$TEST_SCORE")
COVERAGE_SCORE=$(clamp "$COVERAGE_SCORE")
REVIEW_SCORE=$(clamp "$REVIEW_SCORE")

# total = (test * 0.40) + (coverage * 0.30) + (review * 0.30)
TOTAL_SCORE=$(( (TEST_SCORE * 40 + COVERAGE_SCORE * 30 + REVIEW_SCORE * 30) / 100 ))

STAR_COUNT=$(score_to_stars "$TOTAL_SCORE")
STAR_GRADE=$(stars_display "$STAR_COUNT")
GRADE_LABEL=$(score_to_label "$TOTAL_SCORE")

log "Scores — Test: $TEST_SCORE, Coverage: $COVERAGE_SCORE, Review: $REVIEW_SCORE"
log "Total: $TOTAL_SCORE ($STAR_GRADE $GRADE_LABEL)"

# ---------------------------------------------------------------------------
# Step 6: Write results
# ---------------------------------------------------------------------------
PER_AC=$(echo "$SCORES" | jq '.per_ac')
GAPS=$(echo "$SCORES" | jq '.gaps')

jq -n \
    --arg issue_id "$ISSUE_ID" \
    --argjson total_score "$TOTAL_SCORE" \
    --argjson test_score "$TEST_SCORE" \
    --argjson coverage_score "$COVERAGE_SCORE" \
    --argjson review_score "$REVIEW_SCORE" \
    --argjson star_count "$STAR_COUNT" \
    --arg star_grade "$STAR_GRADE" \
    --arg grade_label "$GRADE_LABEL" \
    --argjson ac_count "$AC_COUNT" \
    --argjson truncated "$TRUNCATED" \
    --argjson per_ac "$PER_AC" \
    --argjson gaps "$GAPS" \
    '{
        issue_id: $issue_id,
        total_score: $total_score,
        test_score: $test_score,
        coverage_score: $coverage_score,
        review_score: $review_score,
        star_count: $star_count,
        star_grade: $star_grade,
        grade_label: $grade_label,
        ac_count: $ac_count,
        diff_truncated: $truncated,
        per_ac: $per_ac,
        gaps: $gaps
    }' > /tmp/pr-eval-results.json

# Summary for comment script
jq -n \
    --arg issue_id "$ISSUE_ID" \
    --argjson total_score "$TOTAL_SCORE" \
    '{
        issue_id: $issue_id,
        total_score: $total_score
    }' > /tmp/pr-eval-summary.json

# Set GitHub Actions outputs
{
    echo "total_score=$TOTAL_SCORE"
    echo "star_grade=$STAR_GRADE"
    echo "grade_label=$GRADE_LABEL"
    echo "issue_id=$ISSUE_ID"
} >> "$GITHUB_OUTPUT"

log "Results written to /tmp/pr-eval-results.json"
