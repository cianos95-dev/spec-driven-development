#!/usr/bin/env node
/**
 * dispatch-server.js — Dispatch result relay with delivery verification.
 *
 * Receives agent execution output (Gemini, Codex, etc.) and posts formatted
 * comments to Linear issues via MCP. Includes a quality gate that distinguishes
 * successful dispatches from failures (429 errors, empty output, rate limits).
 *
 * Routes:
 *   GET  /health         — Health check
 *   POST /dispatch       — Trigger agent dispatch (passthrough)
 *   POST /linear-update  — Verify dispatch result, format, post to Linear
 *
 * CIA-718
 */

import { createServer } from 'node:http';

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

const PORT = parseInt(process.env.DISPATCH_PORT || '3847', 10);

const ERROR_INDICATORS = [
  '429',
  'RESOURCE_EXHAUSTED',
  'MODEL_CAPACITY_EXHAUSTED',
  'rate limit',
  'Rate limit',
  'RateLimitError',
  'quota exceeded',
  'Too Many Requests',
];

const NOISE_PATTERNS = [
  /^\s*at\s+/,             // stack trace lines
  /^\s*\d+\s*\|/,         // line-number prefixes
  /^[{}\[\],]*$/,          // bare JSON delimiters
  /^\s*"[a-zA-Z_]+"\s*:/, // JSON key-value pairs
  /^\s*Error:/,            // error preamble
  /^\s*Traceback/,         // Python traceback
  /node_modules\//,        // dependency paths
];

const MIN_SUBSTANTIVE_WORDS = 100;
const MAX_ERROR_RATIO = 0.5;

// ---------------------------------------------------------------------------
// Delivery Verification — Core
// ---------------------------------------------------------------------------

/**
 * Parse raw agent stdout into a structured result.
 *
 * Agents may emit JSON with a `response` field, or plain text.
 * Stats (duration, tokens, requests, errors) are extracted when available.
 */
export function parseDispatchResult(raw) {
  if (!raw || typeof raw !== 'string') {
    return { response: '', stats: null, raw: raw || '' };
  }

  // Try to parse top-level JSON
  let parsed = null;
  try {
    parsed = JSON.parse(raw.trim());
  } catch {
    // Not JSON — treat full output as the response
  }

  if (parsed && typeof parsed === 'object') {
    const response = typeof parsed.response === 'string'
      ? parsed.response
      : typeof parsed.output === 'string'
        ? parsed.output
        : typeof parsed.result === 'string'
          ? parsed.result
          : '';

    const stats = extractStats(parsed);
    return { response: response || raw, stats, raw };
  }

  return { response: raw, stats: null, raw };
}

/**
 * Extract execution stats from a parsed JSON object.
 */
function extractStats(obj) {
  if (!obj || typeof obj !== 'object') return null;

  const stats = {};

  // Duration
  if (obj.duration != null) stats.duration = obj.duration;
  else if (obj.durationMs != null) stats.duration = obj.durationMs / 1000;
  else if (obj.elapsed != null) stats.duration = obj.elapsed;

  // Tokens
  if (obj.tokens != null) stats.tokens = obj.tokens;
  else if (obj.totalTokens != null) stats.tokens = obj.totalTokens;
  else if (obj.usage?.total_tokens != null) stats.tokens = obj.usage.total_tokens;

  // Requests
  if (obj.requests != null) stats.totalRequests = obj.requests;
  else if (obj.totalRequests != null) stats.totalRequests = obj.totalRequests;

  // Errors / failed requests
  if (obj.errors != null) stats.failedRequests = obj.errors;
  else if (obj.failedRequests != null) stats.failedRequests = obj.failedRequests;

  // First error message
  if (obj.error) stats.primaryError = String(obj.error);
  else if (Array.isArray(obj.errors) && obj.errors.length > 0) {
    stats.primaryError = String(obj.errors[0]);
  } else if (obj.firstError) stats.primaryError = String(obj.firstError);

  return Object.keys(stats).length > 0 ? stats : null;
}

/**
 * Count substantive words in text, filtering out noise lines.
 */
export function countSubstantiveWords(text) {
  if (!text) return 0;

  const lines = text.split('\n');
  let wordCount = 0;

  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) continue;

    // Skip lines matching noise patterns
    const isNoise = NOISE_PATTERNS.some((pat) => pat.test(trimmed));
    if (isNoise) continue;

    // Count words on this line
    const words = trimmed.split(/\s+/).filter((w) => w.length > 1);
    wordCount += words.length;
  }

  return wordCount;
}

/**
 * Check whether the response contains error indicators.
 */
export function detectErrors(text) {
  if (!text) return [];

  const found = [];
  const lower = text.toLowerCase();

  for (const indicator of ERROR_INDICATORS) {
    if (lower.includes(indicator.toLowerCase())) {
      found.push(indicator);
    }
  }

  return found;
}

/**
 * Calculate error ratio from stats.
 * Returns a number between 0 and 1, or null if stats are unavailable.
 */
export function calcErrorRatio(stats) {
  if (!stats) return null;
  const total = stats.totalRequests;
  const failed = stats.failedRequests;
  if (total == null || total === 0) return null;
  if (failed == null) return null;
  return failed / total;
}

/**
 * Run the quality gate on a parsed dispatch result.
 *
 * Returns { pass: boolean, reason: string, details: object }
 */
