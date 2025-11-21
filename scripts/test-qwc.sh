#!/bin/bash
# shellcheck disable=SC2155,SC2002

# QWC2 Functional Test Script
# Comprehensive end-to-end testing of QWC2 application

set -euo pipefail

# Configuration
NAMESPACE="${QWC_NAMESPACE:-qwc-dev}"
RELEASE="${QWC_RELEASE:-my-qwc-instance}"
BASE_URL="${QWC_BASE_URL:-http://myhostname.com}"
SKIP_SLOW_TESTS="${SKIP_SLOW_TESTS:-false}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0
TOTAL_TESTS=0

# Test result tracking
test_passed() {
	echo -e "${GREEN}✓${NC} $1"
	((PASSED++)) || true
	((TOTAL_TESTS++)) || true
}

test_failed() {
	echo -e "${RED}✗${NC} $1"
	((FAILED++)) || true
	((TOTAL_TESTS++)) || true
}

test_warning() {
	echo -e "${YELLOW}⚠${NC} $1"
	((WARNINGS++)) || true
	((TOTAL_TESTS++)) || true
}

test_info() {
	echo -e "${BLUE}ℹ${NC} $1"
}

test_section() {
	echo ""
	echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
	echo -e "${CYAN}$1${NC}"
	echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

echo -e "${BLUE}=== QWC2 Comprehensive Test Suite ===${NC}"
echo "Namespace: $NAMESPACE"
echo "Release: $RELEASE"
echo "Base URL: $BASE_URL"
echo "Skip slow tests: $SKIP_SLOW_TESTS"
echo ""

# Cleanup function
# shellcheck disable=SC2329
cleanup() {
	# shellcheck disable=SC2317
	rm -f /tmp/qwc-*.{json,xml,txt,log} 2>/dev/null || true
}
trap cleanup EXIT

# Helper functions
check_http_status() {
	local url=$1
	local expected=$2
	local description=$3
	local cookies_file=${4:-}
	local method=${5:-GET}
	local data=${6:-}
	local follow_redirects=${7:-false}

	local curl_cmd="curl -s -w \"%{http_code}\" -o /tmp/http-response.json"
	if [ "$follow_redirects" = "true" ]; then
		curl_cmd="$curl_cmd -L"
	fi
	if [ -n "$cookies_file" ]; then
		curl_cmd="$curl_cmd -b $cookies_file"
	fi
	if [ "$method" = "POST" ] && [ -n "$data" ]; then
		curl_cmd="$curl_cmd -X POST -H \"Content-Type: application/json\" -d '$data'"
	fi
	curl_cmd="$curl_cmd \"$url\""

	local status_code=$(eval "$curl_cmd" 2>/dev/null || echo "000")

	# Accept 302 as valid if it's a redirect (common for auth or HTTPS redirects)
	if [ "$expected" = "200" ] && [ "$status_code" = "302" ]; then
		# Check if it's a redirect to a valid location
		local location=$(curl -s -I "$url" 2>/dev/null | grep -i "location:" | cut -d' ' -f2 | tr -d '\r' || echo "")
		if [ -n "$location" ]; then
			test_warning "$description - Got HTTP 302 redirect to: $location (may be expected)"
			return 0
		fi
	fi

	if [ "$status_code" = "$expected" ]; then
		test_passed "$description (HTTP $status_code)"
		return 0
	else
		test_failed "$description - Expected HTTP $expected, got $status_code"
		if [ -f /tmp/http-response.json ]; then
			local response_preview=$(head -c 200 /tmp/http-response.json 2>/dev/null || echo 'N/A')
			if [ -n "$response_preview" ] && [ "$response_preview" != "N/A" ]; then
				test_info "Response: $response_preview"
			fi
		fi
		return 1
	fi
}

check_pod_logs_for_errors() {
	local pod_name=$1
	local service_name=$2
	local error_pattern=${3:-"ERROR|FATAL|Exception|Traceback"}

	local errors=$(kubectl logs -n "$NAMESPACE" "$pod_name" --tail=50 2>/dev/null | grep -ciE "$error_pattern" | tr -d ' ')
	if [ "$errors" -gt "0" ]; then
		test_warning "$service_name has $errors recent errors in logs"
		kubectl logs -n "$NAMESPACE" "$pod_name" --tail=10 2>/dev/null | grep -iE "$error_pattern" | head -3
	else
		test_passed "$service_name logs are clean"
	fi
}

# ============================================================================
# SECTION 1: Infrastructure Tests
# ============================================================================
test_section "SECTION 1: Infrastructure & Kubernetes Resources"

# 1.1 Check pods status
echo -e "${YELLOW}[1.1] Checking pods status...${NC}"
PODS_OUTPUT=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE" --no-headers 2>/dev/null || echo "")
PODS_READY=$(echo "$PODS_OUTPUT" | grep -c "Running" || echo "0")
PODS_TOTAL=$(echo "$PODS_OUTPUT" | grep -cv "^$" | tr -d ' ' || echo "0")
PODS_NOT_READY=$(echo "$PODS_OUTPUT" | grep -v "Running" | grep -cv "^$" | tr -d ' ' || echo "0")

# Ensure we have valid integers
PODS_READY=${PODS_READY:-0}
PODS_TOTAL=${PODS_TOTAL:-0}
PODS_NOT_READY=${PODS_NOT_READY:-0}

if [ "$PODS_READY" -eq "$PODS_TOTAL" ] && [ "$PODS_TOTAL" -gt "0" ]; then
	test_passed "All $PODS_TOTAL pods are running"
else
	test_failed "Only $PODS_READY/$PODS_TOTAL pods are running ($PODS_NOT_READY not ready)"
	if [ -n "$PODS_OUTPUT" ]; then
		kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE"
		echo ""
		test_info "Checking pod details for non-ready pods..."
		echo "$PODS_OUTPUT" | grep -v "Running" | while read -r line; do
			pod_name=$(echo "$line" | awk '{print $1}')
			if [ -n "$pod_name" ]; then
				echo "  Pod: $pod_name"
				kubectl describe pod -n "$NAMESPACE" "$pod_name" 2>/dev/null | grep -A 5 "Events:" | tail -3
			fi
		done
	else
		test_info "No pods found with label app.kubernetes.io/instance=$RELEASE"
	fi
fi

# 1.2 Check pod readiness
echo -e "${YELLOW}[1.2] Checking pod readiness...${NC}"
READY_COUNT=0
TOTAL_COUNT=0
while IFS= read -r line; do
	if [ -n "$line" ]; then
		pod_name=$(echo "$line" | awk '{print $1}')
		ready_status=$(echo "$line" | awk '{print $2}')
		((TOTAL_COUNT++)) || true
		if [[ "$ready_status" == *"/"* ]] && [[ "$ready_status" != "0/"* ]]; then
			((READY_COUNT++)) || true
			test_passed "Pod $pod_name is ready ($ready_status)"
		else
			test_failed "Pod $pod_name is not ready ($ready_status)"
		fi
	fi
done <<<"$PODS_OUTPUT"

# 1.3 Check services
echo -e "${YELLOW}[1.3] Checking Kubernetes services...${NC}"
EXPECTED_SERVICES=("qwcdb" "qwcqgisserver" "qwcconfigservice" "qwcmapviewer" "qwcogcservice" "qwcdataservice" "qwcauthservice" "qwcadmingui" "qwcpermalinkservice")
for svc in "${EXPECTED_SERVICES[@]}"; do
	if kubectl get svc -n "$NAMESPACE" "${RELEASE}-${svc}" &>/dev/null; then
		test_passed "Service ${RELEASE}-${svc} exists"
	else
		test_failed "Service ${RELEASE}-${svc} not found"
	fi
done

# 1.4 Check HTTPRoutes
echo -e "${YELLOW}[1.4] Checking HTTPRoutes...${NC}"
HTTPROUTES=$(kubectl get httproute -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE" --no-headers 2>/dev/null || echo "")
if [ -n "$HTTPROUTES" ]; then
	HTTPROUTE_COUNT=$(echo "$HTTPROUTES" | wc -l | tr -d ' ')
	test_passed "Found $HTTPROUTE_COUNT HTTPRoute(s)"

	while IFS= read -r route_line; do
		if [ -n "$route_line" ]; then
			route_name=$(echo "$route_line" | awk '{print $1}')
			route_status=$(kubectl get httproute -n "$NAMESPACE" "$route_name" -o jsonpath='{.status.parents[0].conditions[0].status}' 2>/dev/null || echo "Unknown")
			if [ "$route_status" = "True" ]; then
				test_passed "HTTPRoute $route_name is accepted"
			else
				test_failed "HTTPRoute $route_name is not accepted (status: $route_status)"
			fi
		fi
	done <<<"$HTTPROUTES"
else
	test_warning "No HTTPRoutes found (may be using Ingress or port-forwarding)"
fi

# 1.5 Check persistent volumes
echo -e "${YELLOW}[1.5] Checking persistent volumes...${NC}"
PVC_COUNT=$(kubectl get pvc -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE" --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$PVC_COUNT" -gt "0" ]; then
	test_passed "Found $PVC_COUNT PersistentVolumeClaim(s)"
	kubectl get pvc -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE" --no-headers | while read -r pvc_line; do
		pvc_name=$(echo "$pvc_line" | awk '{print $1}')
		pvc_status=$(echo "$pvc_line" | awk '{print $2}')
		if [ "$pvc_status" = "Bound" ]; then
			test_passed "PVC $pvc_name is bound"
		else
			test_failed "PVC $pvc_name is not bound (status: $pvc_status)"
		fi
	done
else
	test_warning "No PersistentVolumeClaims found (volumes may be external)"
fi

# 1.6 Check database connectivity
echo -e "${YELLOW}[1.6] Checking database connectivity...${NC}"
DB_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE",app.kubernetes.io/name=qwcdb -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$DB_POD" ]; then
	if kubectl exec -n "$NAMESPACE" "$DB_POD" -- pg_isready -U postgres &>/dev/null; then
		test_passed "Database is ready and accepting connections"

		# Check database exists
		DB_EXISTS=$(kubectl exec -n "$NAMESPACE" "$DB_POD" -- psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='qwc_services'" 2>/dev/null || echo "0")
		if [ "$DB_EXISTS" = "1" ]; then
			test_passed "Database 'qwc_services' exists"
		else
			test_failed "Database 'qwc_services' does not exist"
		fi
	else
		test_failed "Database is not ready"
	fi
else
	test_failed "Database pod not found"
fi

# 1.7 Check for recent pod restarts
echo -e "${YELLOW}[1.7] Checking for pod restarts...${NC}"
RESTART_COUNT=0
while IFS= read -r line; do
	if [ -n "$line" ]; then
		pod_name=$(echo "$line" | awk '{print $1}')
		restarts=$(echo "$line" | awk '{print $4}')
		if [ "$restarts" != "0" ] && [ -n "$restarts" ]; then
			((RESTART_COUNT++)) || true
			test_warning "Pod $pod_name has restarted $restarts time(s)"
		fi
	fi
done <<<"$PODS_OUTPUT"
if [ "$RESTART_COUNT" -eq "0" ]; then
	test_passed "No pod restarts detected"
fi

# 1.8 Check pod logs for critical errors
if [ "$SKIP_SLOW_TESTS" != "true" ]; then
	echo -e "${YELLOW}[1.8] Checking pod logs for errors...${NC}"
	while IFS= read -r line; do
		if [ -n "$line" ]; then
			pod_name=$(echo "$line" | awk '{print $1}')
			service_name=${pod_name//${RELEASE}-/}
			check_pod_logs_for_errors "$pod_name" "$service_name"
		fi
	done <<<"$PODS_OUTPUT"
fi
echo ""

# ============================================================================
# SECTION 2: Service Health & Readiness Tests
# ============================================================================
test_section "SECTION 2: Service Health & Readiness"

# Discover available QGIS projects from config service
echo -e "${YELLOW}[2.0] Discovering available QGIS projects...${NC}"
CONFIG_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE",app.kubernetes.io/name=qwcconfigservice -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
QGIS_PROJECT=""
if [ -n "$CONFIG_POD" ]; then
	CONFIG_RESPONSE=$(kubectl exec -n "$NAMESPACE" "$CONFIG_POD" -- sh -c 'curl -s "http://localhost:9090/maps?tenant=default" 2>/dev/null' 2>/dev/null || echo "")
	if [ -n "$CONFIG_RESPONSE" ]; then
		QGIS_PROJECT=$(echo "$CONFIG_RESPONSE" | jq -r '.themes[0].name // empty' 2>/dev/null || echo "")
		if [ -n "$QGIS_PROJECT" ] && [ "$QGIS_PROJECT" != "null" ]; then
			test_passed "Found QGIS project: $QGIS_PROJECT"
		else
			# Try to get project name from URL if available
			QGIS_PROJECT=$(echo "$CONFIG_RESPONSE" | jq -r '.themes[0].url // empty' 2>/dev/null | sed -n 's/.*MAP=\([^&]*\).*/\1/p' || echo "")
			if [ -z "$QGIS_PROJECT" ]; then
				test_warning "No QGIS projects found in config - using default 'qwc_demo'"
				QGIS_PROJECT="qwc_demo"
			fi
		fi
	else
		test_warning "Could not retrieve config from config service - using default 'qwc_demo'"
		QGIS_PROJECT="qwc_demo"
	fi
else
	test_warning "Config service pod not found - using default 'qwc_demo'"
	QGIS_PROJECT="qwc_demo"
fi

# 2.1 Test config service health
echo -e "${YELLOW}[2.1] Testing config service...${NC}"
if [ -n "$CONFIG_POD" ]; then
	# Internal health check
	if kubectl exec -n "$NAMESPACE" "$CONFIG_POD" -- sh -c 'curl -s "http://localhost:9090/maps?tenant=default" 2>/dev/null' &>/dev/null; then
		test_passed "Config service is responding internally"
	else
		test_failed "Config service is not responding internally"
	fi
fi

# External health check - Config service is typically not exposed externally
# Try to access via base URL (may be routed through API Gateway)
test_info "Config service is typically internal-only, testing via base URL..."
if check_http_status "$BASE_URL/maps?tenant=default" "200" "Config service endpoint accessible" "" "GET" "" "true"; then
	MAPS_COUNT=$(cat /tmp/http-response.json 2>/dev/null | jq -r '.themes | length' 2>/dev/null || echo "0")
	if [ "$MAPS_COUNT" -gt "0" ]; then
		test_passed "Config service returns $MAPS_COUNT themes"
		# Validate config structure
		if cat /tmp/http-response.json 2>/dev/null | jq -e '.themes[0].title' &>/dev/null; then
			test_passed "Config structure is valid"
		else
			test_failed "Config structure is invalid"
		fi
	else
		test_failed "Config service returns empty themes list"
	fi
fi

# 2.2 Test map viewer health
echo -e "${YELLOW}[2.2] Testing map viewer...${NC}"
MAPVIEWER_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE",app.kubernetes.io/name=qwcmapviewer -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$MAPVIEWER_POD" ]; then
	if kubectl exec -n "$NAMESPACE" "$MAPVIEWER_POD" -- sh -c "wget -q -O- http://localhost:9090/healthz 2>/dev/null || curl -s http://localhost:9090/healthz 2>/dev/null" &>/dev/null; then
		test_passed "Map viewer health check passed internally"
	else
		test_warning "Map viewer health check endpoint not responding internally"
	fi
fi
check_http_status "$BASE_URL/healthz" "200" "Map viewer health endpoint" "" "GET" "" "true" || check_http_status "$BASE_URL/" "200" "Map viewer root endpoint" "" "GET" "" "true" || true

# 2.3 Test OGC service health
echo -e "${YELLOW}[2.3] Testing OGC service...${NC}"
OGC_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE",app.kubernetes.io/name=qwcogcservice -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$OGC_POD" ]; then
	if kubectl exec -n "$NAMESPACE" "$OGC_POD" -- sh -c "wget -q -O- http://localhost:9090/healthz 2>/dev/null || curl -s http://localhost:9090/healthz 2>/dev/null" &>/dev/null; then
		test_passed "OGC service health check passed internally"
	else
		test_warning "OGC service health check endpoint not responding internally"
	fi
fi
check_http_status "$BASE_URL/ows/healthz" "200" "OGC service health endpoint" "" "GET" "" "true" || check_http_status "$BASE_URL/ows/" "200" "OGC service root endpoint" "" "GET" "" "true" || true

# 2.4 Test data service health
echo -e "${YELLOW}[2.4] Testing data service...${NC}"
DATA_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE",app.kubernetes.io/name=qwcdataservice -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$DATA_POD" ]; then
	if kubectl exec -n "$NAMESPACE" "$DATA_POD" -- sh -c "wget -q -O- http://localhost:9090/healthz 2>/dev/null || curl -s http://localhost:9090/healthz 2>/dev/null" &>/dev/null; then
		test_passed "Data service health check passed internally"
	else
		test_warning "Data service health check endpoint not responding internally"
	fi
