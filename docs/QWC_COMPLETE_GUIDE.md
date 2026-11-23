# QWC - QGIS Web Client

## Complete Technical Documentation for Kubernetes Deployment

---

## Table of Contents

1. [Product Overview](#product-overview)
2. [System Architecture](#system-architecture)
3. [Services, Endpoints and Flows](#services-endpoints-and-flows)
4. [Volumes and Persistent Storage](#volumes-and-persistent-storage)
5. [Helm Chart Configuration](#helm-chart-configuration)
6. [Installation Guide](#installation-guide)
7. [Troubleshooting](#troubleshooting)
8. [Appendix](#appendix)

---

## Product Overview

### What is QWC?

**QWC (QGIS Web Client)** is a modern, modular web mapping application built on top of QGIS Server. It provides a responsive, feature-rich web interface for viewing and interacting with geospatial data served through OGC-compliant services (WMS, WFS, WCS, WMTS).

The application follows a **microservices architecture** where each service handles a specific functionality, all orchestrated within a Kubernetes cluster using Helm charts.

### Key Features

| Category | Features |
| ---------- | ---------- |
| **Map Viewing** | Pan, zoom, rotation, coordinate display, scale bar |
| **Layer Management** | Layer tree, visibility toggle, opacity control, layer ordering |
| **Feature Interaction** | Click identification, feature info popups, attribute display |
| **Search** | Full-text search, coordinate search, layer search |
| **Measurement** | Distance measurement, area measurement, coordinate reading |
| **Drawing & Sketching** | Point, line, polygon drawing, annotations |
| **Print & Export** | PDF export, image export, print layouts |
| **Permalinks** | Shareable map state URLs |
| **Authentication** | JWT-based authentication, role-based access control |
| **Administration** | User management, permission configuration, theme management |

### Technology Stack

| Component | Technology |
| ----------- | ------------ |
| **Frontend** | React.js, OpenLayers, Redux |
| **Backend Services** | Python Flask (microservices) |
| **Map Server** | QGIS Server 3.x (Apache + FastCGI) |
| **Database** | PostgreSQL 16 with PostGIS 3.x |
| **Authentication** | JWT (JSON Web Tokens) |
| **Containerization** | Docker |
| **Orchestration** | Kubernetes with Helm 3.x |
| **API Gateway** | Kubernetes Gateway API / NGINX |

### Use Cases

- **Enterprise GIS Portals**: Internal mapping applications for organizations
- **Public Map Services**: Government and municipal mapping portals
- **Environmental Monitoring**: Real-time data visualization dashboards
- **Asset Management**: Infrastructure and facility management
- **Land Management**: Cadastral and property management systems

### Compatibility Matrix

The following component versions are verified to work together in this Helm chart release:

| Component | Service Name | Version / Tag | Notes |
| ----------- | -------------- | --------------- | ------- |
| **QGIS Server** | `qwc-qgis-server` | `3.40` | Core map rendering engine |
| **Map Viewer** | `qwc-map-viewer` | `v2026.02.02` | Frontend application |
| **Config Service** | `qwc-config-service` | `v2026.01.30` | Configuration generator |
| **OGC Service** | `qwc-ogc-service` | `v2026.01.18` | OGC proxy |
| **Data Service** | `qwc-data-service` | `v2026.02.03` | Feature editing API |
| **Admin GUI** | `qwc-admin-gui` | `v2026.01.18` | Administration interface |
| **Auth Service** | `qwc-auth-service` | `v2026.01.27` | Authentication service |
| **Permalink Service** | `qwc-permalink-service` | `v2026.01.22` | Permalink generation |
| **Database** | `qwc-db` | `16` | PostgreSQL version |
| **DB Migrate** | `qwc-db-migrate` | `v2026.01.05` | Schema migration tool |

> **Note:** These versions reflect the configuration in `values.yaml`. Using significantly older or newer versions may require configuration adjustments.

---

## System Architecture

### High-Level Architecture

```raw
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              EXTERNAL TRAFFIC                                   │
│                           (HTTPS via TLS Termination)                           │
└─────────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌────────────────────────────────────────────────────────────────────────────────────┐
│                        API GATEWAY / INGRESS CONTROLLER                            │
│                     (Kubernetes Gateway API / NGINX / Envoy)                       │
│                                                                                    │
│   ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐     │
│   │    /    │  │ /auth/* │  │ /ows/*  │  │/api/v1/ │  │/admin/* │  │/api/v1/ │     │
│   │         │  │         │  │         │  │ data/*  │  │         │  │permalink│     │
│   └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘     │
└────────┼────────────┼────────────┼────────────┼────────────┼────────────┼──────────┘
         │            │            │            │            │            │
         ▼            ▼            ▼            ▼            ▼            ▼
┌─────────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌─────────────┐
│ MAP VIEWER  │ │   AUTH    │ │    OGC    │ │   DATA    │ │  ADMIN    │ │  PERMALINK  │
│             │ │  SERVICE  │ │  SERVICE  │ │  SERVICE  │ │   GUI     │ │   SERVICE   │
│ (React SPA) │ │  (Flask)  │ │  (Flask)  │ │  (Flask)  │ │  (Flask)  │ │   (Flask)   │
└──────┬──────┘ └─────┬─────┘ └─────┬─────┘ └─────┬─────┘ └─────┬─────┘ └──────┬──────┘
       │              │             │             │             │              │
       │              │             ▼             │             │              │
       │              │      ┌───────────┐        │             │              │
       │              │      │   QGIS    │        │             │              │
       │              │      │  SERVER   │        │             │              │
       │              │      │(Apache+   │        │             │              │
       │              │      │ FastCGI)  │        │             │              │
       │              │      └─────┬─────┘        │             │              │
       │              │            │              │             │              │
       └──────────────┴────────────┴──────────────┴─────────────┴──────────────┘
                                        │
                                        ▼
                    ┌───────────────────────────────────────────┐
                    │          POSTGRESQL + POSTGIS             │
                    │                                           │
                    │  ┌────────────┐  ┌────────────┐           │
                    │  │ qwc_config │  │ qwc_users  │           │
                    │  │   schema   │  │   schema   │           │
                    │  └────────────┘  └────────────┘           │
                    │                                           │
                    │  ┌────────────────────────────────┐       │
                    │  │      Geospatial Data (demo)    │       │
                    │  │  cities | roads | regions      │       │
                    │  └────────────────────────────────┘       │
                    └───────────────────────────────────────────┘

                    ┌───────────────────────────────────────────┐
                    │          CONFIG SERVICE                   │
                    │    (Reads QGIS projects, generates        │
                    │     runtime configurations)               │
                    └───────────────────────────────────────────┘
```

### Component Details

#### Frontend Services

| Service | Image | Description | Default Port |
| --------- | ------- | ------------- | -------------- |
| **qwc-map-viewer** | `sourcepole/qwc-map-viewer` | React-based SPA for map visualization | 9090 |
| **qwc-admin-gui** | `sourcepole/qwc-admin-gui` | Administrative web interface | 9090 |

#### Backend Services

| Service | Image | Description | Default Port |
| --------- | ------- | ------------- | -------------- |
| **qwc-auth-service** | `sourcepole/qwc-db-auth` | JWT authentication and session management | 9090 |
| **qwc-ogc-service** | `sourcepole/qwc-ogc-service` | OGC proxy with permission filtering | 9090 |
| **qwc-data-service** | `sourcepole/qwc-data-service` | REST API for feature CRUD operations | 9090 |
| **qwc-permalink-service** | `sourcepole/qwc-permalink-service` | Permanent link generation and resolution | 9090 |
| **qwc-config-service** | `sourcepole/qwc-config-generator` | Configuration generator from QGIS projects | 9090 |

#### Infrastructure Services

| Service | Image | Description | Default Port |
| --------- | ------- | ------------- | -------------- |
| **qwc-qgis-server** | `sourcepole/qwc-qgis-server` | QGIS Server (Apache + FCGI) | 80/1080 |
| **qwc-db** | `postgis/postgis:16-3.4` | PostgreSQL with PostGIS | 5432 |

### Service Dependencies and Startup Order

```raw
                    ┌────────────────────┐
                    │     1. qwc-db      │
                    │   (PostgreSQL +    │
                    │     PostGIS)       │
                    └─────────┬──────────┘
                              │
                              ▼
                    ┌────────────────────┐
                    │  2. qwc-qgis-server│
                    │   (Must be ready   │
                    │   for config-svc)  │
                    └─────────┬──────────┘
                              │
                              ▼
                    ┌────────────────────┐
                    │ 3. qwc-config-svc  │
                    │  (Generates all    │
                    │   configurations)  │
                    └─────────┬──────────┘
                              │
           ┌──────────────────┼──────────────────┐
           │                  │                  │
           ▼                  ▼                  ▼
    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
    │qwc-map-viewer│   │qwc-ogc-svc  │    │qwc-auth-svc │
    └─────────────┘    └─────────────┘    └─────────────┘
           │                  │                  │
           ▼                  ▼                  ▼
    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
    │qwc-data-svc │    │qwc-admin-gui│    │qwc-permalink│
    └─────────────┘    └─────────────┘    └─────────────┘
```

### Communication Matrix

| From → To | qwc-db | qgis-server | config-svc | ogc-svc | data-svc | auth-svc |
| ----------- | -------- | ------------- | ------------ | --------- | ---------- | ---------- |
| **qgis-server** | ✅ R | - | - | - | - | - |
| **config-service** | ✅ R | ✅ HTTP | - | - | - | - |
| **map-viewer** | - | - | ✅ HTTP | ✅ HTTP | ✅ HTTP | ✅ HTTP |
| **ogc-service** | - | ✅ HTTP | ✅ HTTP | - | - | - |
| **data-service** | ✅ R/W | - | ✅ HTTP | - | - | - |
| **auth-service** | ✅ R | - | ✅ HTTP | - | - | - |
| **admin-gui** | ✅ R/W | - | ✅ HTTP | - | - | - |
| **permalink-svc** | ✅ R/W | - | ✅ HTTP | - | - | - |

**Legend:** ✅ R = Read, ✅ R/W = Read/Write, ✅ HTTP = HTTP communication

---

## Services, Endpoints and Flows

### URL Routing Overview

| Path | Service | Description |
| ------ | --------- | ------------- |
| `/` | qwc-map-viewer | Main map application |
| `/auth/*` | qwc-auth-service | Authentication endpoints |
| `/ows/*` | qwc-ogc-service | OGC services (WMS, WFS) |
| `/api/v1/data/*` | qwc-data-service | Feature data REST API |
| `/api/v1/permalink/*` | qwc-permalink-service | Permalink operations |
| `/admin/*` | qwc-admin-gui | Administration interface |

### Map Viewer Service

**Service**: `qwc-map-viewer`
**Path**: `/`
**Purpose**: Main web application for map visualization

#### Endpoints

| Endpoint | Method | Description |
| ---------- | -------- | ------------- |
| `/` | GET | Main application page |
| `/themes.json` | GET | Available themes/maps configuration |
| `/assets/*` | GET | Static assets (JS, CSS, images) |

#### Request Flow: Loading Map Viewer

```raw
Browser                    Gateway              Map Viewer           Config Service
   │                          │                     │                      │
   │  GET /                   │                     │                      │
   ├─────────────────────────►│                     │                      │
   │                          │  Route to service   │                      │
   │                          ├────────────────────►│                      │
   │                          │                     │                      │
   │                          │◄────────────────────┤                      │
   │◄─────────────────────────┤  HTML + JS bundle   │                      │
   │                          │                     │                      │
   │  GET /themes.json        │                     │                      │
   ├─────────────────────────►├────────────────────►│                      │
   │                          │                     │  GET themes config   │
   │                          │                     ├─────────────────────►│
   │                          │                     │◄─────────────────────┤
   │◄─────────────────────────┤◄────────────────────┤                      │
   │  Themes JSON             │                     │                      │
```

### Authentication Service

**Service**: `qwc-auth-service`
**Path**: `/auth/`
**Purpose**: User authentication and JWT token management

#### Endpoints

| Endpoint | Method | Description |
| ---------- | -------- | ------------- |
| `/auth/login` | POST | Authenticate user, return JWT |
| `/auth/logout` | POST | Invalidate session |
| `/auth/userinfo` | GET | Get current user information |
| `/auth/verify` | GET | Verify JWT token validity |

#### Login Request

**Request:**

```http
POST /auth/login
Content-Type: application/x-www-form-urlencoded

username=demo&password=demo
```

**Response (200 OK):**

```json
{
  "username": "demo",
  "name": "Demo User",
  "email": "demo@example.com",
  "roles": ["user"]
}
```

**Response Headers:**

```raw
Set-Cookie: jwt_token=eyJhbGc...; HttpOnly; Secure; SameSite=Strict
```

#### Authentication Flow

```raw
Browser                    Auth Service              Database
   │                            │                        │
   │  POST /auth/login          │                        │
   │  username=demo             │                        │
   │  password=demo             │                        │
   ├───────────────────────────►│                        │
   │                            │  SELECT * FROM users   │
   │                            │  WHERE name='demo'     │
   │                            ├───────────────────────►│
   │                            │◄───────────────────────┤
   │                            │  Verify password hash  │
   │                            │                        │
   │                            │  Generate JWT token    │
   │◄───────────────────────────┤                        │
   │  Set-Cookie: jwt_token=... │                        │
   │  200 OK + user info        │                        │
```

### OGC Service

**Service**: `qwc-ogc-service`
**Path**: `/ows/`
**Purpose**: OGC-compliant services proxy with authentication

#### WMS Endpoints

| Request | Description |
| --------- | ------------- |
| `GetCapabilities` | List available layers and operations |
| `GetMap` | Render map image |
| `GetFeatureInfo` | Query feature attributes at point |
| `GetLegendGraphic` | Get layer legend image |
| `GetPrint` | Generate print layout |

#### Example: GetCapabilities

```http
GET /ows/demo?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities
```

**Response:** XML capabilities document

#### Example: GetMap

```http
GET /ows/demo?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap
    &LAYERS=European%20Cities
    &CRS=EPSG:3857
    &BBOX=-1500000,4000000,3500000,7500000
    &WIDTH=800
    &HEIGHT=600
    &FORMAT=image/png
```

**Response:** PNG image

#### WMS Request Flow

```raw
Browser        OGC Service       Permissions         QGIS Server         Database
   │               │                  │                   │                  │
   │  GetMap       │                  │                   │                  │
   │  LAYERS=...   │                  │                   │                  │
   ├──────────────►│                  │                   │                  │
   │               │  Check JWT       │                   │                  │
   │               │  permissions     │                   │                  │
   │               ├─────────────────►│                   │                  │
   │               │◄─────────────────┤                   │                  │
   │               │  Allowed layers  │                   │                  │
   │               │                  │                   │                  │
   │               │  Forward request │                   │                  │
   │               ├──────────────────────────────────────►│                  │
   │               │                  │                   │  Query geodata   │
   │               │                  │                   ├─────────────────►│
   │               │                  │                   │◄─────────────────┤
   │               │                  │                   │  Render image    │
   │               │◄──────────────────────────────────────┤                  │
   │◄──────────────┤  PNG Image       │                   │                  │
```

### Data Service

**Service**: `qwc-data-service`
**Path**: `/api/v1/data/`
**Purpose**: REST API for geospatial feature operations

#### Endpoints

| Endpoint | Method | Description |
| ---------- | -------- | ------------- |
| `/api/v1/data/{dataset}` | GET | List features (GeoJSON) |
| `/api/v1/data/{dataset}/{id}` | GET | Get single feature |
| `/api/v1/data/{dataset}` | POST | Create new feature |
| `/api/v1/data/{dataset}/{id}` | PUT | Update feature |
| `/api/v1/data/{dataset}/{id}` | DELETE | Delete feature |

#### Query Parameters

| Parameter | Description | Example |
| ----------- | ------------- | --------- |
| `bbox` | Bounding box filter | `bbox=0,0,100,100` |
| `filter` | CQL filter expression | `filter=population>1000000` |
| `limit` | Maximum features | `limit=100` |
| `offset` | Pagination offset | `offset=50` |

#### Example: Get Features

```http
GET /api/v1/data/demo.cities?limit=5
Cookie: jwt_token=...
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
        "type": "Point",
        "coordinates": [1391493.64, 5145609.47]
      },
      "properties": {
        "name": "Rome",
        "country": "Italy",
        "population": 2870000
      }
    }
  ]
}
```

### Admin GUI

**Service**: `qwc-admin-gui`
**Path**: `/admin/`
**Purpose**: Administrative interface for system management

#### Features

| Section | Capabilities |
| --------- | ------------- |
| **Users** | Create, edit, delete users; password management |
| **Groups** | Manage user groups |
| **Roles** | Define and assign roles |
| **Resources** | Manage maps, layers, data resources |
| **Permissions** | Configure layer and resource permissions |

#### Access

- **URL**: `https://maps.example.com/admin/`
- **Default Credentials**: `admin` / `demo`

### Permalink Service

**Service**: `qwc-permalink-service`
**Path**: `/api/v1/permalink/`
**Purpose**: Create and resolve shareable map state URLs

#### Endpoints

| Endpoint | Method | Description |
| ---------- | -------- | ------------- |
| `/api/v1/permalink/` | POST | Create permalink |
| `/api/v1/permalink/{id}` | GET | Resolve permalink |

#### Example: Create Permalink

```http
POST /api/v1/permalink/
Content-Type: application/json

{
  "mapState": {
    "center": [1000000, 5000000],
    "zoom": 8,
    "layers": ["European Cities", "Roads"]
  }
}
```

**Response (201 Created):**

```json
{
  "id": "abc123",
  "url": "/api/v1/permalink/abc123"
}
```

---

### Exposed Endpoints Reference

This section provides a consolidated view of all publicly exposed endpoints, their purpose, and the routing logic.

#### Routing Schema

```raw
                                  HTTPS Request
                                       │
                                       ▼
                         ┌───────────────────────────┐
                         │   Gateway / Load Balancer │
                         └─────────────┬─────────────┘
                                       │
          ┌────────────────────────────┼────────────────────────────┐
          │                            │                            │
          ▼                            ▼                            ▼
  ┌───────────────┐            ┌───────────────┐            ┌───────────────┐
  │     ROOT      │            │      API      │            │     ADMIN     │
  │      (/)      │            │   (/api/*)    │            │    (/admin)   │
  └───────┬───────┘            └───────┬───────┘            └───────┬───────┘
          │                            │                            │
          │                    ┌───────┴───────┐                    │
          │                    │               │                    │
          ▼                    ▼               ▼                    ▼
   qwc-map-viewer       qwc-data-svc    qwc-permalink      qwc-admin-gui
   (Frontend App)       (Feature API)   (Share Links)      (Management UI)

          │                            │                            │
          ▼                            ▼                            ▼
  ┌───────────────┐            ┌───────────────┐            ┌───────────────┐
  │     AUTH      │            │      OGC      │            │  QGIS SERVER  │
  │    (/auth)    │            │     (/ows)    │            │(Direct Access)│
  └───────┬───────┘            └───────┬───────┘            └───────┬───────┘
          │                            │                            │
          ▼                            ▼                            ▼
   qwc-auth-service             qwc-ogc-service              qwc-qgis-server
   (Login/Token)                (WMS/WFS Proxy)              (WMS/WFS Core)
```

#### Public Endpoints Matrix

| Path Prefix | Service | Function | Auth Required |
| ------------- | --------- | ---------- | --------------- |
| `/` | `qwc-map-viewer` | **Main Application**: Loads the map viewer interface, themes, and static assets. | No |
| `/auth/login` | `qwc-auth-service` | **Login**: Authenticates user and issues JWT cookie. | No |
| `/auth/logout` | `qwc-auth-service` | **Logout**: Invalidates the user session. | No |
| `/auth/userinfo` | `qwc-auth-service` | **User Info**: Returns details of the logged-in user. | Yes |
| `/ows/*` | `qwc-ogc-service` | **OGC Proxy**: Serves WMS/WFS/WCS requests (GetMap, GetFeature) with permission checks. | Optional* |
| `/api/v1/data/*` | `qwc-data-service` | **Data API**: CRUD operations for vector features and attachments. | Yes |
| `/api/v1/permalink/*` | `qwc-permalink-service` | **Permalinks**: Generates and resolves short URLs for map states. | No |
| `/admin/*` | `qwc-admin-gui` | **Admin UI**: Interface for managing users, permissions, and configuration. | Yes (Admin) |

> (*) **Note on OGC Auth**: Authentication for `/ows` depends on the specific layer permissions. Public layers can be accessed without auth, while protected layers require a valid JWT cookie.

#### Direct QGIS Server Access (Optional)

If configured, QGIS Server can be exposed directly, bypassing the OGC proxy. This is useful for debugging or internal use but bypasses QWC permission checks.

| Path | Service | Function | Auth Required |
| ------ | --------- | ---------- | --------------- |
| `/` (on specific host) | `qwc-qgis-server` | **Direct WMS/WFS**: Direct access to QGIS Server. | No (Basic Auth possible) |

---

## Volumes and Persistent Storage

### Volume Architecture

```raw
┌──────────────────────────────────────────────────────────────────────────────┐
│                            PERSISTENT VOLUMES                                 │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌─────────────────────┐    Exclusive RWO    ┌───────────────────────────┐  │
│  │    vol-db-data      │◄───────────────────►│      qwc-db               │  │
│  │  (PostgreSQL data)  │                     │   (PostgreSQL + PostGIS)  │  │
│  │   Size: 20-100 Gi   │                     └───────────────────────────┘  │
│  └─────────────────────┘                                                     │
│                                                                               │
│  ┌─────────────────────┐    ReadWriteMany    ┌───────────────────────────┐  │
│  │  qgis-resources      │◄───────────────────►│  qwc-qgis-server (RO)     │  │
│  │  (QGIS Projects)    │◄───────────────────►│  qwc-config-service (RO)  │  │
│  │   Size: 5-50 Gi     │◄───────────────────►│  qwc-admin-gui (RW)       │  │
│  └─────────────────────┘                     └───────────────────────────┘  │
│                                                                               │
│  ┌─────────────────────┐    ReadWriteMany    ┌───────────────────────────┐  │
│  │  config-input       │◄───────────────────►│  qwc-config-service (RW)  │  │
│  │  (Templates)        │◄───────────────────►│  qwc-admin-gui (RW)       │  │
│  │   Size: 1 Gi        │                     └───────────────────────────┘  │
│  └─────────────────────┘                                                     │
│                                                                               │
│  ┌─────────────────────┐    ReadWriteMany    ┌───────────────────────────┐  │
│  │  config-generated   │◄───────────────────►│  qwc-config-service (RW)  │  │
│  │  (Runtime configs)  │◄───────────────────►│  ALL OTHER SERVICES (RO)  │  │
│  │   Size: 1 Gi        │                     └───────────────────────────┘  │
│  └─────────────────────┘                                                     │
│                                                                               │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Volume Details

#### Database Data Volume

| Property | Value |
| ---------- | ------- |
| **Name** | `{release}-qwcdb-data-claim` |
| **Purpose** | PostgreSQL data files, WAL logs |
| **Access Mode** | **ReadWriteOnce (RWO)** |
| **Recommended Size** | 20 Gi (minimum) - 100+ Gi (production) |
| **Used By** | qwc-db (exclusive) |
| **Mount Path** | `/var/lib/postgresql/data` |
| **Backup Required** | **CRITICAL - Daily backups required** |

**Contents:**

```raw
/var/lib/postgresql/data/
├── base/                    # Database files
├── global/                  # Cluster-wide tables
├── pg_wal/                  # Write-ahead logs
├── pg_xact/                 # Transaction status
└── postgresql.conf          # Configuration
```

#### QGIS Projects Volume

| Property | Value |
| ---------- | ------- |
| **Name** | `{release}-qwcqgisserver-qgis-resources-claim` |
| **Purpose** | QGIS project files (.qgs, .qgz), symbols, fonts |
| **Access Mode** | **ReadWriteMany (RWX)** |
| **Recommended Size** | 10 Gi |
| **Used By** | qwc-qgis-server (RO), qwc-config-service (RO), qwc-admin-gui (RW) |
| **Mount Path** | `/data/` |
| **Backup Required** | Yes - Weekly or after changes |

**Contents:**

```raw
/data/
├── demo.qgs                 # QGIS project files
├── other_project.qgz
├── symbols/                 # Custom SVG symbols
│   └── marker.svg
└── fonts/                   # Custom fonts
    └── custom.ttf
```

#### Configuration Input Volume

| Property | Value |
| ---------- | ------- |
| **Name** | `{release}-qwcconfigservice-config-input-claim` |
| **Purpose** | User-editable configuration templates |
| **Access Mode** | **ReadWriteMany (RWX)** |
| **Recommended Size** | 1 Gi |
| **Used By** | qwc-config-service (RW), qwc-admin-gui (RW) |
| **Mount Path** | `/qwc_cfg/config-in/` |
| **Backup Required** | Yes - After configuration changes |

**Contents:**

```raw
/qwc_cfg/config-in/
└── default/                 # Tenant name
    ├── tenantConfig.json    # Tenant settings
    └── themes/
        └── config.json      # Theme definitions
```

#### Configuration Generated Volume

| Property | Value |
| ---------- | ------- |
| **Name** | `{release}-qwcconfigservice-config-generated-claim` |
| **Purpose** | Runtime configurations generated by config-service |
| **Access Mode** | **ReadWriteMany (RWX)** |
| **Recommended Size** | 1 Gi |
| **Used By** | qwc-config-service (RW), all other services (RO) |
| **Mount Path** | `/qwc_cfg/config-generated/` |
| **Backup Required** | No - Can be regenerated |

**Contents:**

```raw
/qwc_cfg/config-generated/
└── default/
    ├── mapViewerConfig.json    # Map viewer themes
    ├── ogcConfig.json          # OGC service config
    ├── permissions.json        # Layer permissions
    ├── adminGuiConfig.json     # Admin GUI config
    └── dbAuthConfig.json       # Auth config
```

### Volume Summary Table

| Volume | Access Mode | Size | Services (Access) | Critical |
| -------- | ------------- | ------ | ------------------- | ---------- |
| **db-data** | RWO | 20-100 Gi | qwc-db (RW) | ⚠️ CRITICAL |
| **qgis-projects** | RWX | 10 Gi | qgis-server (RO), config-svc (RO), admin-gui (RW) | Important |
| **config-input** | RWX | 1 Gi | config-svc (RW), admin-gui (RW) | Important |
| **config-generated** | RWX | 1 Gi | config-svc (RW), all others (RO) | Regenerable |
| **attachments** | RWX | 10 Gi | data-service (RW) | Important |

### Storage Class Requirements

#### For ReadWriteMany (RWX) Volumes

RWX volumes require a storage provisioner that supports multi-node access:

| Cloud Provider | Recommended Storage Class |
| ---------------- | --------------------------- |
| **AWS** | EFS (Elastic File System) |
| **Azure** | Azure Files |
| **GCP** | Filestore |
| **On-Premise** | NFS, CephFS, GlusterFS |

**Example NFS StorageClass:**

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-rwx
provisioner: nfs.csi.k8s.io
parameters:
  server: nfs-server.example.com
  share: /exports/qwc
reclaimPolicy: Retain
volumeBindingMode: Immediate
```

---

## Helm Chart Configuration

### Configuration Files Structure

```raw
qwc-helm/
├── values.yaml     # Your custom overrides
├── charts/                  # Sub-charts for each service
│   ├── qwc-db/
│   ├── qwc-qgis-server/
│   ├── qwc-config-service/
│   ├── qwc-map-viewer/
│   ├── qwc-ogc-service/
│   ├── qwc-data-service/
│   ├── qwc-auth-service/
│   ├── qwc-admin-gui/
│   └── qwc-permalink-service/
└── scripts/
    └── init-demo-data.sh    # Demo data initialization
```

### Essential Configuration (values.yaml)

#### Global Settings

```yaml
global:
  # Instance identification
  instanceName: my-qwc-instance

  # External hostnames for access
  hostnames:
    - maps.example.com
    - myhostname.com

  # Gateway API configuration
  gateway:
    name: gateway-private
    namespace: balancers-dev
    sectionName: https

  # Database credentials (CHANGE FOR PRODUCTION!)
  db:
    secrets:
      main:
        user: postgres
        password: "YOUR_POSTGRES_PASSWORD"
      qwcAdmin:
        user: qwc_admin
        password: "YOUR_SECURE_PASSWORD"
      qwcDemoRead:
        user: qwc_service
        password: "YOUR_SECURE_PASSWORD"
      qwcDemoWrite:
        user: qwc_service_write
        password: "YOUR_SECURE_PASSWORD"
      myUser:
        user: user
        password: "THE_PASSWORD"

  # JWT Secret for authentication (CHANGE FOR PRODUCTION!)
  # Must be at least 32 characters
  jwtSecret: "your-very-secure-jwt-secret-at-least-32-chars"
```

#### Persistence Settings

Volumes and claims are configured in the `global` section. There are 7 volumes/claims to configure:

```yaml
global:
  persistence:
    # true  = Chart creates PVCs dynamically (development)
    # false = Expects pre-existing PVCs (production)
    createVolumes: false

    db:
    configInput:
    configOutput:
    qwcApp:
    attachments:
    infoTemplates:
    qgisResources:
```

Each bloc as the same content, f.e. for `db`:

```yaml
global:
    db:
      # === Storage class name for PVCs
      # === IMPORTANT: Use Azure Disk (managed-csi) instead of Azure Files for PostgreSQL
      # === Azure Files does NOT support chmod/chown operations required by PostgreSQL initdb
      storageClassName: managed-csi # Use Azure Disk for PostgreSQL
      # === Size for PVC
      size: 10Gi
      # === Local paths for PVs when storageClassName is local-storage, ie. dev mode
      # volumePath: /data/db/
      # === Overrides claim name.
      # claimOverride: claim-01
```

or for local storage:

```yaml
global:
    db:
      # === Storage class name for PVCs
      storageClassName: local-storage
      # === Size for PVC
      size: 10Gi
      # === Local paths for PVs when storageClassName is local-storage, ie. dev mode
      volumePath: /data/db/
      # === Overrides claim name.
      # claimOverride: claim-01
```

if you have `global.persistence.createVolumes` to `true`:

- then in most of cases you do not need to specify `claimOverride` and claim will be generated automatically
- if the `storageClassName` is a driver mapping local directory, then you should set the `volumePath`

If you set a `claimOverride` for one of the volume above, no PVC will be generated automatically.

#### Database Configuration

```yaml
qwcDb:
  enabled: true

  image:
    repository: postgis/postgis
    tag: "16-3.4"

  resources:
    requests:
      memory: "512Mi"
      cpu: "250m"
    limits:
      memory: "2Gi"
      cpu: "1000m"
```

#### QGIS Server Configuration

```yaml
qwcQgisServer:
  enabled: true

  image:
    repository: sourcepole/qwc-qgis-server
    tag: "3.34"

  resources:
    requests:
      memory: "1Gi"
      cpu: "500m"
    limits:
      memory: "4Gi"
      cpu: "2000m"

  env:
    QGIS_SERVER_LOG_LEVEL: "1"          # 0=None, 1=Info, 2=Debug
    QGIS_SERVER_MAX_THREADS: "4"
    QGIS_SERVER_CACHE_SIZE: "268435456"  # 256MB cache
```

#### Map Viewer Configuration

```yaml
qwcMapViewer:
  enabled: true

  image:
    repository: sourcepole/qwc-map-viewer
    tag: "latest"

  env:
    CONFIG_PATH: "/qwc_cfg/config"
    DEFAULT_TENANT: "default"
    SERVICE_MOUNTPOINT: "/"
```

#### Authentication Configuration

```yaml
qwcAuthService:
  enabled: true

  env:
    # Security settings (ENABLE FOR PRODUCTION!)
    JWT_COOKIE_SECURE: "true"        # Requires HTTPS
    JWT_COOKIE_SAMESITE: "Strict"    # CSRF protection
    JWT_TOKEN_EXPIRATION: "3600"     # 1 hour

    # Optional features
    TOTP_ENABLED: "false"            # 2FA support
```

### Production Configuration Checklist

⚠️ **CRITICAL: Change these before production deployment!**

| Setting | Demo Value | Production Action |
| --------- | ------------ | ------------------- |
| `db.secrets.qwcAdmin.password` | `qwc_admin` | Generate strong password |
| `db.secrets.main.password` | `postgres` | Generate strong password |
| `jwtSecret` | `changeme...` | `openssl rand -base64 32` |
| Admin user password | `demo` | Change via Admin GUI or SQL |
| `JWT_COOKIE_SECURE` | `false` | Set to `true` (requires HTTPS) |
| `JWT_COOKIE_SAMESITE` | `Lax` | Set to `Strict` |

#### Generate Secure Secrets

```bash
## Generate JWT secret
openssl rand -base64 32

## Generate database passwords
openssl rand -base64 16
```

### HTTPRoute Configuration

HTTPRoutes are created outside this chart:

```yaml
global:
  httpRoute:
    enabled: false
    gateway:
      create: false
```

HTTPRoutes are needed to be created by this chart:

```yaml
  httpRoute:
    enabled: true
    # HOSTNAMES
    hostnames:
      - "mycompany.local"

    # GATEWAY
    gateway:
      create: true
      namespace: qwc-dev
      sectionName: http
```

---

## Installation Guide

### Prerequisites

| Requirement | Minimum Version | Notes |
| ------------- | ----------------- | ------- |
| Kubernetes | 1.21+ | Cluster with kubectl access |
| Helm | 3.x | Installed locally |
| kubectl | 1.21+ | Configured for cluster |
| Gateway API | 1.0+ | For HTTPRoute (optional) |
| Storage Class | - | RWX support for shared volumes |

#### Verify Prerequisites

```bash
## Check Kubernetes cluster
kubectl cluster-info

## Check Helm version
helm version

## Check available storage classes
kubectl get storageclass
```

### Installation Steps

#### Step 1: Clone Repository

```bash
git clone <repository-url>
cd qwc-helm-main
```

#### Step 2: Create Configuration Override

```bash
cp values.yaml values.yaml
```

#### Step 3: Edit Configuration

Edit `values.yaml` with your settings:

```yaml
global:
  hostnames:
    - maps.your-domain.com

  db:
    secrets:
      main:
        user: postgres
        password: "YOUR_POSTGRES_PASSWORD"
      qwcAdmin:
        user: qwc_admin
        password: "YOUR_SECURE_PASSWORD"
      qwcDemoRead:
        user: qwc_service
        password: "YOUR_SECURE_PASSWORD"
      qwcDemoWrite:
        user: qwc_service_write
        password: "YOUR_SECURE_PASSWORD"
      myUser:
        user: user
        password: "THE_PASSWORD"

  jwtSecret: "YOUR_32_CHAR_JWT_SECRET"
```

#### Step 4: Install with Helm

```bash
helm upgrade --install my-qwc-instance . \
  -n qwc-dev \
  -f ./values.yaml \
  --create-namespace
```

#### Step 5: Verify Installation

```bash
## Check all pods are running
kubectl get pods -n qwc-dev

## Expected output: All pods in "Running" state
NAME                                              READY   STATUS    RESTARTS   AGE
my-qwc-instance-qwcdb-xxx                        1/1     Running   0          5m
my-qwc-instance-qwcqgisserver-xxx                1/1     Running   0          5m
my-qwc-instance-qwcconfigservice-xxx             1/1     Running   0          5m
my-qwc-instance-qwcmapviewer-xxx                 1/1     Running   0          5m
my-qwc-instance-qwcogcservice-xxx                1/1     Running   0          5m
my-qwc-instance-qwcauthservice-xxx               1/1     Running   0          5m
my-qwc-instance-qwcadmingui-xxx                  1/1     Running   0          5m
my-qwc-instance-qwcpermalinkservice-xxx          1/1     Running   0          5m
```

#### Step 6: Initialize Demo Data

```bash
./scripts/init-demo-data.sh
```

The script will:

1. Prompt for namespace (default: `qwc-dev`)
2. Create PostGIS extension
3. Create demo users (`admin/demo`, `demo/demo`)
4. Create sample geospatial data
5. Deploy demo QGIS project
6. Configure Map Viewer theme

### Verification Tests

#### Test WMS Service

```bash
## GetCapabilities
curl "https://myhostname.com/ows/demo?SERVICE=WMS&REQUEST=GetCapabilities"

## GetMap (download image)
curl "https://myhostname.com/ows/demo?\
SERVICE=WMS&REQUEST=GetMap&VERSION=1.3.0\
&LAYERS=European%20Cities\
&CRS=EPSG:3857\
&BBOX=-1500000,4000000,3500000,7500000\
&WIDTH=800&HEIGHT=600\
&FORMAT=image/png" -o map.png
```

#### Test Authentication

```bash
## Login
curl -X POST "https://myhostname.com/auth/login" \
  -d "username=demo&password=demo" \
  -c cookies.txt

## Get user info
curl "https://myhostname.com/auth/userinfo" \
  -b cookies.txt
```

#### Test Data Service

```bash
## Get cities (requires authentication)
curl "https://myhostname.com/api/v1/data/demo.cities?limit=5" \
  -b cookies.txt
```

### Upgrade

```bash
## Apply configuration changes
helm upgrade my-qwc-instance . \
  -n qwc-dev \
  -f ./values.yaml
```

### Uninstall

```bash
## Remove Helm release
helm uninstall my-qwc-instance -n qwc-dev

## Remove PVCs (WARNING: Deletes all data!)
kubectl delete pvc --all -n qwc-dev

## Remove namespace (optional)
kubectl delete namespace qwc-dev
```

---

## Troubleshooting

### Common Issues

#### Pods Not Starting

**Symptom:** Pods stuck in `Pending`, `ContainerCreating`, or `CrashLoopBackOff`

**Diagnosis:**

```bash
## Check pod status
kubectl get pods -n qwc-dev

## Check pod events
kubectl describe pod <pod-name> -n qwc-dev

## Check logs
kubectl logs <pod-name> -n qwc-dev
```

**Common Causes:**

- PVC not bound (check storage class)
- Image pull errors (check credentials)
- Resource limits too low
- Database not ready

#### Map Viewer Shows Blank Map

**Symptom:** Map loads but shows only background, no layers

**Diagnosis:**

```bash
## Check themes.json
curl "https://myhostname.com/themes.json"

## Check WMS capabilities
curl "https://myhostname.com/ows/demo?SERVICE=WMS&REQUEST=GetCapabilities"

## Check config-service logs
kubectl logs -n qwc-dev -l app.kubernetes.io/name=qwcconfigservice
```

**Solutions:**

1. Refresh browser cache (Ctrl+F5)
2. Run `./scripts/init-demo-data.sh` again
3. Restart config-service: `kubectl rollout restart deployment -n qwc-dev my-qwc-instance-qwcconfigservice`

#### Cannot Login

**Symptom:** Login fails with "Invalid credentials"

**Diagnosis:**

```bash
## Check users in database
kubectl exec -n qwc-dev deployment/my-qwc-instance-qwcdb -- \
  psql -U postgres -d qwc_services -c "SELECT name, active FROM qwc_config.users;"
```

**Solutions:**

```bash
## Reset admin password to 'demo'
kubectl exec -n qwc-dev deployment/my-qwc-instance-qwcdb -- \
  psql -U postgres -d qwc_services -c \
  "UPDATE qwc_config.users SET password_hash = crypt('demo', gen_salt('bf')) WHERE name = 'admin';"
```

#### HTTPRoute Not Working

**Symptom:** Cannot access via external hostname

**Diagnosis:**

```bash
## Check HTTPRoutes
kubectl get httproute -n qwc-dev

## Check status
kubectl describe httproute -n qwc-dev <route-name>
```

**Common Issues:**

- Gateway not found (check gateway namespace/name)
- Hostname certificate not available
- Conflicting routes

### Useful Commands

#### Pod Management

```bash
## Get all pods
kubectl get pods -n qwc-dev

## Watch pods status
kubectl get pods -n qwc-dev -w

## Get pod logs
kubectl logs -n qwc-dev <pod-name> --tail=100

## Shell into pod
kubectl exec -it -n qwc-dev <pod-name> -- bash

## Restart deployment
kubectl rollout restart deployment -n qwc-dev <deployment-name>
```

#### Database Operations

```bash
## Connect to database
kubectl exec -it -n qwc-dev deployment/my-qwc-instance-qwcdb -- \
  psql -U postgres -d qwc_services

## Run SQL query
kubectl exec -n qwc-dev deployment/my-qwc-instance-qwcdb -- \
  psql -U postgres -d qwc_services -c "SELECT * FROM demo.cities LIMIT 5;"
```

#### Configuration Check

```bash
## Check generated configs
kubectl exec -n qwc-dev deployment/my-qwc-instance-qwcconfigservice -- \
  ls -la /qwc_cfg/config-generated/default/

## View config file
kubectl exec -n qwc-dev deployment/my-qwc-instance-qwcconfigservice -- \
  cat /qwc_cfg/config-generated/default/mapViewerConfig.json
```

### Re-initialization

If something is broken, you can re-run the init script:

```bash
./scripts/init-demo-data.sh
```

For a complete reset:

```bash
## Uninstall and reinstall
helm uninstall my-qwc-instance -n qwc-dev
kubectl delete pvc --all -n qwc-dev

helm upgrade --install my-qwc-instance . \
  -n qwc-dev \
  -f ./values.yaml \
  --create-namespace

./scripts/init-demo-data.sh
```

---

## Appendix

### Environment Variables Reference

#### All Services

| Variable | Description | Default |
| ---------- | ------------- | --------- |
| `CONFIG_PATH` | Path to configuration directory | `/srv/qwc_service/config` |
| `JWT_SECRET_KEY` | JWT signing secret | From secret |
| `SERVICE_MOUNTPOINT` | URL path prefix | Service-specific |

#### QGIS Server

| Variable | Description | Default |
| ---------- | ------------- | --------- |
| `QGIS_SERVER_LOG_LEVEL` | Log verbosity (0-3) | `1` |
| `QGIS_SERVER_MAX_THREADS` | Worker threads | `4` |
| `QGIS_SERVER_CACHE_SIZE` | Cache in bytes | `268435456` |
| `PGSERVICEFILE` | pg_service.conf path | `/etc/pg_service.conf` |

#### Auth Service

| Variable | Description | Default |
| ---------- | ------------- | --------- |
| `JWT_COOKIE_SECURE` | HTTPS-only cookies | `false` |
| `JWT_COOKIE_SAMESITE` | SameSite policy | `Lax` |
| `TOTP_ENABLED` | Enable 2FA | `false` |

### Database Schema

#### qwc_config Schema

| Table | Description |
| ------- | ------------- |
| `users` | User accounts |
| `groups` | User groups |
| `roles` | User roles |
| `user_roles` | User-role associations |
| `user_groups` | User-group associations |

#### demo Schema (Sample Data)

| Table | Type | Description |
| ------- | ------ | ------------- |
| `cities` | Point | European cities |
| `roads` | LineString | Road connections |
| `regions` | Polygon | City regions |

### Backup Recommendations

| Data | Frequency | Method | Retention |
| ------ | ----------- | -------- | ----------- |
| Database | Daily | pg_dump | 30 days |
| QGIS Projects | Weekly | File copy | 90 days |
| Config Input | After changes | File copy | 90 days |
| Attachments | Daily | File copy | 30 days |

#### Backup Script Example

```bash
##!/bin/bash
NAMESPACE="qwc-dev"
DATE=$(date +%Y%m%d)
BACKUP_DIR="/backup/qwc"

## Database backup
kubectl exec -n $NAMESPACE deployment/my-qwc-instance-qwcdb -- \
  pg_dump -U postgres qwc_services > "$BACKUP_DIR/db_$DATE.sql"

## Compress
gzip "$BACKUP_DIR/db_$DATE.sql"

## Cleanup old backups (keep 30 days)
find "$BACKUP_DIR" -name "*.gz" -mtime +30 -delete

echo "Backup completed: $BACKUP_DIR/db_$DATE.sql.gz"
```

### Security Best Practices

1. **Change default passwords immediately**
2. **Enable HTTPS** (set `JWT_COOKIE_SECURE: true`)
3. **Use strong JWT secret** (32+ characters, random)
4. **Limit admin access** (only grant admin role to trusted users)
5. **Enable network policies** to restrict pod communication
6. **Regular security updates** for container images
7. **Audit logging** for user actions
8. **Regular backups** with tested restore procedures

### References

- [QWC Official Documentation](https://github.com/qgis/qwc2)
- [QGIS Server Manual](https://docs.qgis.org/latest/en/docs/server_manual/)
- [PostGIS Documentation](https://postgis.net/documentation/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Gateway API](https://gateway-api.sigs.k8s.io/)
