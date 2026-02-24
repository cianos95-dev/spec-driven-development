#!/usr/bin/env bash
# test-delivery-verification.sh — CIA-718
#
# Tests for the dispatch delivery verification layer in scripts/dispatch-server.js.
# Validates quality check logic, comment formatting, and HTTP endpoint behaviour.
#
# Run: bash tests/test-delivery-verification.sh
# Requires: node (>= 18)
#
# Exit codes: 0 = all pass, 1 = one or more failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVER_SCRIPT="$PLUGIN_ROOT/scripts/dispatch-server.js"

PASS=0
FAIL=0
TOTAL=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

pass() {
    local test_name="$1"
    TOTAL=$((TOTAL + 1))
    PASS=$((PASS + 1))
    echo "  PASS: $test_name"
}

fail() {
    local test_name="$1"
    local detail="${2:-}"
    TOTAL=$((TOTAL + 1))
    FAIL=$((FAIL + 1))
    if [[ -n "$detail" ]]; then
        echo "  FAIL: $test_name ($detail)"
    else
        echo "  FAIL: $test_name"
    fi
}

# Run a Node.js snippet that imports the server module and outputs JSON results.
# Usage: run_node_test "js code that calls console.log(JSON.stringify(result))"
run_node_test() {
    local code="$1"
    node --input-type=module <<EOF
import {
  parseDispatchResult,
  countSubstantiveWords,
  detectErrors,
  calcErrorRatio,
  qualityCheck,
  formatPassComment,
  formatFailComment,
  verifyAndFormat
} from '$SERVER_SCRIPT';

$code
EOF
}

# ---------------------------------------------------------------------------
# Preconditions
# ---------------------------------------------------------------------------

echo ""
echo "=== Delivery Verification Tests (CIA-718) ==="
echo ""

if [[ ! -f "$SERVER_SCRIPT" ]]; then
    echo "ERROR: dispatch-server.js not found at $SERVER_SCRIPT"
    exit 1
fi

if ! command -v node &>/dev/null; then
    echo "ERROR: node is required"
    exit 1
fi

# ===================================================================
echo "--- Test Group 1: parseDispatchResult ---"
echo ""
# ===================================================================

# Test 1.1: Parse JSON with response field
RESULT=$(run_node_test '
const r = parseDispatchResult(JSON.stringify({ response: "Hello world", duration: 10 }));
console.log(JSON.stringify({ resp: r.response, hasStat: r.stats !== null }));
')
if echo "$RESULT" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); process.exit(d.resp==='Hello world' && d.hasStat ? 0 : 1)"; then
    pass "Parse JSON with response field"
else
    fail "Parse JSON with response field" "got: $RESULT"
fi

# Test 1.2: Parse plain text (non-JSON)
RESULT=$(run_node_test '
const r = parseDispatchResult("This is plain text output from an agent");
console.log(JSON.stringify({ resp: r.response, stats: r.stats }));
')
if echo "$RESULT" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); process.exit(d.resp.includes('plain text') && d.stats===null ? 0 : 1)"; then
    pass "Parse plain text (non-JSON)"
else
    fail "Parse plain text (non-JSON)" "got: $RESULT"
fi

# Test 1.3: Parse empty/null input
RESULT=$(run_node_test '
const r = parseDispatchResult("");
console.log(JSON.stringify({ resp: r.response, stats: r.stats }));
')
if echo "$RESULT" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); process.exit(d.resp==='' && d.stats===null ? 0 : 1)"; then
    pass "Parse empty input"
else
    fail "Parse empty input" "got: $RESULT"
fi

# Test 1.4: Parse JSON with output field (fallback)
RESULT=$(run_node_test '
const r = parseDispatchResult(JSON.stringify({ output: "Fallback output", tokens: 500 }));
console.log(JSON.stringify({ resp: r.response, tokens: r.stats?.tokens }));
')
if echo "$RESULT" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); process.exit(d.resp==='Fallback output' && d.tokens===500 ? 0 : 1)"; then
    pass "Parse JSON with output field fallback"
else
    fail "Parse JSON with output field fallback" "got: $RESULT"
fi

echo ""

# ===================================================================
echo "--- Test Group 2: countSubstantiveWords ---"
echo ""
# ===================================================================

