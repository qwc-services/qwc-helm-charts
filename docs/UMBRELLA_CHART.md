# Umbrella chart

An umbrella chart is a Helm Chart referencing other charts to create an application. It brings configurations and data to create a dedicated application.

One can use the main QWC chart or create its own by picking only the needed parts.

## Configuration Files Structure

```raw
qwc-helm/
├── Chart.yaml     # Your custom chart dependencies
├── values.yaml     # Your custom overrides
├── secret-values.yaml     # Your secret
├── pg_service_ro.conf     # read only database accesses
├── pg_service_rw.conf     # read/write database accesses
├── bootstrap/             # Init data for qwc UI. Can be copied from https://github.com/qwc-services/qwc-helm-charts/tree/main/bootstrap and then customized.
│   ├── assets/
│   ├── config/
│   ├── scripts/
│   └── ...
├── templates/             # Extra Helm templates (PV, PVC, gateway, etc.). Can be copied from https://github.com/qwc-services/qwc-helm-charts/tree/main/templates
│   └── ...
├── charts/                  # Custom sub-charts
│   ├── my_other_chart/
│   ├── my_another_chart/
│   └── ...
└── ...
```

## Configuration file examples

### `Chart.yaml`

```yaml
apiVersion: v2
name: qwc
description: My Helm chart for QGIS Web Client

type: application
version: 1.0.0
appVersion: "2026.08.30"

# Aliases are needed to call chart functions from root chart and match internal chart function names in '_helpers.tpl'.
dependencies:
  - name: qwc-db
    version: "3.1.0"
    repository: "oci://ghcr.io/qwc-services/charts"
    alias: qwcDb
    condition: qwcDb.enabled

  - name: qwc-qgis-server
    version: "3.1.0"
    repository: "oci://ghcr.io/qwc-services/charts"
    alias: qwcQgisServer

  - name: qwc-config-service
    version: "3.1.0"
    repository: "oci://ghcr.io/qwc-services/charts"
    alias: qwcConfigService

  - name: qwc-ogc-service
    version: "3.1.0"
    repository: "oci://ghcr.io/qwc-services/charts"
    alias: qwcOgcService

  - name: qwc-map-viewer
    version: "3.1.0"
    repository: "oci://ghcr.io/qwc-services/charts"
    alias: qwcMapViewer

  - name: qwc-admin-gui
    version: "3.1.0"
    repository: "oci://ghcr.io/qwc-services/charts"
    alias: qwcAdminGUI

  - name: qwc-auth-service
    version: "3.1.0"
    repository: "oci://ghcr.io/qwc-services/charts"
    alias: qwcAuthService
```

### `values.yaml`

This example is for AKS without volumes, http routes, gateways and database (they are created outside this chart):

```yaml
# ============================================================
# QWC Services Helm Chart - Main Configuration
# ============================================================
# Deploy with: helm upgrade --install <release-name> . -f values.yaml
# ============================================================

global:
  # ========================================
  # HTTPRoutes
  # ========================================
  httpRoute:
    enabled: false

    # GATEWAY
    gateway:
      create: false

  # ========================================
  # DATABASE
  # ========================================
  db:
    port: 5432
    hostname: pg.gis.example.com

  env:
    # ====== Access to JWT secret
    jwtSecret: {}
      # === secret name or empty to use the default one: 'RELEASE-global-secret'
      # name:
      # === jwt key name within secret or empty to use the default one: 'jsonWebToken'
      # key:

  # ========================================
  # VOLUME MANAGEMENT
  # ========================================
  # true  = Chart creates PVCs dynamically (development)
  # false = Expects pre-existing PVCs (production)
  persistence:
    createVolumes: false

    configInput:
      # === Storage class name for PVCs
      storageClassName: azurefile-csi
      # === Size for PVC
      size: 10Gi

    configOutput:
      # === Storage class name for PVCs
      storageClassName: azurefile-csi
      # === Size for PVC
      size: 10Gi

    qwcApp:
      # === Storage class name for PVCs
      storageClassName: azurefile-csi
      # === Size for PVC
      size: 10Gi

    attachments:
      # === Storage class name for PVCs
      storageClassName: azurefile
      # === Size for PVC
      size: 10Gi

    infoTemplates:
      # === Storage class name for PVCs
      storageClassName: azurefile-csi
      # === Size for PVC
      size: 10Gi

    qgisResources:
      # === Storage class name for PVCs (azurefile-csi for ReadWriteMany)
      storageClassName: azurefile-csi
      # === Size for PVC
      size: 10Gi

# ============================================================
# SUBCHART OVERRIDES
# ============================================================
# Each subchart has sensible defaults. Override here as needed.
# Common overrides:
#   - claimOverrides
#   - image.tag
# ============================================================

# PostgreSQL Database
qwcDb:
  enabled: true
  createDb: false

# QGIS Server
qwcQgisServer:
  enabled: true
  replicaCount: 1

# Config Generator Service
qwcConfigService:
  enabled: true
  env:
    # === uwsgi parameters
    uwsgi:
      # === number of parallel processes per thread
      nbProcess: 1
      # === number of parallel threads
      nbThread: 4

# OGC (WMS/WFS) Service
qwcOgcService:
  enabled: true
  replicaCount: 1
  env:
    authRequired: true
    # === uwsgi parameters
    uwsgi:
      # === listen queue size
      queueSize: 1024

# Map Viewer (Web UI)
qwcMapViewer:
  enabled: true
  env:
    authRequired: true

# Admin GUI
qwcAdminGUI:
  enabled: true
  env:
    jwtCookieCSRFProtect: false

# Auth Service
qwcAuthService:
  enabled: true
  mode: db

```

### `secret-values.yaml`

```yaml
global:
  # ========================================
  # DATABASE
  # ========================================
  db:
    # SECRETS
    # Can also be set via --set or separate values file
    secrets:
      main:
        user: postgres
        password: postgres
      qwcAdmin:
        user: qwc_admin
        password: "my_password"
      qwcDemoRead:
        user: qwc_service
        password: "my_password"
      qwcDemoWrite:
        user: qwc_service_write
        password: "my_password"
      myAppReader:
        user: user_reader
        password: "my_password"

  # jwt secret to be saved in default Secret storage 'RELEASE-global-secret'
  jsonWebToken: the_secret_key
```

### `pg_service_ro.conf`

```ini
## Vars between {{ }} will replaced by `global_secrets.yaml` object

# MANDATORY: for qwc config service
[qwc_configdb]
host={{ qwc_db_host }}
port={{ qwc_db_port }}
dbname=qwc_services
user={{ qwc_admin_user }}
password={{ qwc_admin_pwd }}
sslmode=require

# To save QGIS projects to database
[qgisprojects]
host={{ qwc_db_host }}
port={{ qwc_db_port }}
dbname=gis_fr
user={{ my_app_reader_user }}
password={{ my_app_reader_pwd }}
sslmode=require

# app DB
[my_app_db]
host={{ qwc_db_host }}
port={{ qwc_db_port }}
dbname=my_app_db
user={{ my_app_reader_user }}
password={{ my_app_reader_pwd }}
sslmode=require

```

### `pg_service_rw.conf`

Can be empty if the `qwc-data-service` is not used.

```ini
## Vars between {{ }} will replaced by `global_secrets.yaml` object
```