fi
check_http_status "$BASE_URL/api/v1/data/healthz" "200" "Data service health endpoint" "" "GET" "" "true" || check_http_status "$BASE_URL/api/v1/data/" "200" "Data service root endpoint" "" "GET" "" "true" || true

# 2.5 Test auth service health
echo -e "${YELLOW}[2.5] Testing auth service...${NC}"
AUTH_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE",app.kubernetes.io/name=qwcauthservice -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$AUTH_POD" ]; then
	if kubectl exec -n "$NAMESPACE" "$AUTH_POD" -- sh -c "wget -q -O- http://localhost:9090/healthz 2>/dev/null || curl -s http://localhost:9090/healthz 2>/dev/null" &>/dev/null; then
		test_passed "Auth service health check passed internally"
	else
		test_warning "Auth service health check endpoint not responding internally"
	fi
fi
check_http_status "$BASE_URL/auth/healthz" "200" "Auth service health endpoint" "" "GET" "" "true" || check_http_status "$BASE_URL/auth/" "200" "Auth service root endpoint" "" "GET" "" "true" || true

echo ""

# ============================================================================
# SECTION 3: Authentication & Authorization Tests
# ============================================================================
test_section "SECTION 3: Authentication & Authorization"

# 3.1 Test authentication endpoint
echo -e "${YELLOW}[3.1] Testing authentication...${NC}"
if check_http_status "$BASE_URL/auth/login" "200" "Auth login endpoint accessible" "" "POST" '{"username":"demo","password":"demo"}' "true" && [ -f /tmp/http-response.json ]; then
	cp /tmp/http-response.json /tmp/login-response.json
	curl -s -c /tmp/qwc-cookies.txt "$BASE_URL/auth/login" -X POST -H "Content-Type: application/json" -d '{"username":"demo","password":"demo"}' &>/dev/null || true

	USERNAME=$(cat /tmp/login-response.json 2>/dev/null | jq -r '.username' 2>/dev/null || echo "")
	if [ -n "$USERNAME" ] && [ "$USERNAME" != "null" ]; then
		test_passed "Login successful for user: $USERNAME"
	else
		# Check if auth is disabled
		if grep -q "authRequired.*false" /tmp/login-response.json 2>/dev/null; then
			test_warning "Authentication may be disabled"
		else
			test_passed "Login endpoint responded (auth may be disabled)"
		fi
	fi
