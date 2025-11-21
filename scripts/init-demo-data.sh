#!/bin/bash

# QWC2 Demo Data Initialization Script
# This script initializes the QWC2 database with demo data for testing purposes.
#
# Usage:
#   ./init-demo-data.sh [OPTIONS]
#
# Options:
#   --namespace NS        Kubernetes namespace (default: qwc-dev, or interactive)
#   --release NAME        Helm release name (auto-detected from pods if not specified)
#   --database DB         Database name (default: qwc_services)
#   --skip-users          Skip creating demo users
#   --skip-geodata        Skip creating demo geospatial data
#   --yes                 Skip interactive prompts (use defaults)
#   --help                Show this help message

set -euo pipefail

# Default values
DEFAULT_NAMESPACE="qwc-dev"
NAMESPACE="${NAMESPACE:-}"
RELEASE_NAME="${RELEASE_NAME:-}"
DB_HOST="${DB_HOST:-}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-qwc_services}"
ADMIN_USER="${ADMIN_USER:-qwc_admin}"
ADMIN_PASS="${ADMIN_PASS:-}"
SUPERUSER="${SUPERUSER:-postgres}"
SUPERUSER_PASS="${SUPERUSER_PASS:-}"
SKIP_USERS=false
SKIP_GEODATA=false
INTERACTIVE=true
PORT_FORWARD_PID=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Cleanup function to stop port-forward on exit
cleanup() {
	if [ -n "$PORT_FORWARD_PID" ]; then
		echo -e "${YELLOW}Stopping port-forward (PID: $PORT_FORWARD_PID)...${NC}"
		kill "$PORT_FORWARD_PID" 2>/dev/null || true
		wait "$PORT_FORWARD_PID" 2>/dev/null || true
	fi
}
trap cleanup EXIT

# Parse command line arguments
while [[ $# -gt 0 ]]; do
	case $1 in
	--namespace | -n)
		NAMESPACE="$2"
		shift 2
		;;
	--release)
		RELEASE_NAME="$2"
		shift 2
		;;
	--database)
		DB_NAME="$2"
		shift 2
		;;
	--skip-users)
		SKIP_USERS=true
		shift
		;;
	--skip-geodata)
		SKIP_GEODATA=true
		shift
		;;
	--yes | -y)
		INTERACTIVE=false
		shift
		;;
	--help)
		echo "Usage: ./init-demo-data.sh [OPTIONS]"
		echo ""
		echo "This script initializes QWC2 with demo data including:"
		echo "  - Demo users (admin/demo, demo/demo)"
		echo "  - Demo geospatial data (cities, roads, regions)"
		echo "  - Demo QGIS project"
		echo "  - Demo theme configuration"
		echo ""
		echo "Options:"
		echo "  --namespace, -n NS    Kubernetes namespace (default: $DEFAULT_NAMESPACE)"
		echo "  --release NAME        Helm release name (auto-detected from pods)"
		echo "  --database DB         Database name (default: qwc_services)"
		echo "  --skip-users          Skip creating demo users"
		echo "  --skip-geodata        Skip creating demo geospatial data"
		echo "  --yes, -y             Skip interactive prompts (use defaults)"
		echo "  --help                Show this help message"
		exit 0
		;;
	*)
		echo -e "${RED}Unknown option: $1${NC}"
		echo "Use --help for usage information."
		exit 1
		;;
	esac
done

# Interactive namespace prompt
if [ -z "$NAMESPACE" ]; then
	if [ "$INTERACTIVE" = true ]; then
		echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
		echo -e "${CYAN}║         QWC2 Demo Data Initialization Script               ║${NC}"
		echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
		echo ""
		read -r -p "Enter Kubernetes namespace [${DEFAULT_NAMESPACE}]: " INPUT_NAMESPACE
		NAMESPACE="${INPUT_NAMESPACE:-$DEFAULT_NAMESPACE}"
	else
		NAMESPACE="$DEFAULT_NAMESPACE"
	fi
fi

echo ""
echo -e "${GREEN}=== Using kubectl exec mode (superuser) ===${NC}"
echo -e "Namespace: ${YELLOW}$NAMESPACE${NC}"

# Find the database pod
DB_POD=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=qwcdb" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$DB_POD" ]; then
	# Try alternative label
	DB_POD=$(kubectl get pods -n "$NAMESPACE" | grep -E "qwcdb|qwc-db" | awk '{print $1}' | head -1 || echo "")
fi

if [ -z "$DB_POD" ]; then
	echo -e "${RED}Error: Cannot find database pod in namespace '$NAMESPACE'.${NC}"
	echo -e "${YELLOW}Available pods:${NC}"
	kubectl get pods -n "$NAMESPACE" 2>/dev/null || echo "Cannot list pods"
	exit 1
fi

echo -e "Database pod: ${YELLOW}$DB_POD${NC}"

