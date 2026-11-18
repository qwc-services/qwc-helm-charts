# QWC Helm Chart

A Helm chart for deploying QWC2 (QGIS Web Client 2) on Kubernetes.

**QWC2 (QGIS Web Client 2)** is a modern, modular web mapping application built on top of QGIS Server. It provides a responsive, feature-rich web interface for viewing and interacting with geospatial data served through OGC-compliant services (WMS, WFS, WCS, WMTS).

## Quick Start

For complete installation instructions, see **[docs/QUICK_START.md](docs/QUICK_START.md)**.

---

## Features

- **Map Viewer** - Interactive web map client (QWC2)
- **Admin GUI** - User and permission management
- **OGC Services** - WMS, WFS via QGIS Server
- **Authentication** - JWT-based authentication
- **Data Service** - REST API for feature data
- **Permalink Service** - Shareable map links

## Sub charts

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

## Documentation

| Document | Description |
| ---------- | ------------- |
| **[QUICK_START.md](docs/QUICK_START.md)** | Fast installation and demo setup |
| **[QWC2_COMPLETE_GUIDE.md](docs/QWC2_COMPLETE_GUIDE.md)** | 📚 Complete technical documentation |
| **[ADMIN_GUI_CREDENTIALS.md](docs/ADMIN_GUI_CREDENTIALS.md)** | User and credential management |
| **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** | System architecture details |
| **[SERVICES_AND_ENDPOINTS.md](docs/SERVICES_AND_ENDPOINTS.md)** | All services and API endpoints |
| **[VOLUMES.md](docs/VOLUMES.md)** | Volume configuration |

## License

See [LICENSE](LICENSE) file.
