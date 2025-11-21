# QWC Helm Chart

A Helm chart for deploying QWC2 (QGIS Web Client 2) on Kubernetes.

## Quick Start

```bash
# 1. Install the chart
helm upgrade --install my-qwc-instance . -n qwc-dev -f ./values-override.yaml --create-namespace

# 2. Initialize demo data
./scripts/init-demo-data.sh

# 3. Access the application
open https://myhostname.com/
```

**Demo Credentials:** `admin` / `demo`

For complete installation instructions, see **[docs/QUICK_START.md](docs/QUICK_START.md)**.

---

## Features

- **Map Viewer** - Interactive web map client (QWC2)
- **Admin GUI** - User and permission management
- **OGC Services** - WMS, WFS via QGIS Server
- **Authentication** - JWT-based authentication
- **Data Service** - REST API for feature data
- **Permalink Service** - Shareable map links

## Architecture

The chart deploys multiple interconnected services:

| Service | Description |
| --------- | ------------- |
| `qwcdb` | PostgreSQL database with PostGIS |
| `qwcqgisserver` | QGIS Server for WMS/WFS |
| `qwcconfigservice` | Configuration generator |
| `qwcmapviewer` | QWC2 web client |
| `qwcogcservice` | OGC service proxy |
| `qwcdataservice` | REST data API |
| `qwcauthservice` | Authentication |
| `qwcadmingui` | Admin interface |
| `qwcpermalinkservice` | Permalink management |

## Prerequisites

- Kubernetes 1.21+
- Helm 3.x
- Gateway API (for external access)
- PersistentVolume provisioner

## Installation

### Basic Installation

```bash
# Create values override
cp values.yaml values-override.yaml
# Edit values-override.yaml with your configuration

# Install
helm upgrade --install my-qwc-instance . \
  -n qwc-dev \
  -f ./values-override.yaml \
  --create-namespace
```

### Initialize Demo Data

```bash
# Run the initialization script
./scripts/init-demo-data.sh
```

This will:

- Create demo users (`admin/demo`, `demo/demo`)
- Create sample geospatial data
- Deploy a demo QGIS project
- Configure the Map Viewer theme

## Configuration

Key configuration in `values-override.yaml`:

```yaml
global:
  createVolumes: true  # Set to false if using pre-existing PVCs
  hostnames:
    - myhostname.com
  gateway:
    name: gateway-private
    namespace: balancers-dev
    sectionName: https
  postgresqlSecrets:
    qwcAdminPassword: "your-admin-password"
  jsonWebToken: "your-jwt-secret"
```

## Documentation

📖 **Complete Guide**: **[docs/QWC2_COMPLETE_GUIDE.md](docs/QWC2_COMPLETE_GUIDE.md)** - Full technical documentation

| Document | Description |
| ---------- | ------------- |
| **[QWC2_COMPLETE_GUIDE.md](docs/QWC2_COMPLETE_GUIDE.md)** | 📚 Complete technical documentation |
| **[QUICK_START.md](docs/QUICK_START.md)** | Fast installation and demo setup |
| **[TESTING_AND_ACCESS.md](docs/TESTING_AND_ACCESS.md)** | Testing and accessing the application |
| **[ADMIN_GUI_CREDENTIALS.md](docs/ADMIN_GUI_CREDENTIALS.md)** | User and credential management |
| **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** | System architecture details |
| **[SERVICES_AND_ENDPOINTS.md](docs/SERVICES_AND_ENDPOINTS.md)** | All services and API endpoints |
| **[VOLUMES.md](docs/VOLUMES.md)** | Volume configuration |

## Access URLs

| Service | URL |
|---------|-----|
| Map Viewer | <https://myhostname.com/> |
| Admin GUI | <https://myhostname.com/admin/> |
| WMS Demo | <https://myhostname.com/ows/demo?SERVICE=WMS&REQUEST=GetCapabilities> |

## Uninstall

```bash
helm uninstall my-qwc-instance -n qwc-dev
kubectl delete pvc --all -n qwc-dev  # Optional: remove data
```

## License

See LICENSE file.
