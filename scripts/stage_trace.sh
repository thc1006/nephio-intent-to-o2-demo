#!/usr/bin/env bash
# Stage trace reporting utility for pipeline execution monitoring

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Stage trace class
create_trace() {
    local trace_file="$1"
    local pipeline_id="${2:-$(date +%s)}"

    cat > "$trace_file" <<EOF
{
  "pipeline_id": "$pipeline_id",
  "start_time": "$(date -Iseconds)",
  "status": "running",
  "stages": [],
  "metrics": {
    "total_duration_ms": 0,
    "stages_completed": 0,
    "stages_failed": 0
  }
}
EOF
    echo "$trace_file"
}

# Add stage to trace
add_stage() {
    local trace_file="$1"
    local stage_name="$2"
    local status="${3:-running}"
    local message="${4:-}"
    local start_time="${5:-$(date -Iseconds)}"

    jq ".stages += [{
        \"name\": \"$stage_name\",
        \"start_time\": \"$start_time\",
        \"status\": \"$status\",
        \"message\": \"$message\"
    }]" "$trace_file" > "${trace_file}.tmp"
    mv "${trace_file}.tmp" "$trace_file"
}

# Update stage status
update_stage() {
    local trace_file="$1"
    local stage_name="$2"
    local status="$3"
    local end_time="${4:-$(date -Iseconds)}"
    local message="${5:-}"
    local duration_ms="${6:-0}"

    # Escape message for JSON
    message=$(echo "$message" | sed 's/"/\\"/g')

    # Ensure duration is a valid number
    if [[ -z "$duration_ms" ]] || [[ "$duration_ms" == "" ]]; then
        duration_ms=0
    fi

    jq --arg name "$stage_name" \
       --arg status "$status" \
       --arg end_time "$end_time" \
       --arg message "$message" \
       --argjson duration "$duration_ms" \
       '.stages |= map(if .name == $name then
            .status = $status |
            .end_time = $end_time |
            .duration_ms = $duration |
            .message = $message
        else . end)' "$trace_file" > "${trace_file}.tmp"
    mv "${trace_file}.tmp" "$trace_file"

    # Update metrics
    if [[ "$status" == "success" ]]; then
        jq ".metrics.stages_completed += 1" "$trace_file" > "${trace_file}.tmp"
    elif [[ "$status" == "failed" ]]; then
        jq ".metrics.stages_failed += 1" "$trace_file" > "${trace_file}.tmp"
    fi
    [[ -f "${trace_file}.tmp" ]] && mv "${trace_file}.tmp" "$trace_file"
}

# Finalize trace
finalize_trace() {
    local trace_file="$1"
    local status="${2:-completed}"
    local end_time="$(date -Iseconds)"

    # Calculate total duration
    local start_epoch=$(jq -r '.start_time' "$trace_file" | xargs -I {} date -d {} +%s%N)
    local end_epoch=$(date +%s%N)
    local duration_ms=$(( (end_epoch - start_epoch) / 1000000 ))

    jq ".status = \"$status\" |
        .end_time = \"$end_time\" |
        .metrics.total_duration_ms = $duration_ms" "$trace_file" > "${trace_file}.tmp"
    mv "${trace_file}.tmp" "$trace_file"
}

# Generate trace report
generate_report() {
    local trace_file="$1"

    echo ""
    echo "======================================"
    echo "Pipeline Execution Trace Report"
    echo "======================================"

    local pipeline_id=$(jq -r '.pipeline_id' "$trace_file")
    local status=$(jq -r '.status' "$trace_file")
    local start_time=$(jq -r '.start_time' "$trace_file")
    local total_duration=$(jq -r '.metrics.total_duration_ms' "$trace_file")
    local stages_completed=$(jq -r '.metrics.stages_completed' "$trace_file")
    local stages_failed=$(jq -r '.metrics.stages_failed' "$trace_file")

    echo "Pipeline ID: $pipeline_id"
    echo "Status: $status"
    echo "Start Time: $start_time"
    echo "Duration: ${total_duration}ms"
    echo ""
    echo "Stages Summary:"
    echo "  Completed: $stages_completed"
    echo "  Failed: $stages_failed"
    echo ""
    echo "Stage Details:"
    echo "-------------------------------------"

    jq -r '.stages[] |
        "\(.name):\n  Status: \(.status)\n  Duration: \(.duration_ms // "N/A")ms\n  Message: \(.message // "N/A")\n"' \
        "$trace_file"

    echo "======================================"
}

