#!/bin/bash
# shellcheck disable=SC2155

#
# QWC Services Health Check & Endpoint Test Script
#
# This script tests reachability and functionality of all QWC services
# using kubectl port-forward.
#
# Usage:
#   ./test-services.sh [OPTIONS]
#
# Options:
#   -n, --namespace NAMESPACE   Kubernetes namespace (default: qwc-dev)
#   -r, --release RELEASE       Helm release name (default: qwc-services)
#   -v, --verbose               Verbose output
#   -h, --help                  Show this help message
#
# Requirements:
#   - kubectl configured with access to the cluster
#   - curl installed
#

set -e

# ============================================
# Configuration
# ============================================

ROOT_DIR=$(dirname "$0")

# Default values
NAMESPACE="${QWC_NAMESPACE:-qwc-dev}"
RELEASE="${QWC_RELEASE:-my-qwc-instance}"
VERBOSE="${VERBOSE:-false}"
LOCAL_PORT_START=18000
TIMEOUT=5

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# ============================================
# Service Definitions (compatible with bash 3.x)
# ============================================

# Format: service_short|description|container_port|health_endpoint|test_endpoints (separated by ,)
SERVICES_LIST="
qwcconfigservice|Config Generator Service|9090|/maps?tenant=default|/maps?tenant=default
qwcqgisserver|QGIS Server (WMS/WFS)|1080|/|/ows/?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities&MAP=/data/demo.qgs
qwcmapviewer|Map Viewer Frontend|9090|/healthz|/healthz,/ready,/
qwcogcservice|OGC Service Proxy|9090|/healthz|/healthz,/ready,/ows/
qwcdataservice|Data REST API|9090|/healthz|/healthz,/ready
qwcauthservice|Authentication Service|9090|/healthz|/healthz,/ready,/auth/login
qwcadmingui|Admin GUI|9090|/|/
qwcpermalinkservice|Permalink Service|9090|/healthz|/healthz,/ready
"

DB_SERVICE="qwcdb|PostgreSQL Database|5432|tcp|none"

# ============================================
# Helper Functions
# ============================================

usage() {
  echo ""
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  -n, --namespace NAMESPACE   Kubernetes namespace (default: $NAMESPACE)"
  echo "  -r, --release RELEASE       Helm release name (default: $RELEASE)"
  echo "  -v, --verbose               Verbose output"
  echo "  -h, --help                  Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0                                    # Use defaults"
  echo "  $0 -n my-namespace -r my-release      # Custom namespace and release"
  echo "  $0 -v                                 # Verbose mode"
  echo ""
}

log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
  echo -e "${RED}[✗]${NC} $1"
}

log_header() {
  echo ""
  echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}${CYAN}  $1${NC}"
  echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
}

log_section() {
  echo ""
  echo -e "${BOLD}── $1 ──${NC}"
}

verbose_log() {
  if [ "$VERBOSE" = true ]; then
    echo -e "${CYAN}    [DEBUG] $1${NC}"
  fi
}

# ============================================
# Parse Arguments
# ============================================

while [[ $# -gt 0 ]]; do
  case $1 in
    -n | --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    -r | --release)
      RELEASE="$2"
      shift 2
      ;;
    -v | --verbose)
      VERBOSE=true
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

# ============================================
# Pre-flight Checks
# ============================================

log_header "QWC Services Health Check & Endpoint Test"

echo ""
echo -e "  ${BOLD}Configuration:${NC}"
echo -e "    Namespace:    ${CYAN}$NAMESPACE${NC}"
echo -e "    Release:      ${CYAN}$RELEASE${NC}"
echo -e "    Verbose:      ${CYAN}$VERBOSE${NC}"
echo ""

# Check kubectl
if ! command -v kubectl &>/dev/null; then
  log_error "kubectl is not installed or not in PATH"
  exit 1
fi

# Check cluster connection
log_info "Checking cluster connection..."
if ! kubectl cluster-info &>/dev/null; then
  log_error "Cannot connect to Kubernetes cluster"
  exit 1
fi
log_success "Cluster connection OK"

# Check namespace exists
log_info "Checking namespace '$NAMESPACE'..."
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
  log_error "Namespace '$NAMESPACE' does not exist"
  exit 1
fi
log_success "Namespace exists"

# ============================================
# Test Functions
# ============================================

# Get pod name for a service
get_pod_name() {
  local service_short=$1
  local service_name="${RELEASE}-${service_short}"

  # Try to get pod by service label
  local pod=$(kubectl get pods -n "$NAMESPACE" \
    -l "app.kubernetes.io/name=$service_short" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

  # Fallback: try by partial name match
  if [ -z "$pod" ]; then
    pod=$(kubectl get pods -n "$NAMESPACE" \
      --field-selector=status.phase=Running \
      -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | grep "$service_name" | head -1)
  fi

  echo "$pod"
}

# Check if pod is running
check_pod_status() {
  local pod=$1
  local status=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null)
  echo "$status"
}