# Auto-detect release name from pod name if not specified
if [ -z "$RELEASE_NAME" ]; then
	# Extract release name from db pod name (e.g., qwc-services-qwcdb-xxx -> qwc-services)
	RELEASE_NAME=${DB_POD//-qwcdb.*/}
	echo -e "Detected release name: ${YELLOW}$RELEASE_NAME${NC}"
fi

echo ""

# Define execute_sql function for kubectl exec mode
execute_sql() {
	local sql="$1"
	kubectl exec -n "$NAMESPACE" "$DB_POD" -- psql -U postgres -d "$DB_NAME" -c "$sql" 2>/dev/null
}

execute_sql_file() {
	local file="$1"
	kubectl exec -i -n "$NAMESPACE" "$DB_POD" -- psql -U postgres -d "$DB_NAME" <"$file" 2>/dev/null
}

echo -e "${GREEN}=== QWC2 Demo Data Initialization ===${NC}"
echo "Database: $DB_POD:5432/$DB_NAME (via kubectl exec)"
echo "User: postgres (superuser)"
echo ""

# Test database connection
echo -e "${GREEN}[1/4] Testing database connection...${NC}"
if ! execute_sql "SELECT 1;" >/dev/null 2>&1; then
	echo -e "${RED}Error: Cannot connect to database. Please check connection parameters.${NC}"
	exit 1
fi
echo -e "${GREEN}✓ Database connection successful${NC}"

# Check if PostGIS extension exists
echo -e "${GREEN}[2/4] Checking PostGIS extension...${NC}"
POSTGIS_VERSION=$(execute_sql "SELECT PostGIS_version();" 2>/dev/null | grep -v "row" | grep -v "postgis_version" | grep -v "^-" | xargs || echo "")
if [ -z "$POSTGIS_VERSION" ]; then
	echo -e "${YELLOW}PostGIS extension not found. Creating it...${NC}"
	execute_sql "CREATE EXTENSION IF NOT EXISTS postgis;"
	echo -e "${GREEN}✓ PostGIS extension created${NC}"
else
	echo -e "${GREEN}✓ PostGIS extension found (version: $POSTGIS_VERSION)${NC}"
fi

# Create demo users
if [ "$SKIP_USERS" = false ]; then
	echo -e "${GREEN}[3/4] Creating/updating demo users...${NC}"

	# Check if users table exists in qwc_config schema
	if execute_sql "SELECT 1 FROM information_schema.tables WHERE table_schema='qwc_config' AND table_name='users';" | grep -q "1"; then

		# Find auth-service pod to generate Werkzeug-compatible password hashes
		AUTH_POD=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=qwcauthservice" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

		if [ -z "$AUTH_POD" ]; then
			AUTH_POD=$(kubectl get pods -n "$NAMESPACE" | grep -E "authservice|qwcauthservice" | awk '{print $1}' | head -1 || echo "")
		fi

		if [ -n "$AUTH_POD" ]; then
			echo "Using auth-service pod to generate Werkzeug-compatible password hash..."

			# Generate Werkzeug-compatible password hash using Python in auth-service venv
			DEMO_HASH=$(kubectl exec -n "$NAMESPACE" "$AUTH_POD" -- /srv/qwc_service/.venv/bin/python -c "from werkzeug.security import generate_password_hash; print(generate_password_hash('demo'))" 2>/dev/null)

			if [ -n "$DEMO_HASH" ]; then
				echo "Generated Werkzeug password hash successfully"

				# Ensure password_hash column can hold scrypt hashes (they are ~200 chars)
				execute_sql "ALTER TABLE qwc_config.users ALTER COLUMN password_hash TYPE VARCHAR(256);" 2>/dev/null || true

				# Update admin user password to 'demo' and disable force_password_change
				echo "Updating admin user password to 'demo'..."
				execute_sql "
                UPDATE qwc_config.users
                SET password_hash = '$DEMO_HASH',
                    force_password_change = false
                WHERE name = 'admin';
                " || echo -e "${YELLOW}Note: Could not update admin user${NC}"

				# Create demo regular user if it doesn't exist
				echo "Creating demo regular user (demo/demo)..."
				execute_sql "
                INSERT INTO qwc_config.users (name, description, email, password_hash, force_password_change)
                VALUES ('demo', 'Demo User for Testing', 'demo@example.com', '$DEMO_HASH', false)
                ON CONFLICT (name) DO UPDATE
                SET password_hash = '$DEMO_HASH',
                    force_password_change = false;
                " || echo -e "${YELLOW}Note: Demo user may already exist${NC}"
			else
				echo -e "${YELLOW}Warning: Could not generate Werkzeug password hash. Using fallback method.${NC}"
				echo -e "${RED}Please manually reset passwords via admin GUI after deployment.${NC}"
			fi
		else
			echo -e "${YELLOW}Warning: Auth-service pod not found. Cannot generate proper password hash.${NC}"
			echo -e "${YELLOW}Please manually reset passwords via admin GUI after deployment.${NC}"
		fi

		# Get admin user ID and assign admin role
		echo "Ensuring admin role assignment..."
		execute_sql "
        INSERT INTO qwc_config.users_roles (user_id, role_id)
        SELECT u.id, r.id
        FROM qwc_config.users u, qwc_config.roles r
        WHERE u.name = 'admin' AND r.name = 'admin'
        ON CONFLICT DO NOTHING;
        " 2>/dev/null || true

		# Create demo group if it doesn't exist
		echo "Creating demo group..."
		execute_sql "
        INSERT INTO qwc_config.groups (name, description)
        VALUES ('demo_group', 'Demo Group for Testing')
        ON CONFLICT (name) DO NOTHING;
        " 2>/dev/null || true

		# Add demo user to demo group
		echo "Adding demo user to demo_group..."
		execute_sql "
        INSERT INTO qwc_config.groups_users (group_id, user_id)
        SELECT g.id, u.id
        FROM qwc_config.groups g, qwc_config.users u
        WHERE g.name = 'demo_group' AND u.name = 'demo'
        ON CONFLICT DO NOTHING;
        " 2>/dev/null || true

		echo -e "${GREEN}✓ Demo users configured${NC}"
		echo -e "  ${YELLOW}Admin user:${NC} admin / demo"
		echo -e "  ${YELLOW}Demo user:${NC} demo / demo"
	else
		echo -e "${YELLOW}Users table not found in qwc_config schema. Skipping user creation.${NC}"
		echo -e "${YELLOW}Please ensure database migration has been run.${NC}"
	fi
else
	echo -e "${YELLOW}[3/4] Skipping demo user creation${NC}"
fi

# Create demo geospatial data
if [ "$SKIP_GEODATA" = false ]; then
	echo -e "${GREEN}[4/4] Creating demo geospatial data...${NC}"

	# Check if we need to use postgres superuser for schema operations
	# Try with current user first, fall back to checking permissions
	echo "Creating demo schema..."
	if ! execute_sql "CREATE SCHEMA IF NOT EXISTS demo;" 2>/dev/null; then
		echo -e "${YELLOW}Note: Cannot create schema with current user. Demo geodata may require superuser.${NC}"
		echo -e "${YELLOW}Run with --skip-geodata or use postgres superuser.${NC}"
	else
		# Grant permissions (may fail if roles don't exist, that's OK)
		execute_sql "GRANT USAGE ON SCHEMA demo TO qwc_service;" 2>/dev/null || true
		execute_sql "GRANT USAGE ON SCHEMA demo TO qwc_service_write;" 2>/dev/null || true
		execute_sql "GRANT ALL ON SCHEMA demo TO qwc_service_write;" 2>/dev/null || true

		# Create demo points table (cities)
		echo "Creating demo points layer (cities)..."
		execute_sql "
        CREATE TABLE IF NOT EXISTS demo.cities (
            id SERIAL PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            population INTEGER,
            country VARCHAR(50),
            geom GEOMETRY(POINT, 3857)
        );

        CREATE INDEX IF NOT EXISTS idx_cities_geom ON demo.cities USING GIST (geom);
        " || echo -e "${YELLOW}Note: cities table may already exist${NC}"

		# Grant permissions on cities table
		execute_sql "GRANT SELECT ON demo.cities TO qwc_service;" 2>/dev/null || true
		execute_sql "GRANT ALL ON demo.cities TO qwc_service_write;" 2>/dev/null || true
		execute_sql "GRANT USAGE, SELECT ON SEQUENCE demo.cities_id_seq TO qwc_service_write;" 2>/dev/null || true

		# Insert sample cities (Web Mercator coordinates)
		echo "Inserting sample cities..."
		execute_sql "
        DELETE FROM demo.cities;
        INSERT INTO demo.cities (name, population, country, geom) VALUES
        ('Rome', 2873000, 'Italy', ST_Transform(ST_SetSRID(ST_MakePoint(12.4964, 41.9028), 4326), 3857)),
        ('Paris', 2161000, 'France', ST_Transform(ST_SetSRID(ST_MakePoint(2.3522, 48.8566), 4326), 3857)),
        ('Berlin', 3677000, 'Germany', ST_Transform(ST_SetSRID(ST_MakePoint(13.4050, 52.5200), 4326), 3857)),
        ('Madrid', 3223000, 'Spain', ST_Transform(ST_SetSRID(ST_MakePoint(-3.7038, 40.4168), 4326), 3857)),
        ('London', 8982000, 'UK', ST_Transform(ST_SetSRID(ST_MakePoint(-0.1278, 51.5074), 4326), 3857)),
        ('Amsterdam', 872680, 'Netherlands', ST_Transform(ST_SetSRID(ST_MakePoint(4.9041, 52.3676), 4326), 3857)),
        ('Vienna', 1897000, 'Austria', ST_Transform(ST_SetSRID(ST_MakePoint(16.3738, 48.2082), 4326), 3857)),
        ('Brussels', 185103, 'Belgium', ST_Transform(ST_SetSRID(ST_MakePoint(4.3517, 50.8503), 4326), 3857)),
        ('Lisbon', 547733, 'Portugal', ST_Transform(ST_SetSRID(ST_MakePoint(-9.1393, 38.7223), 4326), 3857)),
        ('Athens', 664046, 'Greece', ST_Transform(ST_SetSRID(ST_MakePoint(23.7275, 37.9838), 4326), 3857));
        "

		# Create demo lines table (roads)
		echo "Creating demo lines layer (roads)..."
		execute_sql "
        CREATE TABLE IF NOT EXISTS demo.roads (
            id SERIAL PRIMARY KEY,
            name VARCHAR(100),
            road_type VARCHAR(50),
            length_km NUMERIC(10, 2),
            geom GEOMETRY(LINESTRING, 3857)
        );

        CREATE INDEX IF NOT EXISTS idx_roads_geom ON demo.roads USING GIST (geom);
        " || echo -e "${YELLOW}Note: roads table may already exist${NC}"

		# Grant permissions on roads table
		execute_sql "GRANT SELECT ON demo.roads TO qwc_service;" 2>/dev/null || true
		execute_sql "GRANT ALL ON demo.roads TO qwc_service_write;" 2>/dev/null || true
		execute_sql "GRANT USAGE, SELECT ON SEQUENCE demo.roads_id_seq TO qwc_service_write;" 2>/dev/null || true

		# Insert sample roads (connecting some cities)
		echo "Inserting sample roads..."
		execute_sql "
        DELETE FROM demo.roads;
        INSERT INTO demo.roads (name, road_type, length_km, geom) VALUES
        ('Route A1', 'Highway', 1100.5,
         ST_Transform(ST_SetSRID(ST_MakeLine(
             ST_MakePoint(12.4964, 41.9028),
             ST_MakePoint(13.4050, 52.5200)
         ), 4326), 3857)),
        ('Route B2', 'Main Road', 850.2,
         ST_Transform(ST_SetSRID(ST_MakeLine(
             ST_MakePoint(2.3522, 48.8566),
             ST_MakePoint(-0.1278, 51.5074)
         ), 4326), 3857)),
        ('Route C3', 'Highway', 1273.8,
         ST_Transform(ST_SetSRID(ST_MakeLine(
             ST_MakePoint(-3.7038, 40.4168),
             ST_MakePoint(4.9041, 52.3676)
         ), 4326), 3857));
        "

		# Create demo polygons table (regions)
		echo "Creating demo polygons layer (regions)..."
		execute_sql "
        CREATE TABLE IF NOT EXISTS demo.regions (
            id SERIAL PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            area_sqkm NUMERIC(12, 2),
            population INTEGER,
            country VARCHAR(50),
            geom GEOMETRY(POLYGON, 3857)
        );

        CREATE INDEX IF NOT EXISTS idx_regions_geom ON demo.regions USING GIST (geom);
        " || echo -e "${YELLOW}Note: regions table may already exist${NC}"

		# Grant permissions on regions table
		execute_sql "GRANT SELECT ON demo.regions TO qwc_service;" 2>/dev/null || true
		execute_sql "GRANT ALL ON demo.regions TO qwc_service_write;" 2>/dev/null || true
		execute_sql "GRANT USAGE, SELECT ON SEQUENCE demo.regions_id_seq TO qwc_service_write;" 2>/dev/null || true

		# Insert sample regions (simple polygons around cities)
		echo "Inserting sample regions..."
		execute_sql "
        DELETE FROM demo.regions;
        INSERT INTO demo.regions (name, area_sqkm, population, country, geom) VALUES
        ('Rome Region', 5351.0, 4200000, 'Italy',
         ST_Buffer(ST_Transform(ST_SetSRID(ST_MakePoint(12.4964, 41.9028), 4326), 3857), 50000)),
        ('Paris Region', 12011.0, 12000000, 'France',
         ST_Buffer(ST_Transform(ST_SetSRID(ST_MakePoint(2.3522, 48.8566), 4326), 3857), 50000)),
        ('Berlin Region', 891.0, 3677000, 'Germany',
         ST_Buffer(ST_Transform(ST_SetSRID(ST_MakePoint(13.4050, 52.5200), 4326), 3857), 30000));
        "

		# Add comments to tables
		execute_sql "
        COMMENT ON TABLE demo.cities IS 'Demo cities point layer for QWC2 testing';
        COMMENT ON TABLE demo.roads IS 'Demo roads line layer for QWC2 testing';
        COMMENT ON TABLE demo.regions IS 'Demo regions polygon layer for QWC2 testing';

        COMMENT ON COLUMN demo.cities.geom IS 'City location in Web Mercator (EPSG:3857)';
        COMMENT ON COLUMN demo.roads.geom IS 'Road geometry in Web Mercator (EPSG:3857)';
        COMMENT ON COLUMN demo.regions.geom IS 'Region boundary in Web Mercator (EPSG:3857)';
        " 2>/dev/null || true

		echo -e "${GREEN}✓ Demo geospatial data created${NC}"
		echo -e "  ${YELLOW}Created layers:${NC}"
		echo -e "    - demo.cities (10 points)"
		echo -e "    - demo.roads (3 lines)"
		echo -e "    - demo.regions (3 polygons)"
	fi
else
	echo -e "${YELLOW}[4/4] Skipping demo geospatial data creation${NC}"
fi

# Step 5: Create and deploy QGIS demo project
if [ "$SKIP_GEODATA" = false ]; then
	echo ""
	echo -e "${GREEN}[5/5] Creating demo QGIS project...${NC}"

	# Find the QGIS server pod to copy the project file
	QGIS_POD=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=qwcqgisserver" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

	if [ -z "$QGIS_POD" ]; then
		QGIS_POD=$(kubectl get pods -n "$NAMESPACE" | grep -E "qgisserver|qwcqgisserver" | awk '{print $1}' | head -1 || echo "")
	fi

	if [ -n "$QGIS_POD" ]; then
		echo "Found QGIS Server pod: $QGIS_POD"

		# Create a minimal QGIS project file
		DEMO_PROJECT=$(
			cat <<'QGIS_PROJECT_EOF'
<!DOCTYPE qgis PUBLIC 'http://mrcc.com/qgis.dtd' 'SYSTEM'>
<qgis projectname="Demo European Cities" version="3.28.0">
  <title>Demo European Cities</title>
  <projectCrs>
    <spatialrefsys>
      <wkt>PROJCS["WGS 84 / Pseudo-Mercator",GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS 84",6378137,298.257223563]],PRIMEM["Greenwich",0],UNIT["degree",0.0174532925199433]],PROJECTION["Mercator_1SP"],PARAMETER["central_meridian",0],PARAMETER["scale_factor",1],PARAMETER["false_easting",0],PARAMETER["false_northing",0],UNIT["metre",1],AUTHORITY["EPSG","3857"]]</wkt>
      <proj4>+proj=merc +a=6378137 +b=6378137 +lat_ts=0 +lon_0=0 +x_0=0 +y_0=0 +k=1 +units=m +nadgrids=@null +wktext +no_defs</proj4>
      <srsid>3857</srsid>
      <srid>3857</srid>
      <authid>EPSG:3857</authid>
      <description>WGS 84 / Pseudo-Mercator</description>
    </spatialrefsys>
  </projectCrs>
  <layer-tree-group>
    <customproperties/>
    <layer-tree-layer id="regions_demo" name="Regions" source="service='qwc_geodb' sslmode=disable key='id' srid=3857 type=Polygon table=&quot;demo&quot;.&quot;regions&quot; (geom)" providerKey="postgres" checked="Qt::Checked" expanded="1">
      <customproperties/>
    </layer-tree-layer>
    <layer-tree-layer id="roads_demo" name="Roads" source="service='qwc_geodb' sslmode=disable key='id' srid=3857 type=LineString table=&quot;demo&quot;.&quot;roads&quot; (geom)" providerKey="postgres" checked="Qt::Checked" expanded="1">
      <customproperties/>
    </layer-tree-layer>
    <layer-tree-layer id="cities_demo" name="European Cities" source="service='qwc_geodb' sslmode=disable key='id' srid=3857 type=Point table=&quot;demo&quot;.&quot;cities&quot; (geom)" providerKey="postgres" checked="Qt::Checked" expanded="1">
      <customproperties/>
    </layer-tree-layer>
  </layer-tree-group>
  <projectlayers>
    <maplayer simplifyAlgorithm="0" simplifyDrawingHints="1" simplifyDrawingTol="1" simplifyMaxScale="1" refreshOnNotifyEnabled="0" minScale="100000000" maxScale="0" geometry="Point" hasScaleBasedVisibilityFlag="0" autoRefreshEnabled="0" type="vector" id="cities_demo">
      <extent>
        <xmin>-1017529</xmin>
        <ymin>4030000</ymin>
        <xmax>2641195</xmax>
        <ymax>6887744</ymax>
      </extent>
      <id>cities_demo</id>
      <datasource>service='qwc_geodb' sslmode=disable key='id' srid=3857 type=Point table="demo"."cities" (geom)</datasource>
      <keywordList><value></value></keywordList>
      <layername>European Cities</layername>
      <srs>
        <spatialrefsys>
          <wkt>PROJCS["WGS 84 / Pseudo-Mercator",GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS 84",6378137,298.257223563]],PRIMEM["Greenwich",0],UNIT["degree",0.0174532925199433]],PROJECTION["Mercator_1SP"],PARAMETER["central_meridian",0],PARAMETER["scale_factor",1],PARAMETER["false_easting",0],PARAMETER["false_northing",0],UNIT["metre",1],AUTHORITY["EPSG","3857"]]</wkt>
          <proj4>+proj=merc +a=6378137 +b=6378137 +lat_ts=0 +lon_0=0 +x_0=0 +y_0=0 +k=1 +units=m +nadgrids=@null +wktext +no_defs</proj4>
          <srsid>3857</srsid>
          <srid>3857</srid>
          <authid>EPSG:3857</authid>
        </spatialrefsys>
      </srs>
      <provider encoding="UTF-8">postgres</provider>
      <vectorjoins/>
      <layerDependencies/>
      <legend type="default-vector"/>
      <fieldConfiguration>
        <field name="id"><editWidget type="TextEdit"/></field>
        <field name="name"><editWidget type="TextEdit"/></field>
        <field name="population"><editWidget type="TextEdit"/></field>
        <field name="country"><editWidget type="TextEdit"/></field>
      </fieldConfiguration>
      <aliases>
        <alias field="id" name="" index="0"/>
        <alias field="name" name="City Name" index="1"/>
        <alias field="population" name="Population" index="2"/>
        <alias field="country" name="Country" index="3"/>
      </aliases>
      <renderer-v2 type="singleSymbol" symbollevels="0" enableorderby="0">
        <symbols>
          <symbol type="marker" name="0" alpha="1" clip_to_extent="1">
            <layer pass="0" class="SimpleMarker" locked="0" enabled="1">
              <prop k="color" v="227,26,28,255"/>
              <prop k="size" v="4"/>
              <prop k="name" v="circle"/>
              <prop k="outline_color" v="35,35,35,255"/>
              <prop k="outline_width" v="0.4"/>
            </layer>
          </symbol>
        </symbols>
      </renderer-v2>
    </maplayer>
    <maplayer simplifyAlgorithm="0" simplifyDrawingHints="1" geometry="Line" hasScaleBasedVisibilityFlag="0" type="vector" id="roads_demo">
      <extent>
        <xmin>-412201</xmin>
        <ymin>4865942</ymin>
        <xmax>1493550</xmax>
        <ymax>6882662</ymax>
      </extent>
      <id>roads_demo</id>
      <datasource>service='qwc_geodb' sslmode=disable key='id' srid=3857 type=LineString table="demo"."roads" (geom)</datasource>
      <layername>Roads</layername>
      <srs><spatialrefsys><authid>EPSG:3857</authid></spatialrefsys></srs>
      <provider encoding="UTF-8">postgres</provider>
      <renderer-v2 type="singleSymbol" symbollevels="0">
        <symbols>
          <symbol type="line" name="0" alpha="1">
            <layer pass="0" class="SimpleLine" locked="0" enabled="1">
              <prop k="line_color" v="31,120,180,255"/>
              <prop k="line_width" v="1.2"/>
            </layer>
          </symbol>
        </symbols>
      </renderer-v2>
    </maplayer>
    <maplayer simplifyAlgorithm="0" simplifyDrawingHints="1" geometry="Polygon" hasScaleBasedVisibilityFlag="0" type="vector" id="regions_demo">
      <extent>
        <xmin>-1101509</xmin>
        <ymin>4683879</ymin>
        <xmax>1586949</xmax>
        <ymax>6931743</ymax>
      </extent>
      <id>regions_demo</id>
      <datasource>service='qwc_geodb' sslmode=disable key='id' srid=3857 type=Polygon table="demo"."regions" (geom)</datasource>
      <layername>Regions</layername>
      <srs><spatialrefsys><authid>EPSG:3857</authid></spatialrefsys></srs>
      <provider encoding="UTF-8">postgres</provider>
      <renderer-v2 type="singleSymbol" symbollevels="0">
        <symbols>
          <symbol type="fill" name="0" alpha="0.5">
            <layer pass="0" class="SimpleFill" locked="0" enabled="1">
              <prop k="color" v="178,223,138,128"/>
              <prop k="outline_color" v="35,35,35,255"/>
              <prop k="outline_width" v="0.26"/>
            </layer>
          </symbol>
        </symbols>
      </renderer-v2>
    </maplayer>
  </projectlayers>
  <properties>
    <WMSServiceTitle type="QString">Demo European Cities</WMSServiceTitle>
    <WMSServiceAbstract type="QString">Demo map showing European cities, roads and regions for QWC2 testing</WMSServiceAbstract>
    <WMSContactOrganization type="QString">QWC Demo</WMSContactOrganization>
    <WMSOnlineResource type="QString"></WMSOnlineResource>
    <WMSExtent type="QStringList">
      <value>-2000000</value>
      <value>4000000</value>
      <value>4000000</value>
      <value>8000000</value>
    </WMSExtent>
    <WMSCrsList type="QStringList">
      <value>EPSG:4326</value>
      <value>EPSG:3857</value>
    </WMSCrsList>
    <WFSLayers type="QStringList">
      <value>cities_demo</value>
      <value>roads_demo</value>
      <value>regions_demo</value>
    </WFSLayers>
    <Identify>
      <disabledLayers type="QStringList"/>
    </Identify>
  </properties>
  <visibility-presets/>
  <mapcanvas name="theMapCanvas" annotationsVisible="1">
    <units>meters</units>
    <extent>
      <xmin>-2000000</xmin>
      <ymin>4000000</ymin>
      <xmax>4000000</xmax>
      <ymax>8000000</ymax>
    </extent>
    <rotation>0</rotation>
    <destinationsrs>
      <spatialrefsys>
        <authid>EPSG:3857</authid>
      </spatialrefsys>
    </destinationsrs>
    <rendermaptile>0</rendermaptile>
  </mapcanvas>
</qgis>
QGIS_PROJECT_EOF
		)

		# Get the PVC name for QGIS qgis resources
		PVC_NAME=$(kubectl get deployment -n "$NAMESPACE" "${RELEASE_NAME}-qwcqgisserver" -o jsonpath='{.spec.template.spec.volumes[?(@.name=="vol-qgis-resources-ro")].persistentVolumeClaim.claimName}' 2>/dev/null || echo "")

		if [ -z "$PVC_NAME" ]; then
			PVC_NAME="${RELEASE_NAME}-qwcqgisserver-qgis-resources-claim"
		fi

		echo "Using PVC: $PVC_NAME"
		echo "Deploying demo.qgs via temporary Job..."

		# Create a temporary Job to write the project file to the PVC
		JOB_NAME="demo-project-writer-$(date +%s)"

		# Escape the project content for use in YAML
		DEMO_PROJECT_BASE64=$(echo "$DEMO_PROJECT" | base64 | tr -d '\n')

		kubectl apply -n "$NAMESPACE" -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: $JOB_NAME
spec:
  ttlSecondsAfterFinished: 60
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: writer
        image: busybox:1.36
        command:
        - sh
        - -c
        - |
          echo "$DEMO_PROJECT_BASE64" | base64 -d > /data/demo.qgs
          echo "Project file created:"
          ls -la /data/demo.qgs
        volumeMounts:
        - name: qgs-resources
          mountPath: /data
      volumes:
      - name: qgs-resources
        persistentVolumeClaim:
          claimName: $PVC_NAME
EOF

		# shellcheck disable=SC2181
		if [ $? -eq 0 ]; then
			echo "Waiting for Job to complete..."
			kubectl wait --for=condition=complete --timeout=60s job/"$JOB_NAME" -n "$NAMESPACE" 2>/dev/null

			if [ $? -eq 0 ]; then
				echo -e "${GREEN}✓ Demo QGIS project deployed${NC}"
				echo -e "  ${YELLOW}Project file:${NC} demo.qgs"

				# Restart config-service to pick up the new project
				echo "Restarting config-service to regenerate configurations..."
				kubectl rollout restart deployment -n "$NAMESPACE" -l "app.kubernetes.io/name=qwcconfigservice" 2>/dev/null || true
				echo -e "${GREEN}✓ Config service restart triggered${NC}"
			else
				echo -e "${YELLOW}Job did not complete in time. Check logs:${NC}"
				kubectl logs job/"$JOB_NAME" -n "$NAMESPACE" 2>/dev/null || true
			fi

			# Clean up Job
			kubectl delete job/"$JOB_NAME" -n "$NAMESPACE" --ignore-not-found 2>/dev/null || true
		else
			echo -e "${YELLOW}Note: Could not create temporary Job. You may need to deploy the project manually.${NC}"
		fi
	else
		echo -e "${YELLOW}Note: QGIS server pod not found. Skipping project deployment.${NC}"
	fi
fi

# Step 6: Configure demo theme and services (direct configuration approach)
if [ "$SKIP_GEODATA" = false ]; then
	echo ""
	echo -e "${GREEN}[6/6] Configuring demo theme and services...${NC}"

	# Wait for config-service to be ready after QGIS project deployment
	echo "Waiting for services to stabilize..."
	sleep 10

	CONFIG_POD=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=qwcconfigservice" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

	if [ -n "$CONFIG_POD" ]; then
		echo "Found config-service pod: $CONFIG_POD"

		# Step 6a: Configure OGC service for the demo theme
		echo "Configuring OGC service..."
		QGIS_SERVER_URL="http://${RELEASE_NAME}-qwcqgisserver"
		kubectl exec -n "$NAMESPACE" "$CONFIG_POD" -- sh -c "cat > /qwc_cfg/config-generated/default/ogcConfig.json << 'EOFOGC'
{
  \"\$schema\": \"https://github.com/qwc-services/qwc-ogc-service/raw/master/schemas/qwc-ogc-service.json\",
  \"service\": \"ogc\",
  \"config\": {
    \"default_qgis_server_url\": \"${QGIS_SERVER_URL}/ows/\"
  },
  \"resources\": {
    \"wms_services\": [
      {
        \"name\": \"demo\",
        \"wms_url\": \"${QGIS_SERVER_URL}/ows/?MAP=/data/demo.qgs\",
        \"online_resources\": {
          \"service\": \"/ows/\",
          \"feature_info\": \"/api/v1/featureinfo/\",
          \"legend\": \"/api/v1/legend/\"
        },
        \"root_layer\": {
          \"name\": \"demo\",
          \"title\": \"Demo European Cities\",
          \"layers\": [
            {\"name\": \"European Cities\", \"title\": \"European Cities\", \"queryable\": true, \"visible\": true},
            {\"name\": \"Roads\", \"title\": \"Roads\", \"queryable\": true, \"visible\": true},
            {\"name\": \"Regions\", \"title\": \"Regions\", \"queryable\": true, \"visible\": true}
          ]
        }
      }
    ],
    \"wfs_services\": [
      {
        \"name\": \"demo\",
        \"wfs_url\": \"${QGIS_SERVER_URL}/ows/?MAP=/data/demo.qgs\",
        \"online_resource\": \"/ows/\"
      }
    ]
  }
}
EOFOGC" 2>/dev/null
		echo -e "${GREEN}✓ OGC service configured${NC}"

		# Step 6b: Update permissions to allow access to demo services
		echo "Updating permissions..."
		kubectl exec -n "$NAMESPACE" "$CONFIG_POD" -- sh -c 'python3 -c "
