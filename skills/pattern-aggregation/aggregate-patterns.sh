#!/usr/bin/env bash
# aggregate-patterns.sh — CIA-436
#
# Cross-session friction pattern aggregation for the CCC Insights Platform.
# Parses archived insights reports, normalizes friction types, calculates trends,
# and produces a structured patterns.json for downstream consumers.
#
# Usage:
#   bash aggregate-patterns.sh
#   INSIGHTS_DIR=/custom/path bash aggregate-patterns.sh
#
# Requires: jq, bash 3.2+
# Output: $INSIGHTS_DIR/patterns.json
#
# Each run is a full idempotent rebuild. The only preserved state across runs
# is linear_issue_id and triaged_at (via the merge algorithm).

set -uo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

INSIGHTS_DIR="${INSIGHTS_DIR:-$HOME/.claude/insights}"
ARCHIVES_DIR="$INSIGHTS_DIR/archives"
OUTPUT_FILE="$INSIGHTS_DIR/patterns.json"
MAX_TRIAGE_PER_RUN=3

# ---------------------------------------------------------------------------
# Preconditions
# ---------------------------------------------------------------------------

if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is required but not found" >&2
    exit 1
fi

if [[ ! -d "$ARCHIVES_DIR" ]]; then
    echo "WARNING: Archives directory not found at $ARCHIVES_DIR" >&2
    mkdir -p "$ARCHIVES_DIR"
fi

# ---------------------------------------------------------------------------
# Step 1: Read existing patterns.json for merge data
# ---------------------------------------------------------------------------