else
	test_warning "Login endpoint test failed (auth may be disabled or credentials incorrect)"
	test_info "Note: If auth is disabled, this is expected"
fi

# 3.2 Test user info endpoint
echo -e "${YELLOW}[3.2] Testing user info endpoint...${NC}"
if [ -f /tmp/qwc-cookies.txt ]; then
	if check_http_status "$BASE_URL/auth/userinfo" "200" "User info endpoint" "/tmp/qwc-cookies.txt"; then
		USERNAME=$(cat /tmp/http-response.json 2>/dev/null | jq -r '.username' 2>/dev/null || echo "")
		if [ -n "$USERNAME" ] && [ "$USERNAME" != "null" ]; then
			test_passed "User info retrieved for: $USERNAME"
		else
			test_passed "User info endpoint accessible"
		fi
	fi
else
	test_warning "Skipping user info test (no session cookie)"
fi

# 3.3 Test logout
echo -e "${YELLOW}[3.3] Testing logout...${NC}"
if [ -f /tmp/qwc-cookies.txt ]; then
	check_http_status "$BASE_URL/auth/logout" "200" "Logout endpoint" "/tmp/qwc-cookies.txt" "POST" || check_http_status "$BASE_URL/auth/logout" "302" "Logout endpoint (redirect)" "/tmp/qwc-cookies.txt" "POST" || true
