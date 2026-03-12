# QWC2 Quick Start Guide

This guide will get you up and running with QWC2 in minutes.

## Prerequisites

- Kubernetes cluster with `kubectl` configured
- Helm 3.x installed
- Gateway API configured (for external access)

## Installation

### Clone the Repository

```bash
git clone <repository-url> qwc-helm-main
cd qwc-helm-main
```

### Configure Values

Copy `values-aks.yaml.sample` (or `values-local.yaml.sample`) and customize the values file:

```bash
cp values-aks.yaml.sample values.yaml
```

Edit `values.yaml` to configure:

- `global` persistence
- `global` database passwords
- external accesses (`hostnames` and `gateway`)

### Deploy with Helm

```bash
# Create namespace and install
helm upgrade --install my-qwc-instance . \
  -n qwc-dev \
  -f ./values.yaml \
  --create-namespace
```

Wait for pods to be ready (few minutes): `kubectl wait --for=condition=Ready pods --all -n qwc-dev --timeout=300s`

### Access the Application

| Service | URL |
| --------- | ----- |
| **Map Viewer** | <https://myhostname.com/> |
| **Admin GUI** | <https://myhostname.com/admin/> |
| **WMS Service** | <https://myhostname.com/ows/demo?SERVICE=WMS&REQUEST=GetCapabilities> |

## Initialize Demo Data

Run the initialization script to set up demo users and sample data:

```bash
./scripts/init-demo-data.sh
```

The script will:

- Prompt for the Kubernetes namespace (default: `qwc-dev`)
- Create demo users (`admin/demo`, `demo/demo`)
- Create sample geospatial data (European cities, roads, regions)
- Deploy a demo QGIS project
- Configure the Map Viewer theme

### Demo Credentials

| User | Password | Role |
| ------ | ---------- | ------ |
| `admin` | `demo` | Administrator |
| `demo` | `demo` | Regular user |

⚠️ **Important:** Change these passwords in production!

### Demo Layers

- **European Cities** - 10 major European cities with population data
- **Roads** - Sample road connections between cities
- **Regions** - Buffer regions around Rome, Paris, and Berlin

### Demo Theme

The "Demo European Cities" theme is automatically configured and will be visible when you open the Map Viewer.

## Verification

After installation, verify everything is working:

```bash
# Check all pods are running
kubectl get pods -n qwc-dev

# Check WMS service
curl "https://myhostname.com/ows/demo?SERVICE=WMS&REQUEST=GetCapabilities"
```

## Troubleshooting

See [the architecture document](ARCHITECTURE.md#troubleshooting-guide) or [the complete guide](QWC2_COMPLETE_GUIDE.md#troubleshooting)

## Next Steps

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Understand the system architecture
- **[ADMIN_GUI_CREDENTIALS.md](ADMIN_GUI_CREDENTIALS.md)** - Manage users and permissions
- **[VOLUMES.md](VOLUMES.md)** - Configure persistent storage
- **[SERVICES_AND_ENDPOINTS.md](SERVICES_AND_ENDPOINTS.md)** - API reference

## Uninstall

```bash
# Remove the Helm release
helm uninstall my-qwc-instance -n qwc-dev

# Remove PVCs (optional - will delete all data)
kubectl delete pvc --all -n qwc-dev

# Remove namespace (optional)
kubectl delete namespace qwc-dev
```