# Start port-forward in background
start_port_forward() {
  local pod=$1
  local local_port=$2
  local remote_port=$3

  kubectl port-forward "pod/$pod" "$local_port:$remote_port" -n "$NAMESPACE" &>/dev/null &
  local pf_pid=$!
  echo $pf_pid

  # Wait a bit for port-forward to establish
  sleep 2
}

# Stop port-forward
stop_port_forward() {
  local pf_pid=$1
  if [ -n "$pf_pid" ] && kill -0 "$pf_pid" 2>/dev/null; then
    kill "$pf_pid" 2>/dev/null || true
    wait "$pf_pid" 2>/dev/null || true
  fi
}

# Test TCP connection (for database)
test_tcp_connection() {
  local port=$1
  local timeout_sec=${2:-5}

  # Try nc first, then /dev/tcp
  if command -v nc &>/dev/null; then
    nc -z -w "$timeout_sec" 127.0.0.1 "$port" 2>/dev/null
    return $?
  else
    # Using /dev/tcp for port check (bash built-in)
    if timeout "$timeout_sec" bash -c "exec 3<>/dev/tcp/127.0.0.1/$port" 2>/dev/null; then
      return 0
    else
      return 1
    fi
  fi
}

# Test HTTP endpoint
test_http_endpoint() {
  local port=$1
  local endpoint=$2
  local timeout_sec=${3:-5}

  local url="http://127.0.0.1:${port}${endpoint}"
  verbose_log "Testing: $url"

  local response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout "$timeout_sec" --max-time $((timeout_sec * 2)) "$url" 2>/dev/null)

  echo "$response"
}

# Test HTTP endpoint and get response body
test_http_endpoint_with_body() {
  local port=$1
  local endpoint=$2
  local timeout_sec=${3:-5}

  local url="http://127.0.0.1:${port}${endpoint}"

  local response=$(curl -s --connect-timeout "$timeout_sec" --max-time $((timeout_sec * 2)) "$url" 2>/dev/null)

  echo "$response"
}

check_pod_logs_for_errors() {
  local pod_name=$1
  local service_name=$2
  local error_pattern=${3:-"ERROR|FATAL|Exception|Traceback"}

  local errors=$(kubectl logs -n "$NAMESPACE" "$pod_name" --tail=50 2>/dev/null | grep -ciE "$error_pattern" | tr -d ' ')
  if [ "$errors" -gt "0" ]; then
    log_warning "$service_name has $errors recent errors in logs"
    kubectl logs -n "$NAMESPACE" "$pod_name" --tail=10 2>/dev/null | grep -iE "$error_pattern" | head -3
  else
    log_success "$service_name logs are clean"
  fi
}

# ============================================
# Main Test Logic
# ============================================

# Counters
TOTAL_SERVICES=0

log_header "Testing Services"

current_port=$LOCAL_PORT_START

if [ -f "$ROOT_DIR/values.yaml" ]; then
  grep -q 'createDb: true' "$ROOT_DIR/values.yaml" && SERVICES_LIST="
$DB_SERVICE
$SERVICES_LIST"
fi