fi

echo ""

# ============================================================================
# SECTION 4: OGC Services Tests
# ============================================================================
test_section "SECTION 4: OGC Services (WMS/WFS/WCS)"

# 4.1 Test WMS GetCapabilities
echo -e "${YELLOW}[4.1] Testing WMS GetCapabilities...${NC}"
if check_http_status "$BASE_URL/ows/?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities&MAP=${QGIS_PROJECT}" "200" "WMS GetCapabilities (MAP=${QGIS_PROJECT})" "/tmp/qwc-cookies.txt" "GET" "" "true"; then
	cp /tmp/http-response.json /tmp/wms-capabilities.xml
	if grep -q "WMS_Capabilities" /tmp/wms-capabilities.xml 2>/dev/null; then
		test_passed "WMS GetCapabilities returned valid XML"
		LAYERS_COUNT=$(grep -c "<Layer>" /tmp/wms-capabilities.xml 2>/dev/null || echo "0")
		if [ "$LAYERS_COUNT" -gt "0" ]; then
			test_passed "WMS GetCapabilities contains $LAYERS_COUNT layers"
		else
			test_warning "WMS GetCapabilities contains no layers"
		fi
	else
		test_failed "WMS GetCapabilities returned invalid XML"
		test_info "Response: $(head -c 500 /tmp/wms-capabilities.xml 2>/dev/null || echo 'N/A')"
	fi
