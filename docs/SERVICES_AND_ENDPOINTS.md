# QWC Helm Chart - Services and Endpoints Documentation

This document provides comprehensive documentation of all Kubernetes services and HTTP endpoints exposed by the QWC application.

## Table of Contents

1. [Services Overview](#services-overview)
2. [Service Details](#service-details)
3. [API Endpoints](#api-endpoints)
4. [OGC Services](#ogc-services)
5. [Routing Configuration](#routing-configuration)
6. [Authentication & Authorization](#authentication--authorization)
7. [Testing Endpoints](#testing-endpoints)

---

## Services Overview

The QWC Helm chart creates the following Kubernetes services:

| Service Name | Type | Port | Purpose |
| -------------- | ------ | ------ | --------- |
| `{release}-qwcdb` | ClusterIP | 5432 | PostgreSQL database |
| `{release}-qwcqgisserver` | ClusterIP | 80 | QGIS Server (Apache/FCGI) |
| `{release}-qwcconfigservice` | ClusterIP | 80 | Config generator service |
| `{release}-qwcmapviewer` | ClusterIP | 80 | Map viewer frontend |
| `{release}-qwcogcservice` | ClusterIP | 80 | OGC service proxy |
| `{release}-qwcdataservice` | ClusterIP | 80 | Data service REST API |
| `{release}-qwcauthservice` | ClusterIP | 80 | Authentication service |
| `{release}-qwcadmingui` | ClusterIP | 80 | Admin GUI |
| `{release}-qwcpermalinkservice` | ClusterIP | 80 | Permalink service |

**Note:** `{release}` is the Helm release name (e.g., `my-qwc-instance`).

---

## Service Details

### 1. qwc-db Service

**Service Name:** `{release}-qwcdb`
**Type:** ClusterIP
**Port:** 5432
**Protocol:** TCP

**Purpose:** Provides PostgreSQL database access within the Kubernetes cluster.

**Access:**

- Internal cluster access only
- Not exposed externally
- Accessed by all QWC services via `pg_service.conf`

**Connection String Format:**

```ini
host={release}-qwcdb
port=5432
dbname=qwc_services
user=<role>
password=<password>
```

---

### 2. qwc-qgis-server Service

**Service Name:** `{release}-qwcqgisserver`
**Type:** ClusterIP
**Port:** 80 (maps to container port 1080)
**Protocol:** TCP

**Purpose:** Serves QGIS Server OGC-compliant web services (WMS, WFS, WCS, WMTS).

**Direct Access:**

- Can be accessed via HTTPRoute when enabled
- Internal access: `http://{release}-qwcqgisserver/ows/`
- Container port: 1080 (to avoid root privileges)

**Typical Usage:**

- Accessed internally by `qwc-ogc-service`
- Can be exposed directly via Gateway API HTTPRoute

**Health Check:**

- Liveness: `GET http://{release}-qwcqgisserver/`
- Readiness: `GET http://{release}-qwcqgisserver/`

---

### 3. qwc-config-service Service

**Service Name:** `{release}-qwcconfigservice`
**Type:** ClusterIP
**Port:** 80 (maps to container port 9090)
**Protocol:** TCP

**Purpose:** Configuration generation service that creates runtime configs from QGIS projects.

**Internal Access:** `http://{release}-qwcconfigservice/`

**Health Check:**

- Liveness: `GET http://{release}-qwcconfigservice/maps?tenant=default`
- Readiness: `GET http://{release}-qwcconfigservice/maps?tenant=default`

**Note:** Typically not exposed externally; used internally by other services.

---

### 4. qwc-map-viewer Service

**Service Name:** `{release}-qwcmapviewer`
**Type:** ClusterIP
**Port:** 80 (maps to container port 9090)
**Protocol:** TCP

**Purpose:** Main web application frontend for map viewing and interaction.

**Internal Access:** `http://{release}-qwcmapviewer/`

**External Access:** Exposed via API Gateway at path `/`

**Health Check:**

- Liveness: `GET http://{release}-qwcmapviewer/healthz`
- Readiness: `GET http://{release}-qwcmapviewer/ready`

---

### 5. qwc-ogc-service Service

**Service Name:** `{release}-qwcogcservice`
**Type:** ClusterIP
**Port:** 80 (maps to container port 9090)
**Protocol:** TCP

**Purpose:** OGC service proxy with authentication and authorization.

**Internal Access:** `http://{release}-qwcogcservice/ows/`

**External Access:** Exposed via API Gateway at path `/ows/`

**Health Check:**

- Liveness: `GET http://{release}-qwcogcservice/healthz`
- Readiness: `GET http://{release}-qwcogcservice/ready`

---

### 6. qwc-data-service Service

**Service Name:** `{release}-qwcdataservice`
**Type:** ClusterIP
**Port:** 80 (maps to container port 9090)
**Protocol:** TCP

**Purpose:** REST API for feature data CRUD operations.

**Internal Access:** `http://{release}-qwcdataservice/api/v1/data/`

**External Access:** Exposed via API Gateway at path `/api/v1/data/`

**Health Check:**

- Liveness: `GET http://{release}-qwcdataservice/healthz`
- Readiness: `GET http://{release}-qwcdataservice/ready`

---

### 7. qwc-auth-service Service

**Service Name:** `{release}-qwcauthservice`
**Type:** ClusterIP
**Port:** 80 (maps to container port 9090)
**Protocol:** TCP

**Purpose:** User authentication and JWT token management.

**Internal Access:** `http://{release}-qwcauthservice/auth/`

**External Access:** Exposed via API Gateway at path `/auth/`

**Health Check:**

- Liveness: `GET http://{release}-qwcauthservice/healthz`
- Readiness: `GET http://{release}-qwcauthservice/ready`

---

### 8. qwc-admin-gui Service

**Service Name:** `{release}-qwcadmingui`
**Type:** ClusterIP
**Port:** 80 (maps to container port 9090)
**Protocol:** TCP

**Purpose:** Administrative web interface for managing the QWC application.

**Internal Access:** `http://{release}-qwcadmingui/admin/`

**External Access:** Exposed via API Gateway at path `/admin/`

**Health Check:**

- Liveness: TCP socket check on port 9090
- Readiness: TCP socket check on port 9090

---

### 9. qwc-permalink-service Service

**Service Name:** `{release}-qwcpermalinkservice`
**Type:** ClusterIP
**Port:** 80 (maps to container port 9090)
**Protocol:** TCP

**Purpose:** Permanent link generation and resolution for map states.

**Internal Access:** `http://{release}-qwcpermalinkservice/api/v1/permalink/`

**External Access:** Exposed via API Gateway at path `/api/v1/permalink/`

**Health Check:**

- Liveness: TCP socket check on port 9090
- Readiness: TCP socket check on port 9090

---

## API Endpoints

### Authentication Service (`/auth/`)

#### POST /auth/login

Authenticate user and receive JWT token.

**Request:**

```json
{
  "username": "user@example.com",
  "password": "password123"
}
```

**Response (200 OK):**

```json
{
  "username": "user@example.com",
  "name": "John Doe",
  "email": "user@example.com",
  "roles": ["user"]
}
```

**Response Headers:**

- `Set-Cookie: jwt_token=...` (HTTP-only, Secure in production)

**Error Response (401 Unauthorized):**

```json
{
  "error": "Invalid credentials"
}
```

---

#### POST /auth/logout

Logout current user (invalidates session).

**Response (200 OK):**

```json
{
  "message": "Logged out successfully"
}
```

---

#### GET /auth/userinfo

Get current user information from JWT token.

**Headers:**

- `Cookie: jwt_token=...` (required)

**Response (200 OK):**

```json
{
  "username": "user@example.com",
  "name": "John Doe",
  "email": "user@example.com",
  "roles": ["user"],
  "groups": ["group1"]
}
```

---

#### POST /auth/register (if enabled)

Register a new user account.

**Request:**

```json
{
  "username": "newuser@example.com",
  "password": "password123",
  "email": "newuser@example.com",
  "name": "New User"
}
```

**Response (201 Created):**

```json
{
  "message": "User registered successfully",
  "username": "newuser@example.com"
}
```

---

### Data Service (`/api/v1/data/`)

All endpoints require authentication via JWT cookie.

#### GET /api/v1/data/{schema}.{table}

Get features from a table.

**Query Parameters:**

- `bbox`: Bounding box `minx,miny,maxx,maxy` (optional)
- `filter`: CQL filter expression (optional)
- `limit`: Maximum number of features (default: 100)
- `offset`: Offset for pagination (default: 0)

**Example:**

```raw
GET /api/v1/data/public.buildings?bbox=-180,-90,180,90&limit=50
```

**Response (200 OK):**

```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "id": 1,
      "geometry": {
        "type": "Polygon",
        "coordinates": [[...]]
      },
      "properties": {
        "name": "Building 1",
        "type": "residential"
      }
    }
  ],
  "total": 100
}
```

---

#### GET /api/v1/data/{schema}.{table}/{id}

Get a single feature by ID.

**Example:**

```raw
GET /api/v1/data/public.buildings/123
```

**Response (200 OK):**

```json
{
  "type": "Feature",
  "id": 123,
  "geometry": {...},
  "properties": {...}
}
```

---

#### POST /api/v1/data/{schema}.{table}

Create a new feature.

**Request:**

```json
{
  "type": "Feature",
  "geometry": {
    "type": "Point",
    "coordinates": [lon, lat]
  },
  "properties": {
    "name": "New Building",
    "type": "commercial"
  }
}
```

**Response (201 Created):**

```json
{
  "type": "Feature",
  "id": 456,
  "geometry": {...},
  "properties": {...}
}
```

---

#### PUT /api/v1/data/{schema}.{table}/{id}

Update an existing feature.

**Request:** (same as POST)

**Response (200 OK):** (updated feature)

---

#### PATCH /api/v1/data/{schema}.{table}/{id}

Partially update a feature.

**Request:**

```json
{
  "properties": {
    "name": "Updated Name"
  }
}
```

**Response (200 OK):** (updated feature)

---

#### DELETE /api/v1/data/{schema}.{table}/{id}

Delete a feature.

**Response (204 No Content):**

---

#### POST /api/v1/data/{schema}.{table}/{id}/attachments

Upload file attachment for a feature.

**Request:** Multipart form data

- `file`: The file to upload

**Response (201 Created):**

```json
{
  "id": "uuid-123",
  "filename": "photo.jpg",
  "size": 12345,
  "mimetype": "image/jpeg",
  "url": "/api/v1/data/public.buildings/123/attachments/uuid-123"
}
```

---

#### GET /api/v1/data/{schema}.{table}/{id}/attachments

List attachments for a feature.

**Response (200 OK):**

```json
[
  {
    "id": "uuid-123",
    "filename": "photo.jpg",
    "size": 12345,
    "mimetype": "image/jpeg"
  }
]
```

---

#### DELETE /api/v1/data/{schema}.{table}/{id}/attachments/{attachment_id}

Delete an attachment.

**Response (204 No Content):**

---

### Permalink Service (`/api/v1/permalink/`)

#### POST /api/v1/permalink/

Create a permanent link for current map state.

**Request:**

```json
{
  "mapState": {
    "center": [lon, lat],
    "zoom": 10,
    "layers": ["layer1", "layer2"],
    "extent": [minx, miny, maxx, maxy]
  }
}
```

**Response (201 Created):**

```json
{
  "id": "abc123",
  "url": "/api/v1/permalink/abc123",
  "expires": "2024-12-31T23:59:59Z"
}
```

---

#### GET /api/v1/permalink/{id}

Resolve a permanent link to map state.

**Response (200 OK):**

```json
{
  "mapState": {
    "center": [lon, lat],
    "zoom": 10,
    "layers": ["layer1", "layer2"],
    "extent": [minx, miny, maxx, maxy]
  }
}
```

---

### Config Service (Internal)

#### GET /maps?tenant={tenant}

Get available maps/themes for a tenant.

**Query Parameters:**

- `tenant`: Tenant name (default: "default")

**Response (200 OK):**

```json
{
  "themes": [
    {
      "name": "main",
      "title": "Main Map",
      "url": "/ows/?MAP=main"
    }
  ]
}
```

---

## OGC Services

The OGC services are exposed via `/ows/` path through the `qwc-ogc-service`.

### WMS (Web Map Service)

#### GetCapabilities

```raw
GET /ows/?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities&MAP={project_name}
```

Returns XML capabilities document describing available layers and operations.

---

#### GetMap

```raw
GET /ows/?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&
    LAYERS={layer_name}&
    STYLES={style_name}&
    CRS=EPSG:3857&
    BBOX={minx,miny,maxx,maxy}&
    WIDTH=800&
    HEIGHT=600&
    FORMAT=image/png&
    MAP={project_name}
```

Returns a map image (PNG, JPEG, etc.).

**Query Parameters:**

- `LAYERS`: Comma-separated layer names
- `STYLES`: Comma-separated style names
- `CRS`: Coordinate reference system
- `BBOX`: Bounding box in CRS units
- `WIDTH`, `HEIGHT`: Image dimensions in pixels
- `FORMAT`: Image format (image/png, image/jpeg)
- `MAP`: QGIS project name (without .qgs extension)

---

#### GetFeatureInfo

```raw
GET /ows/?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetFeatureInfo&
    LAYERS={layer_name}&
    QUERY_LAYERS={layer_name}&
    I={x}&
    J={y}&
    CRS=EPSG:3857&
    BBOX={minx,miny,maxx,maxy}&
    WIDTH=800&
    HEIGHT=600&
    INFO_FORMAT=text/html&
    MAP={project_name}
```

Returns feature information at a point.

**Query Parameters:**

- `I`, `J`: Pixel coordinates within the map image
- `INFO_FORMAT`: Response format (text/html, text/xml, application/json)

---

### WFS (Web Feature Service)

#### GetCapabilities

```raw
GET /ows/?SERVICE=WFS&VERSION=2.0.0&REQUEST=GetCapabilities&MAP={project_name}
```

---

#### GetFeature

```raw
GET /ows/?SERVICE=WFS&VERSION=2.0.0&REQUEST=GetFeature&
    TYPENAMES={layer_name}&
    SRSNAME=EPSG:3857&
    BBOX={minx,miny,maxx,maxy},EPSG:3857&
    OUTPUTFORMAT=application/json&
    MAP={project_name}
```

Returns features as GeoJSON, GML, etc.

**Output Formats:**

- `application/json` (GeoJSON)
- `GML2`, `GML3`
- `text/xml`

---

### WCS (Web Coverage Service)

#### GetCapabilities

```raw
GET /ows/?SERVICE=WCS&VERSION=2.0.1&REQUEST=GetCapabilities&MAP={project_name}
```

---

#### GetCoverage

```raw
GET /ows/?SERVICE=WCS&VERSION=2.0.1&REQUEST=GetCoverage&
    COVERAGEID={layer_name}&
    SUBSET=Long({minx},{maxx})&
    SUBSET=Lat({miny},{maxy})&
    FORMAT=GeoTIFF&
    MAP={project_name}
```

Returns raster coverage data.

---

## Routing Configuration

### API Gateway Routes

When using `qwc-api-gateway`, requests are routed as follows:

| Path | Service | Purpose |
| ------ | --------- | --------- |
| `/` | qwc-map-viewer | Main application |
| `/auth/*` | qwc-auth-service | Authentication |
| `/ows/*` | qwc-ogc-service | OGC services |
| `/api/v1/data/*` | qwc-data-service | Data API |
| `/api/v1/permalink/*` | qwc-permalink-service | Permalinks |
| `/admin/*` | qwc-admin-gui | Admin interface |

### Gateway API HTTPRoute (Alternative)

The chart also supports Kubernetes Gateway API HTTPRoute for direct QGIS Server access:

```yaml
qwcQgisServer:
  httpRoute:
    enabled: true
    hostnames:
      - maps.example.com
    gateway:
      name: gateway-private
      namespace: balancers-dev
      sectionName: https
```

This creates an HTTPRoute that exposes QGIS Server directly at the root path `/`.

---

## Authentication & Authorization

### JWT Token Flow

1. User authenticates via `/auth/login`
2. Server sets HTTP-only cookie: `jwt_token=<token>`
3. Client includes cookie in subsequent requests
4. Services validate JWT token and extract user info

### Token Structure

JWT tokens contain:

- `username`: User identifier
- `roles`: User roles array
- `groups`: User groups array
- `exp`: Expiration timestamp
- `iat`: Issued at timestamp

### Authorization

Authorization is based on:

- **Roles:** System-wide permissions (admin, user, etc.)
- **Groups:** Tenant-specific permissions
- **Layer Permissions:** Defined in `permissions.json`

### Example: Protected Endpoint

```bash
# 1. Login
curl -X POST https://maps.example.com/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"user@example.com","password":"pass"}' \
  -c cookies.txt

# 2. Use authenticated cookie
curl https://maps.example.com/api/v1/data/public.buildings \
  -b cookies.txt
```

---

## Testing Endpoints

### Health Checks

```bash
# Map viewer
curl http://{release}-qwcmapviewer/healthz

# OGC service
curl http://{release}-qwcogcservice/healthz

# Data service
curl http://{release}-qwcdataservice/healthz

# Auth service
curl http://{release}-qwcauthservice/healthz
```

### Database Connection

```bash
# From inside cluster
kubectl exec -it <pod-name> -- psql "service=qwc_configdb" -c "SELECT 1"
```

### QGIS Server Direct Access

```bash
# GetCapabilities
curl "http://{release}-qwcqgisserver/ows/?SERVICE=WMS&REQUEST=GetCapabilities&MAP=qwc_demo"

# GetMap
curl "http://{release}-qwcqgisserver/ows/?SERVICE=WMS&REQUEST=GetMap&LAYERS=layer1&CRS=EPSG:3857&BBOX=0,0,1000,1000&WIDTH=256&HEIGHT=256&FORMAT=image/png&MAP=qwc_demo" \
  -o map.png
```

### End-to-End Test

```bash
# 1. Get map viewer
curl https://maps.example.com/

# 2. Login
curl -X POST https://maps.example.com/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"demo","password":"demo"}' \
  -c cookies.txt

# 3. Get user info
curl https://maps.example.com/auth/userinfo -b cookies.txt

# 4. Get WMS capabilities
curl "https://maps.example.com/ows/?SERVICE=WMS&REQUEST=GetCapabilities&MAP=qwc_demo" \
  -b cookies.txt

# 5. Get features
curl "https://maps.example.com/api/v1/data/public.buildings?limit=10" \
  -b cookies.txt
```
