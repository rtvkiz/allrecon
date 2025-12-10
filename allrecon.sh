#!/bin/bash

#==============================================================================
# allrecon - Web Reconnaissance Automation Tool
# Version: 2.1
# Description: Performs subdomain enumeration and directory discovery
#==============================================================================

set -o pipefail

#==============================================================================
# Configuration & Global Variables
#==============================================================================

VERSION="2.1"
SCRIPT_NAME="$(basename "$0")"
OUTPUT_DIR="${ALLRECON_OUTPUT_DIR:-output}"
LOG_FILE=""
VERBOSE="${ALLRECON_VERBOSE:-false}"
HTTP_STATUS_CODES="${ALLRECON_HTTP_CODES:-200,201,204,301,302}"
MAX_PARALLEL="${ALLRECON_MAX_PARALLEL:-5}"
TIMEOUT="${ALLRECON_TIMEOUT:-300}"
AUTO_UPDATE="${ALLRECON_AUTO_UPDATE:-false}"
SMART_FILTER="${ALLRECON_SMART_FILTER:-true}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Interesting endpoint patterns (regex patterns)
declare -A INTERESTING_PATTERNS=(
    ["admin"]="(admin|administrator|wp-admin|cpanel|plesk|webmin)"
    ["api"]="(api|graphql|rest|v1|v2|v3|swagger|openapi)"
    ["auth"]="(login|signin|auth|oauth|sso|saml|jwt|token)"
    ["config"]="(config|configuration|settings|env|properties)"
    ["database"]="(phpmyadmin|adminer|mysql|postgres|mongodb|db|database)"
    ["backup"]="(backup|bak|old|copy|archive|dump|sql)"
    ["upload"]="(upload|file|media|assets|storage)"
    ["debug"]="(debug|test|dev|staging|console|phpinfo)"
    ["sensitive"]="(password|passwd|secret|key|credential|private)"
    ["files"]="(\\.env|\\.git|\\.svn|\\.htaccess|web\\.config|composer\\.json|package\\.json)"
)

#==============================================================================
# Utility Functions
#==============================================================================

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

print_highlight() {
    echo -e "${MAGENTA}[INTERESTING]${NC} $1"
}

# Logging function
log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" >> "$LOG_FILE"
    [[ "$VERBOSE" == "true" ]] && echo "$message"
}

# Display usage information
usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] <domain>

Web reconnaissance tool combining subfinder and dirsearch for comprehensive
subdomain enumeration and directory discovery.

Arguments:
  domain              Target domain to scan (e.g., example.com)

Options:
  -o, --output DIR    Output directory (default: $OUTPUT_DIR)
  -c, --codes CODES   HTTP status codes to capture (default: $HTTP_STATUS_CODES)
  -p, --parallel NUM  Max parallel dirsearch processes (default: $MAX_PARALLEL)
  -t, --timeout SEC   Timeout for dirsearch in seconds (default: $TIMEOUT)
  -v, --verbose       Enable verbose logging
  -u, --update        Update subfinder and dirsearch before scanning
  -s, --smart         Enable smart filtering for interesting endpoints (default: on)
  --no-smart          Disable smart filtering
  -h, --help          Display this help message
  --version           Display version information
  --no-cleanup        Don't remove previous scan results

Examples:
  $SCRIPT_NAME example.com
  $SCRIPT_NAME -u -v example.com                        # Update tools first
  $SCRIPT_NAME -v -c "200,301,302" --parallel 10 example.com
  $SCRIPT_NAME -o /tmp/scans --timeout 600 target.com

Environment Variables:
  ALLRECON_OUTPUT_DIR     Default output directory
  ALLRECON_HTTP_CODES     Default HTTP status codes
  ALLRECON_MAX_PARALLEL   Default parallel processes
  ALLRECON_TIMEOUT        Default timeout value
  ALLRECON_VERBOSE        Enable verbose mode (true/false)
  ALLRECON_AUTO_UPDATE    Auto-update tools (true/false)
  ALLRECON_SMART_FILTER   Enable smart filtering (true/false)

EOF
    exit 0
}