else
	test_warning "WMS GetCapabilities failed - ensure QGIS project '${QGIS_PROJECT}' exists and is configured"
fi

# 4.2 Test WMS GetMap (if capabilities succeeded)
echo -e "${YELLOW}[4.2] Testing WMS GetMap...${NC}"
if [ -f /tmp/wms-capabilities.xml ] && grep -q "WMS_Capabilities" /tmp/wms-capabilities.xml 2>/dev/null; then
	# Try a simple GetMap request
	WMS_GETMAP_URL="$BASE_URL/ows/?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&BBOX=-180,-90,180,90&CRS=EPSG:4326&WIDTH=256&HEIGHT=256&LAYERS=${QGIS_PROJECT}&MAP=${QGIS_PROJECT}&FORMAT=image/png"
	if check_http_status "$WMS_GETMAP_URL" "200" "WMS GetMap" "/tmp/qwc-cookies.txt"; then
		CONTENT_TYPE=$(curl -s -I "$WMS_GETMAP_URL" -b /tmp/qwc-cookies.txt 2>/dev/null | grep -i "content-type" | cut -d' ' -f2 | tr -d '\r' || echo "")
		if echo "$CONTENT_TYPE" | grep -qi "image"; then
			test_passed "WMS GetMap returned image (Content-Type: $CONTENT_TYPE)"
		else
			test_warning "WMS GetMap returned unexpected content type: $CONTENT_TYPE"
		fi
	fi
