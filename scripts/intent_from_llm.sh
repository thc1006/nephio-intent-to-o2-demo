#!/bin/bash
#
# Intent from LLM - Convert natural language to intent JSON via LLM adapter
#
# Usage:
#   scripts/intent_from_llm.sh "Deploy eMBB slice in edge1 with 500Mbps downlink"
#   scripts/intent_from_llm.sh --file input.txt
#   scripts/intent_from_llm.sh --interactive
#

set -euo pipefail

# Configuration
LLM_ADAPTER_URL="${LLM_ADAPTER_URL:-http://localhost:8888}"
VERBOSE="${VERBOSE:-false}"
OUTPUT_FILE="${OUTPUT_FILE:-}"
TIMEOUT="${TIMEOUT:-30}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" >&2
}

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS] [TEXT]

Convert natural language to intent JSON via LLM adapter.

OPTIONS:
    -h, --help              Show this help message
    -f, --file FILE         Read input text from file
    -i, --interactive       Interactive mode
    -o, --output FILE       Output file (default: stdout)
    -u, --url URL           LLM adapter URL (default: $LLM_ADAPTER_URL)
    -t, --timeout SECONDS   Request timeout (default: $TIMEOUT)
    -v, --verbose           Verbose output

EXAMPLES:
    $0 "Deploy eMBB slice in edge1 with 500Mbps downlink"
    $0 --file request.txt --output intent.json
    $0 --interactive

ENVIRONMENT VARIABLES:
    LLM_ADAPTER_URL        LLM adapter endpoint URL
    VERBOSE                Enable verbose output (true/false)
    OUTPUT_FILE            Default output file
    TIMEOUT                Request timeout in seconds
EOF
}

# Health check function
check_llm_adapter() {
    log_info "Checking LLM adapter health at $LLM_ADAPTER_URL..."
    
    if ! curl -sf "$LLM_ADAPTER_URL/health" >/dev/null 2>&1; then
        log_error "LLM adapter health check failed at $LLM_ADAPTER_URL/health"
        log_error "Please ensure the LLM adapter is running and accessible"
        return 1
    fi
    
    log_success "LLM adapter is healthy"
    return 0
}

# Parse intent function
parse_intent() {
    local input_text="$1"
    local temp_file
    temp_file=$(mktemp)
    
    # Prepare request payload
    jq -n --arg text "$input_text" '{text: $text}' > "$temp_file"
    
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "Sending request to $LLM_ADAPTER_URL/api/v1/intent/parse"
        log_info "Request payload:"
        cat "$temp_file" >&2
        echo >&2
    fi
    
    # Send request to LLM adapter
    local response
    response=$(curl -sf \
        --max-time "$TIMEOUT" \
        -X POST \
        -H "Content-Type: application/json" \
        -d @"$temp_file" \
        "$LLM_ADAPTER_URL/api/v1/intent/parse" 2>/dev/null)
    
    # Clean up temp file
    rm -f "$temp_file"
    
    # Validate JSON response
    if ! echo "$response" | jq . >/dev/null 2>&1; then
        log_error "Invalid JSON response from LLM adapter"
        echo "$response" >&2
        return 1
    fi
    
    # Check for error in response
    if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
        log_error "LLM adapter returned error:"
        echo "$response" | jq -r '.error' >&2
        return 1
    fi
    
    # Validate required fields
    if ! echo "$response" | jq -e '.intentExpectationId and .intentExpectationType' >/dev/null 2>&1; then
        log_error "Response missing required intent fields (intentExpectationId, intentExpectationType)"
        echo "$response" >&2
        return 1
    fi
    
    # Add targetSite if not present (default to edge1 for backward compatibility)
    response=$(echo "$response" | jq '. + if .targetSite then {} else {targetSite: "edge1"} end')
    
    if [[ "$VERBOSE" == "true" ]]; then
        log_success "Successfully parsed intent"
        log_info "Response:"
        echo "$response" | jq . >&2
        echo >&2
    fi
    
    echo "$response"
}

# Interactive mode
interactive_mode() {
    log_info "Starting interactive mode. Type 'quit' or 'exit' to stop."
    echo
    
    while true; do
        echo -n "Enter natural language request: "
        read -r input_text
        
        if [[ "$input_text" == "quit" || "$input_text" == "exit" ]]; then
            log_info "Exiting interactive mode"
            break
        fi
        
        if [[ -z "$input_text" ]]; then
            log_warn "Empty input, please try again"
            continue
        fi
        
        echo
        log_info "Processing: $input_text"
        
        if parse_intent "$input_text"; then
            log_success "Intent parsed successfully"
        else
            log_error "Failed to parse intent"
        fi
        
        echo
        echo "---"
        echo
    done
}

# Main function
main() {
    local input_text=""
    local input_file=""
    local interactive=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -f|--file)
                input_file="$2"
                shift 2
                ;;
            -i|--interactive)
                interactive=true
                shift
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -u|--url)
                LLM_ADAPTER_URL="$2"
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                input_text="$1"
                shift
                ;;
        esac
    done
    
    # Check LLM adapter health
    if ! check_llm_adapter; then
        exit 1
    fi
    
    # Handle different input modes
    if [[ "$interactive" == "true" ]]; then
        interactive_mode
        return 0
    fi
    
    if [[ -n "$input_file" ]]; then
        if [[ ! -f "$input_file" ]]; then
            log_error "Input file not found: $input_file"
            exit 1
        fi
        input_text=$(cat "$input_file")
    fi
    
    if [[ -z "$input_text" ]]; then
        log_error "No input provided. Use --help for usage information."
        exit 1
    fi
    
    # Parse the intent
    local result
    if result=$(parse_intent "$input_text"); then
        if [[ -n "$OUTPUT_FILE" ]]; then
            echo "$result" > "$OUTPUT_FILE"
            log_success "Intent saved to $OUTPUT_FILE"
        else
            echo "$result"
        fi
    else
        log_error "Failed to parse intent"
        exit 1
    fi
}

# Execute main function
main "$@"