# Process each service
echo "$SERVICES_LIST" | while IFS='|' read -r service_short description container_port health_endpoint test_endpoints; do
  # Skip empty lines
  [ -z "$service_short" ] && continue

  TOTAL_SERVICES=$((TOTAL_SERVICES + 1))

  service_name="${RELEASE}-${service_short}"

  log_section "$description ($service_name)"

  # Get pod name
  pod=$(get_pod_name "$service_short")

  if [ -z "$pod" ]; then
    log_error "Pod not found for $service_name"
    echo "$service_short:FAILED:Pod not found" >>/tmp/qwc_test_results_$$
    continue
  fi

  verbose_log "Found pod: $pod"

  # Check pod status
  pod_status=$(check_pod_status "$pod")
  if [ "$pod_status" != "Running" ]; then
    log_error "Pod $pod is not running (status: $pod_status)"
    echo "$service_short:FAILED:Pod not running ($pod_status)" >>/tmp/qwc_test_results_$$
    continue
  fi

  log_success "Pod is running: $pod"

  check_pod_logs_for_errors "$pod" "$service_short"

  # Use next available port
  local_port=$current_port
  current_port=$((current_port + 1))

  # Start port-forward
  log_info "Starting port-forward $local_port -> $container_port"
  pf_pid=$(start_port_forward "$pod" "$local_port" "$container_port")
  verbose_log "Port-forward PID: $pf_pid"

  # Check if port-forward is still running
  if ! kill -0 "$pf_pid" 2>/dev/null; then
    log_error "Port-forward failed to start"
    echo "$service_short:FAILED:Port-forward failed" >>/tmp/qwc_test_results_$$
    continue
  fi

  # extract first project name from tenant to be used for qgisserver test
  if [ "$service_short" == "qwcconfigservice" ]; then
    QGIS_PROJECT=""
    CONFIG_RESPONSE=$(curl -s "http://localhost:$local_port/maps?tenant=default" 2>/dev/null)
    if [ -n "$CONFIG_RESPONSE" ]; then
      echo "$CONFIG_RESPONSE" >/tmp/config_response.json
      QGIS_PROJECT=$(echo "$CONFIG_RESPONSE" | jq -r '.[0] // empty' 2>/dev/null || echo "")
      if [ -n "$QGIS_PROJECT" ] && [ "$QGIS_PROJECT" != "null" ]; then
        log_success "Found QGIS project: $QGIS_PROJECT"
      else
        log_warning "No QGIS projects found in config - using default 'qwc_demo'"
        QGIS_PROJECT="qwc_demo"
      fi
    else
      log_warning "Could not retrieve config from config service - using default 'qwc_demo'"
      QGIS_PROJECT="qwc_demo"
    fi
  fi

  # force the use of the previously extracted project name
  if [ "$service_short" == "qwcqgisserver" ]; then
    test_endpoints="/ows/?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities&MAP=/data/$QGIS_PROJECT.qgs"
  fi

  service_passed=true

  # Test based on service type
  if [ "$health_endpoint" = "tcp" ]; then
    # TCP check (for database)
    log_info "Testing TCP connection..."
    if test_tcp_connection "$local_port" "$TIMEOUT"; then
      log_success "TCP connection successful"
    else
      log_error "TCP connection failed"
      service_passed=false
    fi
  else
    # HTTP health check
    if [ "$health_endpoint" != "none" ]; then
      log_info "Testing health endpoint: $health_endpoint"

      http_code=$(test_http_endpoint "$local_port" "$health_endpoint" "$TIMEOUT")

      if [[ "$http_code" =~ ^2[0-9][0-9]$ ]] || [[ "$http_code" =~ ^3[0-9][0-9]$ ]]; then
        log_success "Health check passed (HTTP $http_code)"
      else
        log_error "Health check failed (HTTP $http_code)"
        service_passed=false
      fi
    fi

    # Test additional endpoints
    if [ "$test_endpoints" != "none" ]; then
      # Split by comma
      IFS=',' read -ra endpoints <<<"$test_endpoints"

      for endpoint in "${endpoints[@]}"; do
        log_info "Testing endpoint: $endpoint"

        http_code=$(test_http_endpoint "$local_port" "$endpoint" "$TIMEOUT")

        if [[ "$http_code" =~ ^2[0-9][0-9]$ ]] || [[ "$http_code" =~ ^3[0-9][0-9]$ ]]; then
          log_success "Endpoint OK (HTTP $http_code)"

          # For verbose mode, show response preview
          if [ "$VERBOSE" = true ]; then
            response=$(test_http_endpoint_with_body "$local_port" "$endpoint" "$TIMEOUT")
            if [ -n "$response" ]; then
              # Truncate long responses
              response_preview=$(echo "$response" | head -c 200)
              if [ ${#response} -gt 200 ]; then
                response_preview="${response_preview}..."
              fi
              verbose_log "Response: $response_preview"
            fi
          fi
        else
          # Don't fail service for non-2xx on test endpoints (might need auth)
          if [ "$http_code" = "401" ] || [ "$http_code" = "403" ]; then
            log_warning "Endpoint returned HTTP $http_code (This endpoint may require authentication)"
          else
            log_error "Endpoint returned HTTP $http_code"
            service_passed=false
          fi
        fi
      done
    fi
  fi

  # Stop port-forward
  verbose_log "Stopping port-forward..."
  stop_port_forward "$pf_pid"

  # Record service result
  if [ "$service_passed" = true ]; then
    echo "$service_short:PASSED:" >>/tmp/qwc_test_results_$$
  else
    echo "$service_short:FAILED:" >>/tmp/qwc_test_results_$$
  fi
done

# ============================================
# Summary
# ============================================

log_header "Test Summary"

echo ""
echo -e "${BOLD}Service Results:${NC}"
echo ""

# Service summary table
printf "  %-30s %-15s %-25s\n" "SERVICE" "STATUS" "DETAILS"
printf "  %-30s %-15s %-25s\n" "──────────────────────────────" "───────────────" "─────────────────────────"

# Read results from temp file
if [ -f /tmp/qwc_test_results_$$ ]; then
  passed=0
  failed=0
  total=0

  while IFS=':' read -r service_short status details; do
    total=$((total + 1))

    # Get description from services list
    description=$(echo "$SERVICES_LIST" | grep "^$service_short|" | cut -d'|' -f2)

    if [ "$status" = "PASSED" ]; then
      printf "  %-30s ${GREEN}✓ PASSED${NC}        %-25s\n" "$description" ""
      passed=$((passed + 1))
    else
      printf "  %-30s ${RED}✗ FAILED${NC}        %-25s\n" "$description" "$details"
      failed=$((failed + 1))
    fi
  done </tmp/qwc_test_results_$$

  # Cleanup
  rm -f /tmp/qwc_test_results_$$

  echo ""
  echo -e "${BOLD}Statistics:${NC}"
  echo ""
  echo -e "  Services:  ${GREEN}$passed passed${NC} / ${RED}$failed failed${NC} / $total total"
  echo ""

  # Overall status
  if [ $failed -eq 0 ]; then
    log_success "All services are healthy!"
    exit 0
  else
    log_error "$failed service(s) failed health check"
    exit 1
  fi
else
  log_warning "No test results found (temp file missing)"
  log_info "This may happen if no services were tested"
  exit 0
fi