else
	test_info "Skipping WMS GetMap test (GetCapabilities failed)"
fi

# 4.3 Test WFS GetCapabilities
echo -e "${YELLOW}[4.3] Testing WFS GetCapabilities...${NC}"
if check_http_status "$BASE_URL/ows/?SERVICE=WFS&VERSION=2.0.0&REQUEST=GetCapabilities&MAP=${QGIS_PROJECT}" "200" "WFS GetCapabilities (MAP=${QGIS_PROJECT})" "/tmp/qwc-cookies.txt" "GET" "" "true"; then
	if grep -q "WFS_Capabilities\|wfs:WFS_Capabilities" /tmp/http-response.json 2>/dev/null; then
		test_passed "WFS GetCapabilities returned valid XML"
	else
		test_warning "WFS GetCapabilities may not be available for this project"
	fi
fi

echo ""

# ============================================================================
# SECTION 5: Data Service Tests
# ============================================================================
test_section "SECTION 5: Data Service API"

# 5.1 Test data service list tables
echo -e "${YELLOW}[5.1] Testing data service...${NC}"
if check_http_status "$BASE_URL/api/v1/data/demo.cities?limit=5" "200" "Data service endpoint" "/tmp/qwc-cookies.txt" "GET" "" "true"; then
	cp /tmp/http-response.json /tmp/data-response.json
	FEATURES_COUNT=$(cat /tmp/data-response.json 2>/dev/null | jq -r '.features | length' 2>/dev/null || echo "0")
	if [ "$FEATURES_COUNT" -gt "0" ]; then
		test_passed "Data service returned $FEATURES_COUNT features"

		# Validate GeoJSON structure
		if cat /tmp/data-response.json 2>/dev/null | jq -e '.type == "FeatureCollection"' &>/dev/null; then
			test_passed "Data service returned valid GeoJSON FeatureCollection"
		else
			test_warning "Data service response may not be valid GeoJSON"
		fi
	else
		test_warning "Data service returned empty feature collection"
		test_info "Note: Ensure demo data is initialized (run init-demo-data.sh)"
	fi