# Test 2.1: Count words in normal prose
RESULT=$(run_node_test '
const text = "The quick brown fox jumps over the lazy dog and runs through the meadow picking flowers along the way stopping to smell each one carefully before moving on to the next beautiful bloom in the garden of eternal spring where butterflies dance freely among the petals and the sun shines warmly on all creatures great and small who inhabit this wonderful magical place full of joy and wonder and happiness for everyone who visits";
console.log(countSubstantiveWords(text));
')
if [[ "$RESULT" -gt 50 ]]; then
    pass "Count substantive words in prose ($RESULT words)"
else
    fail "Count substantive words in prose" "expected >50, got $RESULT"
fi

# Test 2.2: Filter out stack traces
RESULT=$(run_node_test '
const text = "  at Object.run (index.js:42:10)\n  at processTicksAndRejections\n  at async main";
console.log(countSubstantiveWords(text));
')
if [[ "$RESULT" -eq 0 ]]; then
    pass "Filter out stack traces (0 words)"
else
    fail "Filter out stack traces" "expected 0, got $RESULT"
fi

# Test 2.3: Filter out JSON key-value lines
RESULT=$(run_node_test '
const text = "  \"statusCode\": 429,\n  \"message\": \"rate limited\",\n  \"retryAfter\": 30";
console.log(countSubstantiveWords(text));
')
if [[ "$RESULT" -eq 0 ]]; then
    pass "Filter out JSON key-value lines (0 words)"
else
    fail "Filter out JSON key-value lines" "expected 0, got $RESULT"
fi

echo ""

# ===================================================================
echo "--- Test Group 3: detectErrors ---"
echo ""
# ===================================================================

# Test 3.1: Detect 429 error
RESULT=$(run_node_test '
console.log(JSON.stringify(detectErrors("Error: 429 Too Many Requests")));
')
if echo "$RESULT" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); process.exit(d.length>=1 ? 0 : 1)"; then
    pass "Detect 429 error indicator"
else
    fail "Detect 429 error indicator" "got: $RESULT"
fi

# Test 3.2: Detect RESOURCE_EXHAUSTED
RESULT=$(run_node_test '
console.log(JSON.stringify(detectErrors("google.api.errors: RESOURCE_EXHAUSTED")));
')
if echo "$RESULT" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); process.exit(d.includes('RESOURCE_EXHAUSTED') ? 0 : 1)"; then
    pass "Detect RESOURCE_EXHAUSTED"
else
    fail "Detect RESOURCE_EXHAUSTED" "got: $RESULT"
fi

# Test 3.3: No errors in clean text
RESULT=$(run_node_test '
console.log(JSON.stringify(detectErrors("The function was implemented successfully and all tests pass.")));
')
if echo "$RESULT" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); process.exit(d.length===0 ? 0 : 1)"; then
    pass "No errors in clean text"
else
    fail "No errors in clean text" "got: $RESULT"
fi

echo ""

# ===================================================================
echo "--- Test Group 4: calcErrorRatio ---"
echo ""
# ===================================================================

# Test 4.1: 50% error ratio
RESULT=$(run_node_test '
console.log(calcErrorRatio({ totalRequests: 10, failedRequests: 5 }));
')
if [[ "$RESULT" == "0.5" ]]; then
    pass "Calculate 50% error ratio"
else
    fail "Calculate 50% error ratio" "expected 0.5, got $RESULT"
fi

# Test 4.2: Null when no stats
RESULT=$(run_node_test '
console.log(calcErrorRatio(null));
')
if [[ "$RESULT" == "null" ]]; then
    pass "Null ratio for missing stats"
else
    fail "Null ratio for missing stats" "expected null, got $RESULT"
fi

echo ""

# ===================================================================
echo "--- Test Group 5: qualityCheck ---"
echo ""
# ===================================================================

# Test 5.1: Passing dispatch (sufficient words, no errors)
RESULT=$(run_node_test '
const longText = Array(120).fill("substantive word here now").join(" ");
const result = { response: longText, stats: { totalRequests: 10, failedRequests: 1 }, raw: longText };
const check = qualityCheck(result);
console.log(JSON.stringify({ pass: check.pass }));
')
if echo "$RESULT" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); process.exit(d.pass ? 0 : 1)"; then
    pass "Quality check PASS for good output"
else
    fail "Quality check PASS for good output" "got: $RESULT"
fi

# Test 5.2: Failing dispatch (too few words)
RESULT=$(run_node_test '
const result = { response: "Error 429", stats: null, raw: "Error 429" };
const check = qualityCheck(result);
console.log(JSON.stringify({ pass: check.pass, reason: check.reason }));
')
if echo "$RESULT" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); process.exit(!d.pass ? 0 : 1)"; then
    pass "Quality check FAIL for sparse output"
else
    fail "Quality check FAIL for sparse output" "got: $RESULT"
fi

# Test 5.3: Failing dispatch (high error ratio)
RESULT=$(run_node_test '
const longText = Array(120).fill("substantive word here now").join(" ");
const result = { response: longText, stats: { totalRequests: 10, failedRequests: 8 }, raw: longText };
const check = qualityCheck(result);
console.log(JSON.stringify({ pass: check.pass }));
')
if echo "$RESULT" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); process.exit(!d.pass ? 0 : 1)"; then
    pass "Quality check FAIL for high error ratio"
else
    fail "Quality check FAIL for high error ratio" "got: $RESULT"
fi

echo ""

# ===================================================================
echo "--- Test Group 6: Comment Formatting ---"
echo ""
# ===================================================================

# Test 6.1: Pass comment contains issue ID and response
RESULT=$(run_node_test '
const result = { response: "Found 3 issues in the codebase.", stats: { duration: 42, tokens: 1500 }, raw: "" };
const check = { pass: true, reason: "OK", details: {} };
const comment = formatPassComment("CIA-718", result, check);
const ok = comment.includes("Dispatch Results — CIA-718") && comment.includes("Found 3 issues");
console.log(ok);
')
if [[ "$RESULT" == "true" ]]; then
    pass "Pass comment format"
else
    fail "Pass comment format" "got: $RESULT"
fi

# Test 6.2: Fail comment contains warning header and recommendation
RESULT=$(run_node_test '
const result = { response: "429 error", stats: { duration: 5, tokens: 200, failedRequests: 8, totalRequests: 10 }, raw: "429 error trace..." };
const check = { pass: false, reason: "High error ratio", details: { errorIndicators: ["429"] } };
const comment = formatFailComment("CIA-718", result, check);
const ok = comment.includes("Dispatch Failed — CIA-718")
  && comment.includes("Re-dispatch to Tembo")
  && comment.includes("Full execution log");
console.log(ok);
')
if [[ "$RESULT" == "true" ]]; then
    pass "Fail comment format"
else
    fail "Fail comment format" "got: $RESULT"
fi

echo ""

# ===================================================================
echo "--- Test Group 7: verifyAndFormat end-to-end ---"
echo ""
# ===================================================================

# Test 7.1: Mock failed Gemini output → failure comment
RESULT=$(run_node_test '
const geminiOutput = JSON.stringify({
  response: "Error: 429 RESOURCE_EXHAUSTED",
  duration: 3,
  tokens: 50,
  requests: 5,
  errors: 5,
  error: "RESOURCE_EXHAUSTED: Quota exceeded for model"
});
const v = verifyAndFormat("CIA-718", geminiOutput);
console.log(JSON.stringify({ pass: v.pass, hasWarning: v.comment.includes("⚠️"), hasRecommendation: v.comment.includes("Re-dispatch") }));
')
if echo "$RESULT" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); process.exit(!d.pass && d.hasWarning && d.hasRecommendation ? 0 : 1)"; then
    pass "End-to-end: failed Gemini output → failure comment"
else
    fail "End-to-end: failed Gemini output → failure comment" "got: $RESULT"
fi

# Test 7.2: Mock successful dispatch → pass comment
RESULT=$(run_node_test '
const findings = "The implementation was reviewed and the following findings were identified. " +
  "First, the authentication module lacks proper input validation on the email field which could " +
  "allow malicious payloads to bypass security controls. Second, the session management does not " +
  "implement proper token rotation which means long-lived sessions could be compromised by attackers " +
  "who gain access to stored credentials. Third, the database queries in the user controller use " +
  "string concatenation instead of parameterized queries, creating potential vulnerabilities in the " +
  "data access layer. Fourth, response messages expose internal stack traces to the client which " +
  "leaks implementation details and framework versions to potential adversaries. Fifth, the logging " +
  "configuration writes sensitive user data to plaintext files without redaction which violates " +
  "data protection requirements. Recommendation: address these five issues before the next release " +
  "and ensure comprehensive regression testing covers each remediation.";
const successOutput = JSON.stringify({
  response: findings,
  duration: 120,
  tokens: 5000,
  requests: 10,
  errors: 0
});
const v = verifyAndFormat("CIA-700", successOutput);
console.log(JSON.stringify({ pass: v.pass, hasTitle: v.comment.includes("Dispatch Results — CIA-700") }));
')
if echo "$RESULT" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); process.exit(d.pass && d.hasTitle ? 0 : 1)"; then
    pass "End-to-end: successful dispatch → pass comment"
else
    fail "End-to-end: successful dispatch → pass comment" "got: $RESULT"
fi

# Test 7.3: Mock raw 429 trace (non-JSON) → failure comment
RESULT=$(run_node_test '
const rawTrace = "HTTP 429 Too Many Requests\nRetry-After: 60\nrate limit exceeded for model gemini-2.5-pro";
const v = verifyAndFormat("CIA-500", rawTrace);
console.log(JSON.stringify({ pass: v.pass }));
')
if echo "$RESULT" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); process.exit(!d.pass ? 0 : 1)"; then
    pass "End-to-end: raw 429 trace → failure"
else
    fail "End-to-end: raw 429 trace → failure" "got: $RESULT"
fi

echo ""

# ===================================================================
echo "--- Test Group 8: HTTP Endpoint ---"
echo ""
# ===================================================================

# Start server in background
DISPATCH_PORT=0  # Use port 0 to let OS pick a free port
export DISPATCH_PORT

# Start the server and capture the port
SERVER_LOG=$(mktemp)
node -e "
import { server } from '$SERVER_SCRIPT';
server.listen(0, () => {
  const port = server.address().port;
  console.log('PORT:' + port);
  // Keep alive for tests
});
" > "$SERVER_LOG" 2>&1 &
SERVER_PID=$!

# Wait for server to start
sleep 1

if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    fail "Server start" "server exited prematurely"
    cat "$SERVER_LOG"
else
    # Extract port
    SERVER_PORT=$(sed -n 's/^PORT:\([0-9]*\)$/\1/p' "$SERVER_LOG" | head -1)

    if [[ -z "$SERVER_PORT" ]]; then
        fail "Server port detection" "could not detect port from log"
        cat "$SERVER_LOG"
    else
        # Test 8.1: Health check
        HEALTH=$(curl -s "http://localhost:$SERVER_PORT/health" 2>/dev/null || true)
        if echo "$HEALTH" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); process.exit(d.status==='ok' ? 0 : 1)" 2>/dev/null; then
            pass "HTTP GET /health"
        else
            fail "HTTP GET /health" "got: $HEALTH"
        fi

        # Test 8.2: POST /linear-update with failing output
        RESPONSE=$(curl -s -X POST "http://localhost:$SERVER_PORT/linear-update" \
            -H "Content-Type: application/json" \
            -d '{"issueId":"CIA-718","output":"{\"response\":\"429 error\",\"errors\":5,\"requests\":5}"}' 2>/dev/null || true)
        if echo "$RESPONSE" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); process.exit(d.pass===false && d.comment.includes('Dispatch Failed') ? 0 : 1)" 2>/dev/null; then
            pass "HTTP POST /linear-update (fail case)"
        else
            fail "HTTP POST /linear-update (fail case)" "got: $RESPONSE"
        fi

        # Test 8.3: POST /linear-update missing fields
        RESPONSE=$(curl -s -X POST "http://localhost:$SERVER_PORT/linear-update" \
            -H "Content-Type: application/json" \
            -d '{"issueId":"CIA-718"}' 2>/dev/null || true)
        if echo "$RESPONSE" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); process.exit(d.error ? 0 : 1)" 2>/dev/null; then
            pass "HTTP POST /linear-update (missing output field → 400)"
        else
            fail "HTTP POST /linear-update (missing output field)" "got: $RESPONSE"
        fi

        # Test 8.4: 404 for unknown routes
        RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$SERVER_PORT/nonexistent" 2>/dev/null || true)
        if [[ "$RESPONSE" == "404" ]]; then
            pass "HTTP 404 for unknown route"
        else
            fail "HTTP 404 for unknown route" "expected 404, got $RESPONSE"
        fi
    fi

    # Cleanup
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
fi

rm -f "$SERVER_LOG"

echo ""

# ===================================================================
echo "==========================================="
echo "  Results: $PASS passed, $FAIL failed ($TOTAL total)"
echo "==========================================="
echo ""

if [[ $FAIL -gt 0 ]]; then
    echo "FAILED: $FAIL check(s) did not pass."
    exit 1
else
    echo "ALL CHECKS PASSED."
    exit 0
fi
