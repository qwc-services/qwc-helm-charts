# QWC2 Quick Start Guide

This guide will get you up and running with QWC2 in minutes.

## Prerequisites

- Kubernetes cluster with `kubectl` configured
- Helm 3.x installed
- Gateway API configured (for external access)

## Installation

### Clone the Repository

```bash
git clone <repository-url>
cd qwc-helm-main
```

### Configure Values

Copy and customize the values file:

```bash
cp values.yaml values-override.yaml
```

Edit `values-override.yaml` to configure:

- **Namespace** and **release name**
- **Database passwords**
- **Hostnames** for external access

### Deploy with Helm

```bash
# Create namespace and install
helm upgrade --install my-qwc-instance . \
  -n qwc-dev \
  -f ./values-override.yaml \
  --create-namespace
```

### Initialize Demo Data

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

### Access the Application

| Service | URL |
|---------|-----|
| **Map Viewer** | <https://myhostname.com/> |
| **Admin GUI** | <https://myhostname.com/admin/> |
| **WMS Service** | <https://myhostname.com/ows/demo?SERVICE=WMS&REQUEST=GetCapabilities> |

## Demo Credentials

| User | Password | Role |
| ------ | ---------- | ------ |
| `admin` | `demo` | Administrator |
| `demo` | `demo` | Regular user |

⚠️ **Important:** Change these passwords in production!

## What's Included in the Demo

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

### Map Viewer shows blank map

- Wait 30 seconds for services to stabilize
- Refresh the page (Ctrl+F5)
- Check if layers are visible in the layer panel

### Cannot access the application

```bash
# Check pod status
kubectl get pods -n qwc-dev

# Check logs
kubectl logs -n qwc-dev -l app.kubernetes.io/name=qwcmapviewer
```

### Demo data not visible

Re-run the initialization script:

```bash
./scripts/init-demo-data.sh
```

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