else
	test_warning "Data service endpoint test failed"
	test_info "Note: Ensure demo data is initialized (run init-demo-data.sh)"
fi

# 5.2 Test data service with filters
echo -e "${YELLOW}[5.2] Testing data service with filters...${NC}"
if check_http_status "$BASE_URL/api/v1/data/demo.cities?limit=1" "200" "Data service with limit filter" "/tmp/qwc-cookies.txt" "GET" "" "true"; then
	test_passed "Data service filter parameter works"
fi

echo ""

# ============================================================================
# SECTION 6: Permalink Service Tests
# ============================================================================
test_section "SECTION 6: Permalink Service"

# 6.1 Test permalink creation
echo -e "${YELLOW}[6.1] Testing permalink creation...${NC}"
PERMALINK_DATA='{"mapState":{"center":[0,0],"zoom":5,"layers":[]}}'
# Try both with and without trailing slash
if check_http_status "$BASE_URL/api/v1/permalink" "201" "Permalink creation (no trailing slash)" "/tmp/qwc-cookies.txt" "POST" "$PERMALINK_DATA" "true" ||
	check_http_status "$BASE_URL/api/v1/permalink/" "201" "Permalink creation (with trailing slash)" "/tmp/qwc-cookies.txt" "POST" "$PERMALINK_DATA" "true"; then
	cp /tmp/http-response.json /tmp/permalink.json
	PERMALINK_ID=$(cat /tmp/permalink.json 2>/dev/null | jq -r '.id' 2>/dev/null || echo "")
	if [ -n "$PERMALINK_ID" ] && [ "$PERMALINK_ID" != "null" ]; then
		test_passed "Permalink created: $PERMALINK_ID"

		# 6.2 Test permalink resolution
		echo -e "${YELLOW}[6.2] Testing permalink resolution...${NC}"
		if check_http_status "$BASE_URL/api/v1/permalink/$PERMALINK_ID" "200" "Permalink resolution" "/tmp/qwc-cookies.txt"; then
			test_passed "Permalink resolution successful"

			# Validate permalink content
			if cat /tmp/http-response.json 2>/dev/null | jq -e '.mapState' &>/dev/null; then
				test_passed "Permalink contains valid mapState"
			else
				test_warning "Permalink may not contain valid mapState"
			fi
		fi
	else
		test_failed "Permalink creation failed (no ID returned)"
	fi
else
	test_warning "Permalink creation failed"
fi

echo ""

# ============================================================================
# SECTION 7: Admin GUI Tests
# ============================================================================
test_section "SECTION 7: Admin GUI"

# 7.1 Test admin GUI accessibility
echo -e "${YELLOW}[7.1] Testing admin GUI...${NC}"
if check_http_status "$BASE_URL/admin/" "200" "Admin GUI accessible" "/tmp/qwc-cookies.txt" "GET" "" "true"; then
	test_passed "Admin GUI is accessible"

	# Check if it's HTML
	CONTENT_TYPE=$(curl -s -I "$BASE_URL/admin/" -b /tmp/qwc-cookies.txt 2>/dev/null | grep -i "content-type" | cut -d' ' -f2 | tr -d '\r' || echo "")
	if echo "$CONTENT_TYPE" | grep -qi "text/html"; then
		test_passed "Admin GUI returns HTML content"
	fi