export function qualityCheck(result) {
  const { response, stats } = result;

  const wordCount = countSubstantiveWords(response);
  const errorIndicators = detectErrors(response);
  const errorRatio = calcErrorRatio(stats);

  const details = {
    wordCount,
    errorIndicators,
    errorRatio,
    stats,
  };

  // Fail: too few substantive words
  if (wordCount < MIN_SUBSTANTIVE_WORDS) {
    return {
      pass: false,
      reason: `Insufficient content: ${wordCount} substantive words (minimum ${MIN_SUBSTANTIVE_WORDS})`,
      details,
    };
  }

  // Fail: error ratio too high
  if (errorRatio !== null && errorRatio >= MAX_ERROR_RATIO) {
    const pct = Math.round(errorRatio * 100);
    return {
      pass: false,
      reason: `High error ratio: ${pct}% of requests failed (threshold ${MAX_ERROR_RATIO * 100}%)`,
      details,
    };
  }

  // Fail: error indicators dominate (present AND low word count relative to threshold)
  if (errorIndicators.length > 0 && wordCount < MIN_SUBSTANTIVE_WORDS * 2) {
    return {
      pass: false,
      reason: `Error indicators detected: ${errorIndicators.join(', ')}`,
      details,
    };
  }

  return { pass: true, reason: 'OK', details };
}

// ---------------------------------------------------------------------------
// Comment Formatting
// ---------------------------------------------------------------------------

/**
 * Format a Linear comment for a passing dispatch.
 */
export function formatPassComment(issueId, result, checkResult) {
  const { response, stats } = result;

  let comment = `## Dispatch Results — ${issueId}\n\n`;
  comment += response.trim();

  if (stats) {
    comment += '\n\n<details>\n<summary>Execution stats</summary>\n\n';
    if (stats.duration != null) comment += `- **Duration:** ${stats.duration}s\n`;
    if (stats.tokens != null) comment += `- **Tokens:** ${stats.tokens}\n`;
    if (stats.totalRequests != null) comment += `- **Requests:** ${stats.totalRequests}\n`;
    if (stats.failedRequests != null) comment += `- **Errors:** ${stats.failedRequests}\n`;
    comment += '\n</details>';
  }

  return comment;
}

/**
 * Format a Linear comment for a failing dispatch.
 */
export function formatFailComment(issueId, result, checkResult) {
  const { stats, raw } = result;
  const { details } = checkResult;

  const duration = stats?.duration ?? '?';
  const tokens = stats?.tokens ?? '?';
  const failed = stats?.failedRequests ?? '?';
  const total = stats?.totalRequests ?? '?';
  const primaryError = stats?.primaryError
    || (details.errorIndicators.length > 0 ? details.errorIndicators[0] : 'Unknown');

  let comment = `## ⚠️ Dispatch Failed — ${issueId}\n\n`;
  comment += `**Status:** Agent executed but did not produce usable findings.\n`;
  comment += `**Duration:** ${duration}s | **Tokens:** ${tokens} | **Errors:** ${failed} of ${total} requests failed\n`;
  comment += `**Primary error:** ${primaryError}\n\n`;
  comment += `**Recommendation:** Re-dispatch to Tembo or execute manually.\n`;
  comment += `\n<details>\n<summary>Full execution log</summary>\n\n`;
  comment += '```\n' + (raw || '(empty)') + '\n```\n';
  comment += '\n</details>';

  return comment;
}

/**
 * Full pipeline: parse → verify → format.
 */
export function verifyAndFormat(issueId, rawOutput) {
  const result = parseDispatchResult(rawOutput);
  const check = qualityCheck(result);

  const comment = check.pass
    ? formatPassComment(issueId, result, check)
    : formatFailComment(issueId, result, check);

  return { pass: check.pass, reason: check.reason, comment, details: check.details };
}

// ---------------------------------------------------------------------------
// HTTP Server
// ---------------------------------------------------------------------------

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}

function json(res, status, body) {
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(body));
}

const server = createServer(async (req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);

  // GET /health
  if (req.method === 'GET' && url.pathname === '/health') {
    return json(res, 200, { status: 'ok', version: '1.0.0' });
  }

  // POST /linear-update
  if (req.method === 'POST' && url.pathname === '/linear-update') {
    try {
      const body = JSON.parse(await readBody(req));
      const { issueId, output } = body;

      if (!issueId || output == null) {
        return json(res, 400, { error: 'Missing issueId or output' });
      }

      const verification = verifyAndFormat(issueId, output);

      return json(res, 200, {
        issueId,
        pass: verification.pass,
        reason: verification.reason,
        comment: verification.comment,
      });
    } catch (err) {
      return json(res, 400, { error: 'Invalid JSON body', detail: err.message });
    }
  }

  // POST /dispatch (passthrough placeholder)
  if (req.method === 'POST' && url.pathname === '/dispatch') {
    const body = await readBody(req);
    return json(res, 200, { status: 'received', note: 'dispatch routing not yet implemented' });
  }

  // 404
  json(res, 404, { error: 'Not found' });
});

// Only start listening when run directly (not when imported for testing)
if (process.argv[1] && import.meta.url.endsWith(process.argv[1].replace(/\\/g, '/'))) {
  server.listen(PORT, () => {
    console.log(`dispatch-server listening on :${PORT}`);
  });
}

export { server };