# Display version
version() {
    echo "$SCRIPT_NAME version $VERSION"
    exit 0
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Update tools
update_tools() {
    print_info "Updating reconnaissance tools..."
    log "Starting tool updates"

    local update_success=true

    # Update subfinder
    if command_exists "go"; then
        print_info "Updating subfinder..."
        if go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest >> "$LOG_FILE" 2>&1; then
            print_success "Subfinder updated successfully"
            log "Subfinder updated"
        else
            print_warning "Failed to update subfinder"
            log "WARNING: Subfinder update failed"
            update_success=false
        fi
    else
        print_warning "Go not found, skipping subfinder update"
        log "WARNING: Go not available for subfinder update"
    fi

    # Update dirsearch
    if command_exists "pip3"; then
        print_info "Updating dirsearch..."
        if pip3 install --upgrade dirsearch >> "$LOG_FILE" 2>&1; then
            print_success "Dirsearch updated successfully"
            log "Dirsearch updated"
        else
            print_warning "Failed to update dirsearch"
            log "WARNING: Dirsearch update failed"
            update_success=false
        fi
    elif command_exists "pip"; then
        print_info "Updating dirsearch..."
        if pip install --upgrade dirsearch >> "$LOG_FILE" 2>&1; then
            print_success "Dirsearch updated successfully"
            log "Dirsearch updated"
        else
            print_warning "Failed to update dirsearch"
            log "WARNING: Dirsearch update failed"
            update_success=false
        fi
    else
        print_warning "pip/pip3 not found, skipping dirsearch update"
        log "WARNING: pip not available for dirsearch update"
    fi

    echo ""

    if [ "$update_success" = true ]; then
        log "All tool updates completed successfully"
    else
        log "Some tool updates failed"
    fi

    return 0
}

# Validate domain format
validate_domain() {
    local domain="$1"

    # Basic domain validation regex
    if [[ ! "$domain" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
        print_error "Invalid domain format: $domain"
        print_info "Domain should be in format: example.com or subdomain.example.com"
        return 1
    fi

    return 0
}

# Check dependencies
check_dependencies() {
    local missing_deps=()

    print_info "Checking dependencies..."

    if ! command_exists "subfinder"; then
        missing_deps+=("subfinder")
    fi

    if ! command_exists "dirsearch"; then
        missing_deps+=("dirsearch")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        echo ""
        echo "Installation instructions:"
        echo "  subfinder: go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
        echo "  dirsearch: pip3 install dirsearch"
        echo ""
        echo "Make sure the tools are in your PATH."
        return 1
    fi

    print_success "All dependencies found"
    return 0
}

# Check if endpoint matches interesting patterns
is_interesting() {
    local url="$1"
    local matches=()

    for category in "${!INTERESTING_PATTERNS[@]}"; do
        local pattern="${INTERESTING_PATTERNS[$category]}"
        if echo "$url" | grep -iE "$pattern" >/dev/null 2>&1; then
            matches+=("$category")
        fi
    done

    if [ ${#matches[@]} -gt 0 ]; then
        echo "${matches[*]}"
        return 0
    fi

    return 1
}

# Get interest score based on categories
get_interest_score() {
    local categories="$1"
    local score=0

    # High value categories
    [[ "$categories" =~ admin ]] && ((score += 10))
    [[ "$categories" =~ sensitive ]] && ((score += 10))
    [[ "$categories" =~ config ]] && ((score += 9))
    [[ "$categories" =~ database ]] && ((score += 9))
    [[ "$categories" =~ backup ]] && ((score += 8))
    [[ "$categories" =~ auth ]] && ((score += 7))
    [[ "$categories" =~ files ]] && ((score += 7))
    [[ "$categories" =~ api ]] && ((score += 6))
    [[ "$categories" =~ upload ]] && ((score += 5))
    [[ "$categories" =~ debug ]] && ((score += 5))

    echo "$score"
}

#==============================================================================
# Core Functions
#==============================================================================

# Run subdomain enumeration
enumerate_subdomains() {
    local domain="$1"
    local hosts_file="$2"

    print_info "Starting subdomain enumeration for: $domain"
    log "Running subfinder for domain: $domain"

    if ! subfinder -d "$domain" -o "$hosts_file" 2>> "$LOG_FILE"; then
        print_error "Subfinder failed for domain: $domain"
        log "ERROR: Subfinder failed"
        return 1
    fi

    local subdomain_count=$(wc -l < "$hosts_file" 2>/dev/null || echo "0")
    print_success "Found $subdomain_count subdomains"
    log "Subdomain enumeration completed: $subdomain_count subdomains found"

    return 0
}

# Run directory scanning on a single host
scan_host() {
    local host="$1"
    local output_file="$2"

    log "Scanning host: $host"

    # Run dirsearch with timeout
    if timeout "$TIMEOUT" dirsearch -u "$host" -o "$output_file" --format=plain 2>> "$LOG_FILE"; then
        log "Completed scan: $host"
        return 0
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            print_warning "Timeout scanning $host (${TIMEOUT}s exceeded)"
            log "WARNING: Timeout for host $host"
        else
            print_warning "Failed to scan $host (exit code: $exit_code)"
            log "WARNING: Scan failed for host $host"
        fi
        return 1
    fi
}

# Scan all discovered subdomains
scan_subdomains() {
    local hosts_file="$1"
    local output_dir="$2"

    if [ ! -f "$hosts_file" ] || [ ! -s "$hosts_file" ]; then
        print_error "No subdomains found to scan"
        return 1
    fi

    local total_hosts=$(wc -l < "$hosts_file")
    local current=0
    local pids=()

    print_info "Starting directory scans on $total_hosts hosts (max $MAX_PARALLEL parallel)"

    while IFS= read -r host; do
        # Skip empty lines
        [[ -z "$host" ]] && continue

        ((current++))

        # Wait if we've reached max parallel processes
        while [ ${#pids[@]} -ge "$MAX_PARALLEL" ]; do
            for i in "${!pids[@]}"; do
                if ! kill -0 "${pids[$i]}" 2>/dev/null; then
                    unset 'pids[i]'
                fi
            done
            pids=("${pids[@]}") # Re-index array
            sleep 0.5
        done

        print_info "[$current/$total_hosts] Scanning: $host"

        # Launch scan in background
        scan_host "$host" "$output_dir/${host}.txt" &
        pids+=($!)

    done < "$hosts_file"

    # Wait for all remaining background processes
    print_info "Waiting for remaining scans to complete..."
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null
    done

    print_success "All directory scans completed"
    log "Directory scanning phase completed"

    return 0
}

# Aggregate results based on HTTP status codes
aggregate_results() {
    local scan_dir="$1"
    local target_dir="$2"
    local status_codes="$3"

    print_info "Aggregating results for HTTP codes: $status_codes"
    log "Starting result aggregation"

    # Convert comma-separated codes to array
    IFS=',' read -ra codes_array <<< "$status_codes"

    # Create files for different status code ranges
    local final_2xx="$target_dir/final_2xx_success.txt"
    local final_3xx="$target_dir/final_3xx_redirects.txt"
    local final_4xx="$target_dir/final_4xx_client_errors.txt"
    local final_5xx="$target_dir/final_5xx_server_errors.txt"
    local final_all="$target_dir/final_all.txt"
    local interesting_file="$target_dir/interesting.txt"

    # Clear/create all files
    > "$final_2xx"
    > "$final_3xx"
    > "$final_4xx"
    > "$final_5xx"
    > "$final_all"
    > "$interesting_file"

    local total_matches=0
    local files_processed=0
    local interesting_count=0

    # Arrays to store categorized results
    declare -A status_results

    for file in "$scan_dir"/*; do
        [ -f "$file" ] || continue

        ((files_processed++))

        # Skip header lines if they exist
        sed -i '1,2{/^Target/d; /^$/d}' "$file" 2>/dev/null

        while IFS= read -r line; do
            # Extract HTTP status code (first column)
            local http_status=$(echo "$line" | awk '{print $1}')

            # Check if status code matches any in our list
            for code in "${codes_array[@]}"; do
                if [ "$http_status" = "$code" ]; then
                    # Extract URL (third column)
                    local url=$(echo "$line" | awk '{print $3}')
                    if [ -n "$url" ]; then
                        # Add to appropriate file based on status code range
                        if [[ "$http_status" =~ ^2[0-9]{2}$ ]]; then
                            echo "$url" >> "$final_2xx"
                        elif [[ "$http_status" =~ ^3[0-9]{2}$ ]]; then
                            echo "$url" >> "$final_3xx"
                        elif [[ "$http_status" =~ ^4[0-9]{2}$ ]]; then
                            echo "$url" >> "$final_4xx"
                        elif [[ "$http_status" =~ ^5[0-9]{2}$ ]]; then
                            echo "$url" >> "$final_5xx"
                        fi

                        # Add to all results
                        echo "$url" >> "$final_all"
                        ((total_matches++))

                        # Check if interesting (smart filter)
                        if [ "$SMART_FILTER" = "true" ]; then
                            if categories=$(is_interesting "$url"); then
                                score=$(get_interest_score "$categories")
                                echo "[$score] [$categories] $url" >> "$interesting_file"
                                ((interesting_count++))
                            fi
                        fi
                    fi
                    break
                fi
            done
        done < "$file"
    done

    # Process and sort each file
    for result_file in "$final_2xx" "$final_3xx" "$final_4xx" "$final_5xx" "$final_all"; do
        if [ -f "$result_file" ] && [ -s "$result_file" ]; then
            sort -u "$result_file" -o "$result_file"
        fi
    done

    # Sort interesting results by score (descending)
    if [ -f "$interesting_file" ] && [ -s "$interesting_file" ]; then
        sort -t'[' -k2 -rn "$interesting_file" -o "$interesting_file"
    fi

    # Display statistics
    local count_2xx=$([ -f "$final_2xx" ] && wc -l < "$final_2xx" || echo "0")
    local count_3xx=$([ -f "$final_3xx" ] && wc -l < "$final_3xx" || echo "0")
    local count_4xx=$([ -f "$final_4xx" ] && wc -l < "$final_4xx" || echo "0")
    local count_5xx=$([ -f "$final_5xx" ] && wc -l < "$final_5xx" || echo "0")
    local unique_count=$([ -f "$final_all" ] && wc -l < "$final_all" || echo "0")

    print_success "Found $total_matches endpoints ($unique_count unique) from $files_processed scan results"
    print_info "Status code breakdown:"
    echo "  2xx Success:       $count_2xx endpoints"
    echo "  3xx Redirects:     $count_3xx endpoints"
    echo "  4xx Client Errors: $count_4xx endpoints"
    echo "  5xx Server Errors: $count_5xx endpoints"

    if [ "$SMART_FILTER" = "true" ] && [ "$interesting_count" -gt 0 ]; then
        print_highlight "Found $interesting_count interesting endpoints (see interesting.txt)"
        log "Smart filter identified $interesting_count interesting endpoints"
    fi

    log "Aggregation completed: $unique_count unique endpoints"

    return 0
}

# Generate scan summary
generate_summary() {
    local domain="$1"
    local directory="$2"
    local hosts_file="$3"
    local scan_dir="$4"

    local subdomain_count=$([ -f "$hosts_file" ] && wc -l < "$hosts_file" || echo "0")
    local scan_file_count=$(find "$scan_dir" -type f 2>/dev/null | wc -l)

    local count_2xx=$([ -f "$directory/final_2xx_success.txt" ] && wc -l < "$directory/final_2xx_success.txt" || echo "0")
    local count_3xx=$([ -f "$directory/final_3xx_redirects.txt" ] && wc -l < "$directory/final_3xx_redirects.txt" || echo "0")
    local count_4xx=$([ -f "$directory/final_4xx_client_errors.txt" ] && wc -l < "$directory/final_4xx_client_errors.txt" || echo "0")
    local count_5xx=$([ -f "$directory/final_5xx_server_errors.txt" ] && wc -l < "$directory/final_5xx_server_errors.txt" || echo "0")
    local count_all=$([ -f "$directory/final_all.txt" ] && wc -l < "$directory/final_all.txt" || echo "0")
    local count_interesting=$([ -f "$directory/interesting.txt" ] && wc -l < "$directory/interesting.txt" || echo "0")

    cat << EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                        SCAN SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Target Domain:       $domain
Subdomains Found:    $subdomain_count
Hosts Scanned:       $scan_file_count
HTTP Status Codes:   $HTTP_STATUS_CODES

ENDPOINTS DISCOVERED:
  Total Unique:        $count_all
  ├─ 2xx Success:      $count_2xx
  ├─ 3xx Redirects:    $count_3xx
  ├─ 4xx Client Error: $count_4xx
  └─ 5xx Server Error: $count_5xx

EOF

    if [ "$SMART_FILTER" = "true" ] && [ "$count_interesting" -gt 0 ]; then
        cat << EOF
  🎯 Interesting:      $count_interesting (HIGH PRIORITY)

EOF
    fi

    cat << EOF
OUTPUT FILES:
  Main Directory:      $directory
  ├─ Subdomains:       hosts.txt ($subdomain_count)
  ├─ All Endpoints:    final_all.txt ($count_all)
  ├─ Success (2xx):    final_2xx_success.txt ($count_2xx)
  ├─ Redirects (3xx):  final_3xx_redirects.txt ($count_3xx)
  ├─ Errors (4xx):     final_4xx_client_errors.txt ($count_4xx)
  ├─ Errors (5xx):     final_5xx_server_errors.txt ($count_5xx)
EOF

    if [ "$SMART_FILTER" = "true" ] && [ "$count_interesting" -gt 0 ]; then
        cat << EOF
  ├─ 🎯 Interesting:   interesting.txt ($count_interesting) ⭐
EOF
    fi

    cat << EOF
  ├─ Scan Details:     dir/ ($scan_file_count files)
  └─ Log File:         scan.log

Scan completed at:   $(date '+%Y-%m-%d %H:%M:%S')
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF

    # Show top interesting findings if available
    if [ "$SMART_FILTER" = "true" ] && [ "$count_interesting" -gt 0 ] && [ "$count_interesting" -le 20 ]; then
        print_highlight "Top Interesting Endpoints:"
        head -n 10 "$directory/interesting.txt" | while IFS= read -r line; do
            echo "  $line"
        done
        echo ""
    elif [ "$SMART_FILTER" = "true" ] && [ "$count_interesting" -gt 20 ]; then
        print_highlight "Top 10 Interesting Endpoints (of $count_interesting):"
        head -n 10 "$directory/interesting.txt" | while IFS= read -r line; do
            echo "  $line"
        done
        echo ""
        print_info "See interesting.txt for all $count_interesting findings"
        echo ""
    fi
}

#==============================================================================
# Main Execution
#==============================================================================

main() {
    local domain=""
    local cleanup=true

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            --version)
                version
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -c|--codes)
                HTTP_STATUS_CODES="$2"
                shift 2
                ;;
            -p|--parallel)
                MAX_PARALLEL="$2"
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
            -u|--update)
                AUTO_UPDATE=true
                shift
                ;;
            -s|--smart)
                SMART_FILTER=true
                shift
                ;;
            --no-smart)
                SMART_FILTER=false
                shift
                ;;
            --no-cleanup)
                cleanup=false
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
            *)
                domain="$1"
                shift
                ;;
        esac
    done

    # Validate input
    if [ -z "$domain" ]; then
        print_error "No domain specified"
        echo "Use --help for usage information"
        exit 1
    fi

    # Validate domain format
    if ! validate_domain "$domain"; then
        exit 1
    fi

    # Setup directories
    local target_dir="$OUTPUT_DIR/$domain"
    local scan_dir="$target_dir/dir"
    local hosts_file="$target_dir/hosts.txt"
    LOG_FILE="$target_dir/scan.log"

    # Create directory structure early for logging
    mkdir -p "$scan_dir"

    # Initialize log
    echo "=== allrecon $VERSION - Scan started at $(date) ===" > "$LOG_FILE"
    log "Target domain: $domain"
    log "Configuration: HTTP_CODES=$HTTP_STATUS_CODES, MAX_PARALLEL=$MAX_PARALLEL, TIMEOUT=$TIMEOUT"

    # Update tools if requested
    if [ "$AUTO_UPDATE" = true ]; then
        update_tools
    fi

    # Check dependencies
    if ! check_dependencies; then
        exit 1
    fi

    # Cleanup previous results if requested
    if [ "$cleanup" = true ] && [ -d "$target_dir" ]; then
        print_info "Cleaning up previous scan results for $domain"
        # Preserve the log file
        local temp_log="/tmp/allrecon_${domain}_$(date +%s).log"
        [ -f "$LOG_FILE" ] && cp "$LOG_FILE" "$temp_log"
        rm -rf "$target_dir"
        mkdir -p "$scan_dir"
        [ -f "$temp_log" ] && mv "$temp_log" "$LOG_FILE"
    fi

    print_info "Starting reconnaissance for: $domain"
    echo ""

    # Execute reconnaissance workflow
    if ! enumerate_subdomains "$domain" "$hosts_file"; then
        exit 1
    fi

    echo ""

    if ! scan_subdomains "$hosts_file" "$scan_dir"; then
        exit 1
    fi

    echo ""

    aggregate_results "$scan_dir" "$target_dir" "$HTTP_STATUS_CODES"

    # Display summary
    generate_summary "$domain" "$target_dir" "$hosts_file" "$scan_dir"

    log "=== Scan completed successfully ==="

    print_success "Reconnaissance completed successfully!"

    exit 0
}

# Run main function
main "$@"