# Visualize trace as timeline
visualize_timeline() {
    local trace_file="$1"

    echo ""
    echo "Pipeline Timeline:"
    echo "=================="

    jq -r '.stages[] |
        if .status == "success" then
            "✓ \(.name) [\(.duration_ms // 0)ms]"
        elif .status == "failed" then
            "✗ \(.name) [\(.duration_ms // 0)ms] - \(.message // "")"
        elif .status == "skipped" then
            "○ \(.name) [skipped]"
        else
            "⚡ \(.name) [running]"
        end' "$trace_file"

    echo "=================="
}

# Export trace as metrics
export_metrics() {
    local trace_file="$1"
    local format="${2:-prometheus}"

    case "$format" in
        prometheus)
            # Prometheus format
            local pipeline_id=$(jq -r '.pipeline_id' "$trace_file")
            local total_duration=$(jq -r '.metrics.total_duration_ms' "$trace_file")
            local stages_completed=$(jq -r '.metrics.stages_completed' "$trace_file")
            local stages_failed=$(jq -r '.metrics.stages_failed' "$trace_file")

            cat <<EOF
# HELP pipeline_duration_ms Total pipeline execution duration in milliseconds
# TYPE pipeline_duration_ms gauge
pipeline_duration_ms{pipeline_id="$pipeline_id"} $total_duration

# HELP pipeline_stages_completed Number of successfully completed stages
# TYPE pipeline_stages_completed counter
pipeline_stages_completed{pipeline_id="$pipeline_id"} $stages_completed

# HELP pipeline_stages_failed Number of failed stages
# TYPE pipeline_stages_failed counter
pipeline_stages_failed{pipeline_id="$pipeline_id"} $stages_failed
EOF

            # Per-stage metrics
            jq -r '.stages[] |
                "stage_duration_ms{pipeline_id=\"'$pipeline_id'\",stage=\"\(.name)\",status=\"\(.status)\"} \(.duration_ms // 0)"' \
                "$trace_file"
            ;;

        json)
            # JSON metrics export
            jq '{
                pipeline_id: .pipeline_id,
                metrics: .metrics,
                stage_metrics: [.stages[] | {
                    name: .name,
                    status: .status,
                    duration_ms: .duration_ms
                }]
            }' "$trace_file"
            ;;

        csv)
            # CSV format
            echo "pipeline_id,stage,status,duration_ms,message"
            jq -r '.stages[] |
                [.pipeline_id // "'$pipeline_id'", .name, .status, .duration_ms // 0, .message // ""] |
                @csv' "$trace_file"
            ;;
    esac
}

# Usage
usage() {
    cat <<EOF
Usage: $0 COMMAND [OPTIONS]

Stage Trace Reporting Utility

Commands:
    create FILE [ID]           Create new trace file
    add FILE STAGE [STATUS]    Add stage to trace
    update FILE STAGE STATUS   Update stage status
    finalize FILE [STATUS]     Finalize trace
    report FILE                Generate trace report
    timeline FILE              Visualize as timeline
    metrics FILE [FORMAT]      Export metrics (prometheus|json|csv)

Examples:
    $0 create trace.json pipeline-123
    $0 add trace.json "generate_intent" "running"
    $0 update trace.json "generate_intent" "success"
    $0 report trace.json
    $0 timeline trace.json
    $0 metrics trace.json prometheus

EOF
    exit 0
}

# Main command dispatcher
case "${1:-}" in
    create)
        create_trace "${2:-trace.json}" "${3:-}"
        ;;
    add)
        add_stage "${2:-trace.json}" "$3" "${4:-running}" "${5:-}"
        ;;
    update)
        end_time="${5:-}"
        if [[ -z "$end_time" ]]; then
            end_time="$(date -Iseconds)"
        fi
        update_stage "${2:-trace.json}" "$3" "$4" "$end_time" "${6:-}" "${7:-0}"
        ;;
    finalize)
        finalize_trace "${2:-trace.json}" "${3:-completed}"
        ;;
    report)
        generate_report "${2:-trace.json}"
        ;;
    timeline)
        visualize_timeline "${2:-trace.json}"
        ;;
    metrics)
        export_metrics "${2:-trace.json}" "${3:-prometheus}"
        ;;
    --help|-h|help)
        usage
        ;;
    *)
        echo "Unknown command: ${1:-}"
        usage
        ;;
esac