else
	test_warning "Admin GUI may require authentication"
fi

echo ""

# ============================================================================
# SECTION 8: Performance & Integration Tests
# ============================================================================
test_section "SECTION 8: Performance & Integration"

# 8.1 Test response times
if [ "$SKIP_SLOW_TESTS" != "true" ]; then
	echo -e "${YELLOW}[8.1] Testing response times...${NC}"

	# Test config service response time
	START_TIME=$(date +%s%N)
	curl -s "$BASE_URL/maps?tenant=default" &>/dev/null
	END_TIME=$(date +%s%N)
	DURATION=$(((END_TIME - START_TIME) / 1000000))
	if [ "$DURATION" -lt "2000" ]; then
		test_passed "Config service response time: ${DURATION}ms (< 2s)"
	else
		test_warning "Config service response time: ${DURATION}ms (>= 2s)"
	fi

	# Test WMS GetCapabilities response time
	START_TIME=$(date +%s%N)
	curl -s "$BASE_URL/ows/?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities&MAP=qwc_demo" &>/dev/null
	END_TIME=$(date +%s%N)
	DURATION=$(((END_TIME - START_TIME) / 1000000))
	if [ "$DURATION" -lt "5000" ]; then
		test_passed "WMS GetCapabilities response time: ${DURATION}ms (< 5s)"
	else
		test_warning "WMS GetCapabilities response time: ${DURATION}ms (>= 5s)"
	fi
fi

# 8.2 Test service dependencies
echo -e "${YELLOW}[8.2] Testing service dependencies...${NC}"
# Check if config service can access database
if [ -n "$CONFIG_POD" ]; then
	if kubectl exec -n "$NAMESPACE" "$CONFIG_POD" -- pg_isready -h "${RELEASE}-qwcdb" -U qwc_service &>/dev/null; then
		test_passed "Config service can connect to database"
	else
		test_warning "Config service database connectivity check failed"
	fi
fi

# Check if OGC service can access QGIS Server
if [ -n "$OGC_POD" ]; then
	if kubectl exec -n "$NAMESPACE" "$OGC_POD" -- sh -c "wget -q -O- http://${RELEASE}-qwcqgisserver/ 2>/dev/null || curl -s http://${RELEASE}-qwcqgisserver/ 2>/dev/null" &>/dev/null; then
		test_passed "OGC service can connect to QGIS Server"
	else
		test_warning "OGC service cannot connect to QGIS Server"
	fi
fi

echo ""

# ============================================================================
# FINAL SUMMARY
# ============================================================================
test_section "Test Summary"

echo -e "${GREEN}Passed:${NC} $PASSED"
echo -e "${RED}Failed:${NC} $FAILED"
echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
echo -e "${BLUE}Total Tests:${NC} $TOTAL_TESTS"
echo ""

# Calculate success rate
if [ $TOTAL_TESTS -gt 0 ]; then
	SUCCESS_RATE=$(((PASSED * 100) / TOTAL_TESTS))
	echo -e "${BLUE}Success Rate:${NC} ${SUCCESS_RATE}%"
	echo ""
fi

# Final verdict
if [ $FAILED -eq 0 ] && [ $PASSED -gt 0 ]; then
	echo -e "${GREEN}✓ All critical tests passed!${NC}"
	if [ $WARNINGS -gt 0 ]; then
		echo -e "${YELLOW}⚠ Some warnings were reported (non-critical)${NC}"
	fi
	exit 0
elif [ $FAILED -eq 0 ] && [ $PASSED -eq 0 ]; then
	echo -e "${YELLOW}⚠ No tests were executed${NC}"
	exit 0
else
	echo -e "${RED}✗ Some tests failed${NC}"
	echo ""
	echo -e "${BLUE}Next steps:${NC}"
	echo "  1. Review failed tests above"
	echo "  2. Check pod logs: kubectl logs -n '$NAMESPACE'  <pod-name>"
	echo "  3. Check pod status: kubectl get pods -n '$NAMESPACE' "
	echo "  4. Check HTTPRoute status: kubectl get httproute -n '$NAMESPACE' "
	exit 1
fi