import json

# Read current permissions
with open(\"/qwc_cfg/config-generated/default/permissions.json\") as f:
    data = json.load(f)

# Define demo WMS/WFS permissions
demo_wms = {
    \"name\": \"demo\",
    \"layers\": [
        {\"name\": \"demo\", \"queryable\": True},
        {\"name\": \"European Cities\", \"queryable\": True},
        {\"name\": \"Roads\", \"queryable\": True},
        {\"name\": \"Regions\", \"queryable\": True}
    ],
    \"print_templates\": [],
    \"internal_print_layers\": []
}

demo_wfs = {
    \"name\": \"demo\",
    \"layers\": [
        {\"name\": \"European Cities\"},
        {\"name\": \"Roads\"},
        {\"name\": \"Regions\"}
    ]
}

# Add to all roles
for role in data.get(\"roles\", []):
    perms = role.get(\"permissions\", {})
    perms[\"wms_services\"] = [demo_wms]
    perms[\"wfs_services\"] = [demo_wfs]
    role[\"permissions\"] = perms

# Write updated permissions
with open(\"/qwc_cfg/config-generated/default/permissions.json\", \"w\") as f:
    json.dump(data, f, indent=2)
print(\"Permissions updated\")
"' 2>/dev/null
		echo -e "${GREEN}✓ Permissions updated${NC}"

		# Step 6c: Update mapViewerConfig with demo theme
		echo "Configuring Map Viewer theme..."
		kubectl exec -n "$NAMESPACE" "$CONFIG_POD" -- sh -c 'python3 -c "
import json

with open(\"/qwc_cfg/config-generated/default/mapViewerConfig.json\") as f:
    data = json.load(f)

# Fix ogc_service_url to use relative path
data[\"config\"][\"ogc_service_url\"] = \"/ows/\"

# Define demo theme with correct European bbox
demo_theme = {
    \"id\": \"demo\",
    \"name\": \"demo\",
    \"title\": \"Demo European Cities\",
    \"description\": \"Demo map showing European cities, roads and regions\",
    \"wms_name\": \"demo\",
    \"url\": \"/ows/demo\",
    \"attribution\": {\"Title\": \"QWC Demo\", \"OnlineResource\": \"\"},
    \"format\": \"image/png\",
    \"mapCrs\": \"EPSG:3857\",
    \"additionalMouseCrs\": [\"EPSG:4326\"],
    \"bbox\": {\"crs\": \"EPSG:3857\", \"bounds\": [-1500000, 4000000, 3500000, 7500000]},
    \"initialBbox\": {\"crs\": \"EPSG:3857\", \"bounds\": [-1500000, 4000000, 3500000, 7500000]},
    \"scales\": [100000000,50000000,25000000,10000000,4000000,2000000,1000000,400000,200000,80000,40000,20000,10000,8000,6000,4000,2000,1000,500,250,100],
    \"printScales\": [100000,50000,25000,10000,5000,2500],
    \"printResolutions\": [150, 300],
    \"searchProviders\": [\"coordinates\"],
    \"editConfig\": None,
    \"print\": [],
    \"backgroundLayers\": [{\"name\": \"mapnik\", \"visibility\": True}],
    \"sublayers\": [
        {\"name\": \"European Cities\", \"title\": \"European Cities\", \"visibility\": True, \"queryable\": True, \"displayField\": \"name\", \"bbox\": {\"crs\": \"EPSG:3857\", \"bounds\": [-1500000, 4000000, 3500000, 7500000]}},
        {\"name\": \"Roads\", \"title\": \"Roads\", \"visibility\": True, \"queryable\": True, \"displayField\": \"name\", \"bbox\": {\"crs\": \"EPSG:3857\", \"bounds\": [-1500000, 4000000, 3500000, 7500000]}},
        {\"name\": \"Regions\", \"title\": \"Regions\", \"visibility\": True, \"queryable\": True, \"displayField\": \"name\", \"bbox\": {\"crs\": \"EPSG:3857\", \"bounds\": [-1500000, 4000000, 3500000, 7500000]}}
    ],
    \"expanded\": True,
    \"drawingOrder\": [\"Regions\", \"Roads\", \"European Cities\"],
    \"externalLayers\": [],
    \"themeInfoLinks\": {\"entries\": []},
    \"thumbnail\": \"img/mapthumbs/default.jpg\",
    \"skipEmptyFeatureAttributes\": True,
    \"collapseLayerGroupsBelowLevel\": -1
}

# Update themes
if \"resources\" not in data:
    data[\"resources\"] = {}
if \"qwc2_themes\" not in data[\"resources\"]:
    data[\"resources\"][\"qwc2_themes\"] = {\"themes\": {\"items\": [], \"subdirs\": [], \"backgroundLayers\": []}}

themes = data[\"resources\"][\"qwc2_themes\"][\"themes\"]
themes[\"items\"] = [demo_theme]
themes[\"defaultTheme\"] = \"demo\"
themes[\"defaultMapCrs\"] = \"EPSG:3857\"
themes[\"defaultWMSVersion\"] = \"1.3.0\"
themes[\"backgroundLayers\"] = [{
    \"name\": \"mapnik\",
    \"title\": \"Open Street Map\",
    \"type\": \"osm\",
    \"source\": \"osm\",
    \"attribution\": {\"Title\": \"OpenStreetMap contributors\", \"OnlineResource\": \"https://www.openstreetmap.org/copyright\"},
    \"thumbnail\": \"img/mapthumbs/mapnik.jpg\"
}]

with open(\"/qwc_cfg/config-generated/default/mapViewerConfig.json\", \"w\") as f:
    json.dump(data, f, indent=2)
print(\"Map Viewer config updated\")
"' 2>/dev/null
		echo -e "${GREEN}✓ Map Viewer configured${NC}"

		# Step 6d: Remove conflicting QGIS Server HTTPRoute (it conflicts with Map Viewer route on /)
		echo "Removing conflicting QGIS Server HTTPRoute..."
		kubectl delete httproute -n "$NAMESPACE" "${RELEASE_NAME}-qwcqgisserver-route" --ignore-not-found 2>/dev/null || true
		echo -e "${GREEN}✓ Conflicting route removed${NC}"

		# Step 6e: Restart OGC service and Map Viewer to pick up new configs
		echo "Restarting services to apply configuration..."
		kubectl rollout restart deployment -n "$NAMESPACE" -l "app.kubernetes.io/name=qwcogcservice" 2>/dev/null || true
		kubectl rollout restart deployment -n "$NAMESPACE" -l "app.kubernetes.io/name=qwcmapviewer" 2>/dev/null || true
		echo -e "${GREEN}✓ Services restart triggered${NC}"

		# Step 6f: Wait for services to be ready
		echo "Waiting for services to be ready..."
		sleep 30
		echo -e "${GREEN}✓ Services should now be ready${NC}"

	else
		echo -e "${YELLOW}Note: Config-service pod not found. Theme configuration skipped.${NC}"
	fi
fi

echo ""
echo -e "${GREEN}=== Initialization Complete ===${NC}"
echo ""
echo -e "${YELLOW}Demo Access:${NC}"
echo "  Map Viewer:  https://myhostname.com/"
echo "  Admin GUI:   https://myhostname.com/admin/"
echo "  WMS Service: https://myhostname.com/ows/demo?SERVICE=WMS&REQUEST=GetCapabilities"
echo ""
echo -e "${YELLOW}Demo credentials:${NC}"
echo "  Admin: admin / demo"
echo "  User:  demo / demo"
echo ""
echo -e "${YELLOW}Demo layers:${NC}"
echo "  - European Cities (10 major European cities)"
echo "  - Roads (major road connections)"
echo "  - Regions (city regions)"
echo ""
echo -e "${GREEN}The demo is now ready!${NC} Open the Map Viewer to see the demo theme."
echo ""