# Build a jq-compatible merge map from existing patterns.json
MERGE_MAP="{}"
if [[ -f "$OUTPUT_FILE" ]]; then
    MERGE_MAP=$(jq -c '
        reduce (.patterns // [] | .[] | select(.linear_issue_id != null)) as $p
        ({}; . + {($p.type): {linear_issue_id: $p.linear_issue_id, triaged_at: $p.triaged_at}})
    ' "$OUTPUT_FILE" 2>/dev/null || echo "{}")
fi

# ---------------------------------------------------------------------------
# Step 2: Discover and sort archive files
# ---------------------------------------------------------------------------

# Only process files matching YYYY-MM-DD.md pattern
REPORT_FILES=()
for f in "$ARCHIVES_DIR"/*.md; do
    [[ -f "$f" ]] || continue
    fname=$(basename "$f")
    # Match YYYY-MM-DD.md pattern
    if echo "$fname" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}\.md$'; then
        REPORT_FILES+=("$f")
    fi
done

# Sort by filename (ISO date ensures chronological order)
SORTED_FILES=()
if [[ ${#REPORT_FILES[@]} -gt 0 ]]; then
    IFS=$'\n' SORTED_FILES=($(printf '%s\n' "${REPORT_FILES[@]}" | sort))
    unset IFS
fi

# ---------------------------------------------------------------------------
# Step 3: Parse each report
# ---------------------------------------------------------------------------

# Temporary file for building patterns
TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/pattern-agg.XXXXXX")
trap "rm -rf '$TEMP_DIR'" EXIT

# Initialize patterns accumulator as empty JSON object
# Structure: { "type_key": { "display_name": "...", "counts": [n, ...], "dates": ["YYYY-MM-DD", ...] } }
echo '{}' > "$TEMP_DIR/patterns.json"

REPORT_COUNT=0

for report_file in ${SORTED_FILES[@]+"${SORTED_FILES[@]}"}; do
    fname=$(basename "$report_file")
    report_date="${fname%.md}"

    # Read the file content
    content=$(cat "$report_file")

    # Find the friction heading
    # Regex: ^## (Friction Points|Primary Friction Types) — case-insensitive
    heading_line=""
    heading_found=false
    in_table=false
    table_started=false
    separator_seen=false

    # We need to find the heading, then the table after it
    # Process line by line
    found_heading=false
    found_table=false
    table_rows=""

    while IFS= read -r line; do
        if [[ "$found_heading" == false ]]; then
            # Check for heading match (case-insensitive)
            lower_line=$(echo "$line" | tr '[:upper:]' '[:lower:]')
            if echo "$lower_line" | grep -qE '^##[[:space:]]+(friction points|primary friction types)'; then
                found_heading=true
            fi
        elif [[ "$found_table" == false ]]; then
            # Looking for table start (header row with pipes)
            if echo "$line" | grep -qE '^\|.*\|'; then
                found_table=true
                # This is the header row, skip it
                # Next line should be separator (|---|---|)
            fi
        else
            # We're in the table area
            if echo "$line" | grep -qE '^\|[-: |]+\|$'; then
                # This is the separator row, skip it
                separator_seen=true
                continue
            fi
            if echo "$line" | grep -qE '^\|.*\|'; then
                # This is a data row
                table_rows="$table_rows
$line"
            else
                # End of table (non-pipe line)
                break
            fi
        fi
    done < "$report_file"

    if [[ "$found_heading" == false ]]; then
        echo "WARNING: No friction heading found in $fname, skipping" >&2
        continue
    fi

    if [[ "$found_table" == false ]] || [[ -z "$table_rows" ]]; then
        echo "WARNING: No friction table found after heading in $fname, skipping" >&2
        continue
    fi

    # Parse table rows
    has_valid_row=false

    while IFS= read -r row; do
        [[ -z "$row" ]] && continue

        # Extract columns from pipe-delimited row
        # | Type | Count | Pattern |
        # Remove leading/trailing pipes, split by |
        stripped=$(echo "$row" | sed 's/^[[:space:]]*|//;s/|[[:space:]]*$//')

        # Get first column (Type) and second column (Count)
        raw_type=$(echo "$stripped" | awk -F'|' '{print $1}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        raw_count=$(echo "$stripped" | awk -F'|' '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # Skip if count is not a number
        if ! echo "$raw_count" | grep -qE '^[0-9]+$'; then
            continue
        fi

        # Normalize type: trim, lowercase, spaces to underscores
        normalized_type=$(echo "$raw_type" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]' | sed 's/[[:space:]][[:space:]]*/_/g')

        # Skip empty types
        [[ -z "$normalized_type" ]] && continue

        has_valid_row=true

        # Title Case the raw type for display_name
        # Convert "wrong approach" or "Wrong Approach" or "TOOL LIMITATION" to "Wrong Approach" etc.
        display_name=$(echo "$raw_type" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')

        count=$((raw_count))

        # Update patterns accumulator
        existing=$(jq -r --arg t "$normalized_type" '.[$t] // empty' "$TEMP_DIR/patterns.json")

        if [[ -n "$existing" ]]; then
            # Pattern exists — append count and date
            jq --arg t "$normalized_type" \
               --argjson c "$count" \
               --arg d "$report_date" \
               '.[$t].counts += [$c] | .[$t].dates += [$d]' \
               "$TEMP_DIR/patterns.json" > "$TEMP_DIR/patterns.json.tmp"
            mv "$TEMP_DIR/patterns.json.tmp" "$TEMP_DIR/patterns.json"
        else
            # New pattern — create entry with display_name from first occurrence
            jq --arg t "$normalized_type" \
               --arg dn "$display_name" \
               --argjson c "$count" \
               --arg d "$report_date" \
               '.[$t] = {"display_name": $dn, "counts": [$c], "dates": [$d]}' \
               "$TEMP_DIR/patterns.json" > "$TEMP_DIR/patterns.json.tmp"
            mv "$TEMP_DIR/patterns.json.tmp" "$TEMP_DIR/patterns.json"
        fi
    done <<< "$table_rows"

    if [[ "$has_valid_row" == true ]]; then
        REPORT_COUNT=$((REPORT_COUNT + 1))
    else
        echo "WARNING: No valid data rows in friction table of $fname, skipping" >&2
    fi
done

# ---------------------------------------------------------------------------
# Step 4: Calculate trends and build output
# ---------------------------------------------------------------------------

GENERATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Build the final patterns array with trend calculation
# The jq script processes each pattern entry and computes trend
PATTERNS_JSON=$(jq -c --argjson rc "$REPORT_COUNT" '
to_entries | map({
    type: .key,
    display_name: .value.display_name,
    count: (.value.counts | add),
    first_seen: (.value.dates | min),
    last_seen: (.value.dates | max),
    per_report: .value.counts,
    trend: (
        if (.value.counts | length) == 1 then
            "new"
        elif (.value.counts | length) == 2 then
            if .value.counts[0] == .value.counts[1] then
                "stable"
            elif .value.counts[1] > .value.counts[0] then
                "increasing"
            else
                "decreasing"
            end
        else
            # 3+ reports: linear slope calculation
            # slope = (n*sum(i*y) - sum(i)*sum(y)) / (n*sum(i^2) - (sum(i))^2)
            # where i = 0,1,2,...,n-1
            (.value.counts | length) as $n |
            ([ range($n) ] | map(. * .value.counts[.])) as $dummy |
            # Compute using reduce for bash 3.2 / older jq compatibility
            (reduce range($n) as $i (0; . + ($i * .value.counts[$i]))) as $sum_iy |
            (reduce range($n) as $i (0; . + $i)) as $sum_i |
            (reduce range($n) as $i (0; . + .value.counts[$i])) as $sum_y |
            (reduce range($n) as $i (0; . + ($i * $i))) as $sum_i2 |
            (($n * $sum_iy) - ($sum_i * $sum_y)) as $numerator |
            (($n * $sum_i2) - ($sum_i * $sum_i)) as $denominator |
            if $denominator == 0 then
                "stable"
            else
                ($numerator / $denominator) as $slope |
                ($sum_y / $n) as $mean |
                if $mean == 0 then
                    if $slope > 0 then "increasing"
                    elif $slope < 0 then "decreasing"
                    else "stable"
                    end
                elif (($slope | fabs) / $mean) <= 0.1 then
                    "stable"
                elif $slope > 0 then
                    "increasing"
                else
                    "decreasing"
                end
            end
        end
    )
}) | sort_by(.type)
' "$TEMP_DIR/patterns.json" 2>/dev/null)

# The jq above has a known issue with nested .value references inside reduce.
# Use a simpler approach: iterate per pattern and compute trend externally.

# Actually, let's build patterns using a two-pass approach for reliability
# Pass 1: Extract raw data, Pass 2: Compute trends

PATTERNS_JSON=$(jq -c '
to_entries | map({
    type: .key,
    display_name: .value.display_name,
    count: (.value.counts | add),
    first_seen: (.value.dates | min),
    last_seen: (.value.dates | max),
    per_report: .value.counts,
    _counts: .value.counts
}) | sort_by(.type)
' "$TEMP_DIR/patterns.json")

# Compute trends for each pattern
FINAL_PATTERNS="[]"
pattern_count=$(echo "$PATTERNS_JSON" | jq 'length')

i=0
while [[ $i -lt $pattern_count ]]; do
    pattern=$(echo "$PATTERNS_JSON" | jq -c ".[$i]")
    counts=$(echo "$pattern" | jq -c '._counts')
    n=$(echo "$counts" | jq 'length')

    if [[ $n -eq 1 ]]; then
        trend="new"
    elif [[ $n -eq 2 ]]; then
        c0=$(echo "$counts" | jq '.[0]')
        c1=$(echo "$counts" | jq '.[1]')
        if [[ $c0 -eq $c1 ]]; then
            trend="stable"
        elif [[ $c1 -gt $c0 ]]; then
            trend="increasing"
        else
            trend="decreasing"
        fi
    else
        # 3+ reports: linear regression slope
        # slope = (n*sum(i*y_i) - sum(i)*sum(y_i)) / (n*sum(i^2) - (sum(i))^2)
        sum_iy=0
        sum_i=0
        sum_y=0
        sum_i2=0
        j=0
        while [[ $j -lt $n ]]; do
            y=$(echo "$counts" | jq ".[$j]")
            sum_iy=$((sum_iy + j * y))
            sum_i=$((sum_i + j))
            sum_y=$((sum_y + y))
            sum_i2=$((sum_i2 + j * j))
            j=$((j + 1))
        done

        numerator=$((n * sum_iy - sum_i * sum_y))
        denominator=$((n * sum_i2 - sum_i * sum_i))

        if [[ $denominator -eq 0 ]]; then
            trend="stable"
        else
            # Use awk for floating point
            trend=$(awk -v num="$numerator" -v den="$denominator" -v sum_y="$sum_y" -v n="$n" '
            BEGIN {
                slope = num / den
                mean = sum_y / n
                if (mean == 0) {
                    if (slope > 0) print "increasing"
                    else if (slope < 0) print "decreasing"
                    else print "stable"
                } else {
                    ratio = slope / mean
                    if (ratio < 0) ratio = -ratio
                    if (ratio <= 0.1) print "stable"
                    else if (slope > 0) print "increasing"
                    else print "decreasing"
                }
            }')
        fi
    fi

    # Add trend, remove _counts helper field
    FINAL_PATTERNS=$(echo "$FINAL_PATTERNS" | jq -c --argjson p "$pattern" --arg t "$trend" \
        '. + [($p | del(._counts) | . + {trend: $t})]')

    i=$((i + 1))
done

# ---------------------------------------------------------------------------
# Step 5: Apply merge algorithm (restore linear_issue_id, triaged_at)
# ---------------------------------------------------------------------------

if [[ "$MERGE_MAP" != "{}" ]]; then
    FINAL_PATTERNS=$(echo "$FINAL_PATTERNS" | jq -c --argjson mm "$MERGE_MAP" '
        map(
            if $mm[.type] != null then
                . + {
                    linear_issue_id: $mm[.type].linear_issue_id,
                    triaged_at: $mm[.type].triaged_at
                }
            else
                .
            end
        )
    ')
fi

# ---------------------------------------------------------------------------
# Step 6: Build final output
# ---------------------------------------------------------------------------

FINAL_OUTPUT=$(jq -n \
    --argjson sv 1 \
    --arg ga "$GENERATED_AT" \
    --argjson rc "$REPORT_COUNT" \
    --argjson patterns "$FINAL_PATTERNS" \
    '{
        schema_version: $sv,
        generated_at: $ga,
        report_count: $rc,
        patterns: $patterns
    }')

# Write output
mkdir -p "$(dirname "$OUTPUT_FILE")"
echo "$FINAL_OUTPUT" | jq '.' > "$OUTPUT_FILE"

echo "Pattern aggregation complete: $REPORT_COUNT reports processed, $(echo "$FINAL_PATTERNS" | jq 'length') patterns found" >&2
echo "Output written to $OUTPUT_FILE" >&2
