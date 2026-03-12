# QWC2 Helm Chart Architecture Documentation

This document provides comprehensive documentation of the QWC2 (QGIS Web Client 2) application architecture deployed by this Helm chart, including component relationships, interactions, volumes, database requirements, and troubleshooting guidance.

## Table of Contents

1. [Overview](#overview)
2. [Architecture Diagram](#architecture-diagram)
3. [Components](#components)
4. [Component Interactions](#component-interactions)
5. [Request Flow](#request-flow)
6. [Volumes and Storage](#volumes-and-storage)
7. [Database Configuration](#database-configuration)
8. [Using an External Database](#using-an-external-database)
9. [Security Configuration](#security-configuration)
10. [Troubleshooting Guide](#troubleshooting-guide)

---

## Overview

QWC2 (QGIS Web Client 2) is a modular web mapping application built on top of QGIS Server. It provides a modern, responsive web interface for viewing and interacting with geospatial data served by QGIS Server through OGC-compliant services (WMS, WFS, WCS, etc.).

The application follows a microservices architecture where each service handles a specific functionality. All services share:

- A common PostgreSQL database for configuration and user management
- JWT (JSON Web Token) based authentication
- A shared `pg_service.conf` file for database connections

---

## Architecture Diagram

```raw
                                    ┌─────────────────────────────────────────────────────────────┐
                                    │                     EXTERNAL TRAFFIC                        │
                                    └─────────────────────────────────────────────────────────────┘
                                                              │
                                                              ▼
                                    ┌─────────────────────────────────────────────────────────────┐
                                    │              API Gateway / Ingress Controller               │
                                    │         (Kubernetes Gateway API / NGINX / Envoy)            │
                                    └─────────────────────────────────────────────────────────────┘
                                                              │
                    ┌─────────────────────────────────────────┼─────────────────────────────────────────┐
                    │                                         │                                         │
        ┌───────────┴───────────┐                 ┌───────────┴───────────┐                 ┌───────────┴───────────┐
        │    /auth/*            │                 │    /ows/*             │                 │    /                  │
        ▼                       │                 ▼                       │                 ▼                       │
┌───────────────────┐           │         ┌───────────────────┐           │         ┌───────────────────┐           │
│  qwc-auth-service │           │         │  qwc-ogc-service  │           │         │  qwc-map-viewer   │           │
│   (DB Auth)       │           │         │                   │           │         │                   │           │
└─────────┬─────────┘           │         └─────────┬─────────┘           │         └─────────┬─────────┘           │
          │                     │                   │                     │                   │                     │
          │                     │                   ▼                     │                   │                     │
          │                     │         ┌───────────────────┐           │                   │                     │
          │                     │         │  qwc-qgis-server  │           │                   │                     │
          │                     │         │  (Apache + FCGI)  │           │                   │                     │
          │                     │         └─────────┬─────────┘           │                   │                     │
          │                     │                   │                     │                   │                     │
        ┌─┴─────────────────────┴───────────────────┴─────────────────────┴───────────────────┴─────────────────────┤
        │                                                                                                           │
        │                                         /api/v1/data/*          /api/v1/permalink/*        /admin/*       │
        │                                                │                        │                     │           │
        │                                   ┌────────────┴──────────┐   ┌────────┴────────┐   ┌────────┴────────┐   │
        │                                   │   qwc-data-service    │   │qwc-permalink-svc│   │  qwc-admin-gui  │   │
        │                                   └───────────┬───────────┘   └────────┬────────┘   └────────┬────────┘   │
        │                                               │                        │                     │            │
        └───────────────────────────────────────────────┼────────────────────────┼─────────────────────┼────────────┘
                                                        │                        │                     │
                                                        ▼                        ▼                     ▼
                                    ┌─────────────────────────────────────────────────────────────┐
                                    │                      PostgreSQL + PostGIS                   │
                                    │                         (qwc-db)                            │
                                    │                                                             │
                                    │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
                                    │  │ qwc_config  │  │  qwc_users  │  │  Geospatial Data    │  │
                                    │  │   schema    │  │   schema    │  │     (PostGIS)       │  │
                                    │  └─────────────┘  └─────────────┘  └─────────────────────┘  │
                                    └─────────────────────────────────────────────────────────────┘

                                                              │
                                    ┌─────────────────────────┴─────────────────────────┐
                                    │                                                   │
                                    ▼                                                   ▼
                    ┌───────────────────────────────┐                   ┌───────────────────────────────┐
                    │     qwc-config-service        │                   │      Persistent Volumes       │
                    │   (Config Generator)          │                   │                               │
                    │                               │                   │  • qgs-resources (QGIS files) │
                    │  Reads: config-in, qgs files  │                   │  • config-out                 │
                    │  Writes: config-out           │                   │  • qwc2 (frontend assets)     │
                    └───────────────────────────────┘                   │  • attachments                │
                                                                        │  • info-templates             │
                                                                        └───────────────────────────────┘
```

---

## Components

### qwc-qgis-server (QGIS Server)

**Image:** `sourcepole/qwc-qgis-server`

**Role:** Core GIS engine that renders maps and serves geospatial data through OGC-compliant services.

**Functionality:**

- Serves WMS (Web Map Service) for map images
- Serves WFS (Web Feature Service) for vector data
- Serves WCS (Web Coverage Service) for raster data
- Serves WMTS (Web Map Tile Service) for cached tiles
- Renders print layouts
- Processes GetFeatureInfo requests

**Technology Stack:**

- Apache HTTP Server with mod_fcgid
- QGIS Server (FastCGI)
- Python plugins support

**Key Environment Variables:**

| Variable | Description | Default |
| ---------- | ------------- | --------- |
| `URL_PREFIX` | URL prefix for OWS requests | `/ows` |
| `FCGI_MIN_PROCESSES` | Minimum FastCGI processes | 3 |
| `FCGI_MAX_PROCESSES` | Maximum FastCGI processes | 100 |
| `QGIS_SERVER_LOG_LEVEL` | Log verbosity (0-3) | 1 |
| `QGIS_SERVER_CACHE_SIZE` | Cache size in bytes | 268435456 |

**Required Volumes:**

- `pg_service.conf` (read-only) - Database connection configuration
- `qgs-resources` (read-only) - QGIS project files (.qgs/.qgz)

---

### qwc-config-service (Config Generator)

**Image:** `sourcepole/qwc-config-generator`

**Role:** Central configuration management service that generates runtime configurations for all QWC services.

**Functionality:**

- Reads QGIS project files and generates service configurations
- Creates permissions and access control configurations
- Generates themes configuration for the map viewer
- Validates configuration consistency
- Provides REST API for configuration retrieval

**Key Environment Variables:**

| Variable | Description |
| ---------- | ------------- |
| `INPUT_CONFIG_PATH` | Path to input configuration templates |
| `OUTPUT_CONFIG_PATH` | Path to generated configurations |
| `QGIS_SERVER_HOST` | Hostname of QGIS Server |
| `QWC_AUTH_HOST` | Hostname for authentication redirects |
| `GENERATE_DYNAMIC_KVRELS` | Enable dynamic key-value relations |

**Required Volumes:**

- `pg_service.conf` (read-only)
- `qgs-resources` (read-only) - QGIS project files
- `config-in` (read-write) - Input configuration templates
- `config-out` (read-write) - Output generated configurations
- `qwc2` (read-write) - Frontend application files

**Critical:** This service must be able to communicate with QGIS Server to read project capabilities.

---

### qwc-map-viewer

**Image:** `sourcepole/qwc-map-viewer`

**Role:** Main web application frontend that provides the user interface for map viewing and interaction.

**Functionality:**

- React-based single-page application
- Map display with OpenLayers
- Layer tree management
- Search functionality
- Feature info display
- Print/Export capabilities
- Measurement tools
- Drawing/Sketching tools

**Key Environment Variables:**

| Variable | Description | Default |
| ---------- | ------------- | --------- |
| `SERVICE_MOUNTPOINT` | URL base path | `/` |
| `AUTH_REQUIRED` | Require authentication | `false` |

**Required Volumes:**

- `config-out` (read-only) - Runtime configuration
- `qwc2/assets` (read-only) - Static assets (logos, custom styles)

---

### qwc-ogc-service

**Image:** `sourcepole/qwc-ogc-service`

**Role:** OGC service proxy that handles authentication and authorization for OGC requests.

**Functionality:**

- Proxies WMS/WFS/WCS requests to QGIS Server
- Applies permission-based filtering
- Handles JWT token validation
- Enforces layer-level access control

**Key Environment Variables:**

| Variable | Description | Default |
| ---------- | ------------- | --------- |
| `SERVICE_MOUNTPOINT` | URL base path | `/ows` |
| `AUTH_REQUIRED` | Require authentication | `false` |

**Required Volumes:**

- `config-out` (read-only)

**Interaction:** Forwards authorized requests to `qwc-qgis-server`.

---

### qwc-data-service

**Image:** `sourcepole/qwc-data-service`

**Role:** REST API service for reading and writing feature data with full CRUD operations.

**Functionality:**

- Feature editing (Create, Read, Update, Delete)
- Geometry editing
- Attribute editing
- File attachments handling
- Transaction management
- Permission-based access control

**Key Environment Variables:**

| Variable | Description |
| ---------- | ------------- |
| `SERVICE_MOUNTPOINT` | `/api/v1/data` |
| `ATTACHMENTS_BASE_DIR` | Directory for file attachments |
| `MAX_ATTACHMENT_FILE_SIZE` | Maximum upload size |

**Required Volumes:**

- `config-out` (read-only)
- `attachments` (read-write) - File attachments storage

**Database Access:** Requires **read-write** access (`pg_service_rw.conf`).

---

### qwc-auth-service (DB Auth)

**Image:** `sourcepole/qwc-db-auth`

**Role:** Authentication service managing user login, sessions, and JWT tokens.

**Functionality:**

- User authentication against database
- JWT token generation and validation
- Session management via cookies
- Password reset functionality
- TOTP (2FA) support (optional)
- LDAP integration (optional)

**Key Environment Variables:**

| Variable | Description | Default |
| ---------- | ------------- | --------- |
| `SERVICE_MOUNTPOINT` | URL base path | `/auth` |
| `JWT_COOKIE_SECURE` | HTTPS-only cookies | `false` |
| `JWT_COOKIE_SAMESITE` | SameSite cookie policy | `Lax` |
| `TOTP_ENABLED` | Enable 2FA | `false` |

**Required Volumes:**

- `config-out` (read-only)

**Security Note:** In production, set `JWT_COOKIE_SECURE=true` and `JWT_COOKIE_SAMESITE=Strict`.

---

### qwc-admin-gui

**Image:** `sourcepole/qwc-admin-gui`

**Role:** Administrative web interface for managing the QWC application.

**Functionality:**

- User and group management
- Permission assignment
- Theme configuration
- Resource management
- Configuration editing
- Log viewing

**Key Environment Variables:**

| Variable | Description |
| ---------- | ------------- |
| `SERVICE_MOUNTPOINT` | `/admin` |
| `DEFAULT_LOCALE` | UI language |
| `GROUP_REGISTRATION_ENABLED` | Allow user self-registration |
| `USER_INFO_FIELDS` | Custom user profile fields |

**Required Volumes:**

- `config-out` (read-only)
- `config-in` (read-write) - For configuration editing
- `qwc2` (read-write) - For theme editing
- `qgs-resources` (read-write) - For project management
- `info-templates` (read-write) - For template editing

---

### qwc-permalink-service

**Image:** `sourcepole/qwc-permalink-service`

**Role:** Generates and resolves permanent links for map states.

**Functionality:**

- Creates short URLs for current map state
- Stores map state (extent, layers, etc.) in database
- Resolves short URLs back to full state

**Key Environment Variables:**

| Variable | Description |
| ---------- | ------------- |
| `SERVICE_MOUNTPOINT` | `/api/v1/permalink` |

**Required Volumes:**

- `config-out` (read-only)

---

### qwc-db (PostgreSQL + PostGIS)

**Image:** `sourcepole/qwc-base-db`

**Role:** Central database for configuration, user management, and geospatial data storage.

**Database Schemas:**

| Schema | Purpose |
| -------- | --------- |
| `qwc_config` | Service configurations |
| `qwc_users` | User accounts and permissions |
| `public` | Geospatial data (PostGIS) |

**Key Features:**

- PostgreSQL 16 with PostGIS extension
- Automatic schema migration via `qwc-base-db-migrate`
- Connection pooling support

---

## Component Interactions

### Service Dependencies

```raw
┌─────────────────────────────────────────────────────────────────────────┐
│                          STARTUP ORDER                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. qwc-db (PostgreSQL)                                                 │
│       │                                                                 │
│       ▼                                                                 │
│  2. qwc-db-migrate (Job - runs once)                                    │
│       │                                                                 │
│       ▼                                                                 │
│  3. qwc-qgis-server                                                     │
│       │                                                                 │
│       ▼                                                                 │
│  4. qwc-config-service (needs QGIS Server for capabilities)             │
│       │                                                                 │
│       ▼                                                                 │
│  5. All other services (need generated config)                          │
│     ├── qwc-map-viewer                                                  │
│     ├── qwc-ogc-service                                                 │
│     ├── qwc-data-service                                                │
│     ├── qwc-auth-service                                                │
│     ├── qwc-admin-gui                                                   │
│     └── qwc-permalink-service                                           │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Communication Matrix

| From → To | qwc-db | qgis-server | config-service | ogc-service | data-service | auth-service |
| ----------- | -------- | ------------- | ---------------- | ------------- | -------------- | -------------- |
| **qgis-server** | ✅ Read | - | - | - | - | - |
| **config-service** | ✅ Read | ✅ HTTP | - | - | - | - |
| **map-viewer** | - | - | ✅ HTTP | ✅ HTTP | ✅ HTTP | ✅ HTTP |
| **ogc-service** | - | ✅ HTTP | ✅ HTTP | - | - | - |
| **data-service** | ✅ R/W | - | ✅ HTTP | - | - | - |
| **auth-service** | ✅ Read | - | ✅ HTTP | - | - | - |
| **admin-gui** | ✅ R/W | - | ✅ HTTP | - | - | - |
| **permalink-service** | ✅ R/W | - | ✅ HTTP | - | - | - |

---

## Request Flow

### Map Viewing Request

```raw
User Browser
     │
     │ GET https://maps.example.com/
     ▼
API Gateway/Ingress
     │
     │ Route: / → qwc-map-viewer
     ▼
qwc-map-viewer
     │
     │ 1. Load index.html
     │ 2. Fetch config from config-service
     │ 3. Initialize map
     │
     │ GET /ows/?SERVICE=WMS&REQUEST=GetMap...
     ▼
qwc-ogc-service
     │
     │ 1. Validate JWT token
     │ 2. Check permissions
     │ 3. Forward to QGIS Server
     ▼
qwc-qgis-server
     │
     │ 1. Load QGIS project
     │ 2. Query PostGIS database
     │ 3. Render map image
     ▼
PostgreSQL/PostGIS
```

### Authentication Flow

```raw
User Browser
     │
     │ POST /auth/login
     │ Body: { username, password }
     ▼
qwc-auth-service
     │
     │ 1. Validate credentials against DB
     │ 2. Generate JWT token
     │ 3. Set HTTP-only cookie
     ▼
PostgreSQL (qwc_users schema)
     │
     │ User authenticated
     ▼
Response with JWT cookie
```

---

## Volumes and Storage

### Volume Overview

| Volume Name | Purpose | Access Mode | Shared By |
| ------------- | --------- | ------------- | ----------- |
| `vol-db-data-rw` | PostgreSQL data | ReadWriteOnce | qwc-db only |
| `vol-qgis-resources-ro` | QGIS project files | ReadOnlyMany | qgis-server, config-service, admin-gui |
| `vol-config-out` | Generated configs | ReadWriteMany | config-service (RW), all others (RO) |
| `vol-qwc-app-ro` | Frontend assets | ReadWriteMany | config-service, map-viewer, admin-gui |
| `vol-attachments-rw` | File attachments | ReadWriteMany | data-service |
| `vol-info-templates` | Feature info templates | ReadWriteMany | admin-gui, feature-info-service |

### Volume Details

#### Database Volume (`vol-db-data-rw`)

**Path:** `/var/lib/postgresql/docker`

**Contents:**

- PostgreSQL data files
- WAL logs
- Configuration

**Important:** Must be backed up regularly. Loss of this volume means loss of all user data and configurations.

#### QGIS Resources (`vol-qgis-resources-ro`)

**Path:** `/data/` (in QGIS Server), `/qgs-resources` (in admin-gui)

**Contents:**

```raw
/data/
├── project1.qgs          # QGIS project files
├── project2.qgz
├── symbols/              # SVG symbols
├── fonts/                # Custom fonts
└── raster/               # Raster data files (if not in DB)
```

**Important:** QGIS project files must have valid database connections defined using service names from `pg_service.conf`.

#### Generated Configuration (`vol-config-out`)

**Path:** `/srv/qwc_service/config` or `/qwc_cfg/config`

**Contents:**

```raw
/config/
└── default/              # Tenant name (multi-tenant support)
    ├── permissions.json
    ├── mapViewerConfig.json
    ├── ogcConfig.json
    ├── dataConfig.json
    └── ...
```

**Generated by:** `qwc-config-service`

**Consumed by:** All QWC services

#### QWC2 Frontend Assets (`vol-qwc-app-ro`)

**Path:** `/qwc2`

**Contents:**

```raw
/qwc2/
├── assets/
│   ├── img/             # Custom images
│   ├── css/             # Custom styles
│   └── news.html        # News popup content
├── translations/         # Custom translations
└── config.json          # Frontend config (optional override)
```

#### Attachments (`vol-attachments-rw`)

**Path:** `/attachments`

**Contents:** User-uploaded files associated with features.

**Important:** Consider storage quotas and backup strategy.

### Volume Sharing Diagram

```raw
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                    PERSISTENT VOLUMES                                   │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                         │
│  ┌──────────────────────┐                                                               │
│  │   vol-db-data-rw     │◄──── qwc-db (exclusive)                                       │
│  └──────────────────────┘                                                               │
│                                                                                         │
│  ┌──────────────────────┐      ┌──────────────────┐                                     │
│  │ vol-qgis-resources   │◄─────│  qwc-qgis-server │ (RO)                                │
│  │        (RO)          │◄─────│  qwc-config-svc  │ (RO)                                │
│  └──────────────────────┘◄─────│  qwc-admin-gui   │ (RW)                                │
│                                └──────────────────┘                                     │
│                                                                                         │
│  ┌──────────────────────┐      ┌───────────────────┐                                    │
│  │  vol-config-out      │◄─────│ qwc-config-svc    │ (RW - generates)                   │
│  │                      │◄─────│ qwc-map-viewer    │ (RO)                               │
│  │                      │◄─────│ qwc-ogc-service   │ (RO)                               │
│  │                      │◄─────│ qwc-data-service  │ (RO)                               │
│  │                      │◄─────│ qwc-auth-service  │ (RO)                               │
│  │                      │◄─────│ qwc-admin-gui     │ (RO)                               │
│  │                      │◄─────│ qwc-permalink-svc │ (RO)                               │
│  └──────────────────────┘      └───────────────────┘                                    │
│                                                                                         │
│  ┌──────────────────────┐      ┌──────────────────┐                                     │
│  │    vol-qwc-app-ro    │◄─────│ qwc-config-svc   │ (RW)                                │
│  │                      │◄─────│ qwc-map-viewer   │ (RO)                                │
│  │                      │◄─────│ qwc-admin-gui    │ (RW)                                │
│  └──────────────────────┘      └──────────────────┘                                     │
│                                                                                         │
│  ┌──────────────────────┐      ┌──────────────────┐                                     │
│  │  vol-attachments-rw  │◄─────│ qwc-data-service │ (RW)                                │
│  └──────────────────────┘      └──────────────────┘                                     │
│                                                                                         │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Database Configuration

### Database Users and Roles

The QWC system uses three main database roles:

| User | Purpose | Permissions |
| ------ | --------- | ------------- |
| `postgres` | Superuser | Full access (admin only) |
| `qwc_admin` | Config DB admin | R/W on qwc_config, qwc_users schemas |
| `qwc_service` | Service read | Read-only on all schemas |
| `qwc_service_write` | Service write | R/W on feature data |

### pg_service.conf Configuration

Database connections are managed via PostgreSQL service files:

**pg_service_ro.conf** (Read-Only):

```ini
[qwc_configdb]
host={{ qwc_db_host }}
port={{ qwc_db_port }}
dbname=qwc_services
user=qwc_admin
password={{ qwc_admin_pwd }}
sslmode=disable

[qwc_geodb]
host={{ qwc_db_host }}
port={{ qwc_db_port }}
dbname=qwc_services
user=qwc_service
password={{ qwc_service_pwd }}
sslmode=disable
```

**pg_service_rw.conf** (Read-Write):

```ini
[qwc_geodb]
host={{ qwc_db_host }}
port={{ qwc_db_port }}
dbname=qwc_services
user=qwc_service_write
password={{ qwc_service_write_pwd }}
sslmode=disable
```

### Service to pg_service.conf Mapping

| Service | pg_service.conf | Required Services |
| --------- | ----------------- | ------------------- |
| qwc-qgis-server | `pg_service_ro.conf` | qwc_geodb |
| qwc-config-service | `pg_service_ro.conf` | qwc_configdb |
| qwc-ogc-service | `pg_service_rw.conf` | - |
| qwc-data-service | `pg_service_rw.conf` | qwc_geodb |
| qwc-auth-service | `pg_service_ro.conf` | qwc_configdb |
| qwc-admin-gui | `pg_service_ro.conf` | qwc_configdb |
| qwc-permalink-service | `pg_service_ro.conf` | qwc_configdb |

---

## Using an External Database

To use an external PostgreSQL database instead of the built-in `qwc-db`:

### Prerequisites

1. **PostgreSQL 12+** with **PostGIS 3.0+** extension installed
2. Network connectivity from Kubernetes cluster to external database
3. Database user accounts created with appropriate permissions

### Step 1: Prepare the External Database

```sql
-- Create database
CREATE DATABASE qwc_services;

-- Connect to qwc_services and enable PostGIS
\c qwc_services
CREATE EXTENSION postgis;

-- Create roles
CREATE ROLE qwc_admin LOGIN PASSWORD 'your_secure_password';
CREATE ROLE qwc_service LOGIN PASSWORD 'your_secure_password';
CREATE ROLE qwc_service_write LOGIN PASSWORD 'your_secure_password';

-- Create schemas
CREATE SCHEMA qwc_config AUTHORIZATION qwc_admin;
CREATE SCHEMA qwc_users AUTHORIZATION qwc_admin;

-- Grant permissions
GRANT USAGE ON SCHEMA qwc_config TO qwc_service;
GRANT SELECT ON ALL TABLES IN SCHEMA qwc_config TO qwc_service;

GRANT USAGE ON SCHEMA public TO qwc_service, qwc_service_write;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO qwc_service;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO qwc_service_write;
```

### Step 2: Run Database Migrations

Use the `qwc-base-db-migrate` container to initialize schemas:

```bash
docker run --rm \
  -v /path/to/pg_service.conf:/tmp/pg_service.conf:ro \
  -e PGSERVICEFILE=/tmp/pg_service.conf \
  sourcepole/qwc-base-db-migrate:v2026.01.05
```

### Step 3: Update Helm Values

Modify your `values.yaml` when it includes the secrets :

```yaml
# Disable built-in database
qwcDb:
  enabled: false  # or simply don't include qwcDb section

# Configure external database connection
global:
  db:
    hostname: your-external-db.example.com
    port: 5432

    secrets:
      qwcAdminPassword: your_qwc_admin_password
      qwcServiceReadPassword: your_qwc_service_password
      qwcServiceWritePassword: your_qwc_service_write_password
```

Or when the secrets are externalized:

- `values.yaml`:

  ```yaml
  # Disable built-in database
  qwcDb:
    enabled: false  # or simply don't include qwcDb section

  # Configure external database connection
  global:
    db:
      hostname: your-external-db.example.com
      port: 5432
  ```

- `secret-values.yaml`:

  ```yaml
  # Configure external database connection
  global:
    db:
      secrets:
        qwcAdminPassword: your_qwc_admin_password
        qwcServiceReadPassword: your_qwc_service_password
        qwcServiceWritePassword: your_qwc_service_write_password
  ```

### Step 4: Update pg_service.conf Files

Adjust `pg_service_ro.conf` and `pg_service_rw.conf` files to specific database paramaters as `sslmode`.

### Step 5: Deploy

```bash
helm upgrade --install my-qwc-instance . \
  -f values.yaml \
  -f secret-values.yaml
```

---

## Security Configuration

### JWT Configuration

All services share a JWT secret for token validation:

```yaml
global:
  jsonWebToken: "your-very-long-secure-random-string-min-32-chars"

  env:
    jwtSecret:
      name: my-qwc-instance-global-secret
      key: jsonWebToken
    jwtCookieCSRFProtect: true
```

Or with `values.yaml` and `secret-values.yaml`:

- `values.yaml`:

  ```yaml
  global:
    env:
      jwtSecret:
        name: my-qwc-instance-global-secret
        key: jsonWebToken
      jwtCookieCSRFProtect: true
  ```

- `secret-values.yaml`:

  ```yaml
  global:
    jsonWebToken: "your-very-long-secure-random-string-min-32-chars"
  ```

### Production Security Checklist

- [ ] Set `JWT_COOKIE_SECURE: true` (requires HTTPS)
- [ ] Set `JWT_COOKIE_SAMESITE: Strict`
- [ ] Use strong, random `JWT_SECRET_KEY` (minimum 32 characters)
- [ ] Enable HTTPS via Ingress/Gateway TLS termination
- [ ] Use `pg_service.conf` with `sslmode=require` for external DB
- [ ] Set appropriate `AUTH_REQUIRED` for services
- [ ] Configure network policies to restrict pod-to-pod communication
- [ ] Use Kubernetes secrets for sensitive values

---

## Troubleshooting Guide

### Common Issues

#### Services Not Starting - Database Connection

**Symptom:** Pods stuck in `Init:0/1` or `CrashLoopBackOff`

**Diagnosis:**

```bash
# Check init container logs
kubectl logs <pod-name> -c wait-for-db

# Check if database is reachable
kubectl exec -it <any-pod> -- nc -zv <db-hostname> 5432
```

**Causes:**

- Database not started yet
- Wrong hostname in `global.db.hostname`
- Network policy blocking connection
- Wrong port configuration

**Solution:**

1. Verify database pod is running: `kubectl get pods -l app.kubernetes.io/name=qwcdb`
2. Check database service: `kubectl get svc | grep qwcdb`
3. Verify hostname matches service name

#### QGIS Server Returns Empty Maps

**Symptom:** WMS requests return blank images

**Diagnosis:**

```bash
# Check QGIS Server logs
kubectl logs <qgis-server-pod>

# Test direct WMS request
kubectl exec -it <qgis-server-pod> -- curl "http://localhost:1080/ows/?SERVICE=WMS&REQUEST=GetCapabilities"
```

**Causes:**

- QGIS project file not found
- Database connection in project file invalid
- Missing PostGIS data
- Permission issues on volume

**Solution:**

1. Verify QGIS project exists in `/data/` volume
2. Check `pg_service.conf` service names match those in QGIS project
3. Verify PostGIS data tables exist
4. Check volume mount permissions

#### Config Generator Fails

**Symptom:** `qwc-config-service` crashes or returns errors

**Diagnosis:**

```bash
# Check config service logs
kubectl logs <config-service-pod>

# Check if QGIS Server is accessible
kubectl exec -it <config-service-pod> -- curl http://<release>-qwcqgisserver/ows/?SERVICE=WMS&REQUEST=GetCapabilities
```

**Causes:**

- Cannot reach QGIS Server
- Invalid input configuration in `config-in`
- Missing required configuration files
- Database schema not initialized

**Solution:**

1. Ensure QGIS Server is running and healthy
2. Validate `tenantConfig.json` format
3. Check database migration completed successfully
4. Review input configuration files for syntax errors

#### Authentication Not Working

**Symptom:** Login fails or JWT tokens not accepted

**Diagnosis:**

```bash
# Check auth service logs
kubectl logs <auth-service-pod>

# Verify JWT secret is set
kubectl get secret <release>-global-secret -o jsonpath='{.data.jsonWebToken}' | base64 -d
```

**Causes:**

- JWT secret mismatch between services
- Cookie settings incompatible with browser
- Database user table not initialized
- CORS configuration issues

**Solution:**

1. Verify all services use same JWT secret
2. For HTTPS, ensure `JWT_COOKIE_SECURE=true`
3. Check `qwc_users` schema exists with default admin user
4. Verify `JWT_COOKIE_SAMESITE` is appropriate

#### HTTPRoute Not Accepted

**Symptom:** Gateway API HTTPRoute shows status != Accepted

**Diagnosis:**

```bash
# Check HTTPRoute status
kubectl get httproute <route-name> -o yaml

# Check Gateway status
kubectl get gateway -A
```

**Causes:**

- Gateway not found or not ready
- Wrong gateway namespace
- Port mismatch
- Missing gateway reference permissions

**Solution:**

1. Verify Gateway exists in specified namespace
2. Check `sectionName` matches Gateway listener
3. Ensure service port matches backend port
4. Check ReferenceGrant if cross-namespace

#### Database Migration Job - kube-api-access Volume Warning

**Symptom:** `db-migrate` job shows warning:

```raw
MountVolume.SetUp failed for volume "kube-api-access-xxx" :
failed to sync configmap cache: timed out waiting for the condition
```

**Diagnosis:**

```bash
# Check job status
kubectl get job -n <namespace> <release-name>-qwcdb-db-migrate

# Check job pod status
kubectl get pods -n <namespace> | grep db-migrate

# Check migration logs (if job completed)
kubectl logs -n <namespace> <db-migrate-pod> -c qwcdb-db-migrate
```

**Causes:**

- Temporary network issues between node and Kubernetes API server
- ConfigMap cache synchronization timeout
- High API server load during pod startup

**Solution:**

1. **This is usually a non-critical warning.** The `kube-api-access` volume is automatically mounted by Kubernetes for API access, but the migration job doesn't require it to function.

2. **Verify job completion:**

   ```bash
   # Job should show "Completed" status
   kubectl get job -n <namespace> <release-name>-qwcdb-db-migrate

   # Check migration logs for success
   kubectl logs -n <namespace> <db-migrate-pod> -c qwcdb-db-migrate | tail -20
   ```

3. **If job failed (not just warning):**
   - Check if database pod is running: `kubectl get pods | grep qwcdb`
   - Verify database is accessible: `kubectl exec -it <db-pod> -- psql -U qwc_admin -d qwc_services -c "SELECT 1;"`
   - Check `pg_service.conf` secret exists: `kubectl get secret <release-name>-global-secret`

4. **If warning persists and causes issues:**
   - Check API server health: `kubectl get --raw /healthz`
   - Review node connectivity to API server
   - Check for network policies blocking API access
   - Consider increasing API server timeout (cluster-level configuration)

**Note:** The migration job runs once during initial deployment. If it completed successfully (status: `Completed`), the warning can be safely ignored. The job will not re-run unless the database is reset or the job is manually deleted.

### Useful Debug Commands

```bash
# View all QWC pods
kubectl get pods -l app.kubernetes.io/part-of=qwc

# View all services
kubectl get svc | grep qwc

# View persistent volume claims
kubectl get pvc

# Describe a failing pod
kubectl describe pod <pod-name>

# Stream logs from all containers
kubectl logs -f <pod-name> --all-containers

# Execute into a container
kubectl exec -it <pod-name> -- /bin/sh

# Check config files in a pod
kubectl exec -it <pod-name> -- cat /srv/qwc_service/config/default/mapViewerConfig.json

# Test database connection from a pod
kubectl exec -it <pod-name> -- psql "service=qwc_configdb" -c "SELECT 1"
```

### Log Locations

| Service | Log Location | Important Logs |
| --------- | -------------- | ---------------- |
| qwc-qgis-server | stdout/stderr | Apache access/error, QGIS Server |
| qwc-config-service | stdout/stderr | Config generation, validation errors |
| qwc-map-viewer | stdout/stderr | uWSGI, Flask application |
| qwc-* services | stdout/stderr | uWSGI, Flask application |
| PostgreSQL | stdout/stderr | Connection logs, query errors |

---

## Additional Resources

- [QWC Services Documentation](https://github.com/qwc-services)
- [QGIS Server Documentation](https://docs.qgis.org/latest/en/docs/server_manual/)
- [PostGIS Documentation](https://postgis.net/documentation/)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
