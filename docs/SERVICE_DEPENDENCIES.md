# Service Dependencies Analysis

> Generated from `manifest.yaml` analysis
> Date: 2025-12-11

## Overview

This document describes which QWC services are referenced by other services and the URLs used for communication (internal to the Kubernetes cluster or optionally external via Ingress/Gateway).

---

## 1. Services Referenced by Other Services

Services are referenced through environment variables defined in the Deployments. The main service orchestrating connections is **qwc-services-qwcconfigservice** (Config Generator).

### Default Behavior (Internal Communication)

By default, all services communicate using **internal Kubernetes service names**:

| Environment Variable | Service Name | Full URL |
|---|---|---|
| `QGIS_SERVER_HOST` | `<release>-qwcqgisserver` | `http://<release>-qwcqgisserver/ows/` |
| `QWC_AUTH_HOST` | `<release>-qwcauthservice` | `http://<release>-qwcauthservice/auth/` |
| `QWC_CONFIG_HOST` | `<release>-qwcconfigservice` | `http://<release>-qwcconfigservice/` |
| `QWC_DATA_HOST` | `<release>-qwcdataservice` | `http://<release>-qwcdataservice/api/v1/data/` |
| `QWC_OGC_HOST` | `<release>-qwcogcservice` | `http://<release>-qwcogcservice/ows/` |
| `QWC_PERMALINK_HOST` | `<release>-qwcpermalinkservice` | `http://<release>-qwcpermalinkservice/api/v1/permalink/` |

### External Gateway Mode (Optional)

When `apiGatewayHostname` is configured in `qwcConfigService`, services will communicate via the external gateway:

```yaml
qwcConfigService:
  apiGatewayHostname: "qwc.example.com"  # Set to use external gateway
```

This routes traffic through the Ingress/Gateway for:

- Centralized authentication
- Load balancing
- TLS termination
- Centralized logging and monitoring

### PostgreSQL Database

The database `<release>-qwcdb` is referenced by init containers in various services to verify availability before startup:

```bash
until nc -z <release>-qwcdb 5432 >/dev/null 2>&1; do echo waiting for qwcDb; sleep 2; done
```

---

## 2. URL Details by Type

### 🔒 Internal URLs (Intra-Cluster Kubernetes Communication)

These URLs use Kubernetes Service names for direct communication between pods within the cluster.

| Service | Full URL | Description |
|---|---|---|
| QGIS Server | `http://<release>-qwcqgisserver/ows/` | QGIS Server for WMS/WFS |
| Config Service | `http://<release>-qwcconfigservice/` | Configuration generator |
| Auth Service | `http://<release>-qwcauthservice/auth/` | Authentication |
| Data Service | `http://<release>-qwcdataservice/api/v1/data/` | Data API |
| OGC Service | `http://<release>-qwcogcservice/ows/` | OGC services (WMS/WFS) |
| Permalink Service | `http://<release>-qwcpermalinkservice/api/v1/permalink/` | Permalink management |
| Solr (Search) | `http://qwc-solr:8983/solr/gdi/select` | Search engine |
| PostgreSQL DB | `<release>-qwcdb:5432` | Database |

---

## 3. Dependencies Diagram

```raw
┌─────────────────────────────────────────────────────────────────────────┐
│                     <release>-qwcconfigservice                          │
│                    (Config Generator - Main Service)                    │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
              References these services (ALL INTERNAL by default):
                                    │
    ┌───────────────────────────────┼───────────────────────────────┐
    │                               │                               │
    ▼                               ▼                               ▼
┌──────────────────┐      ┌──────────────────┐      ┌──────────────────────────┐
│   QGIS Server    │      │   PostgreSQL     │      │   Other QWC Services     │
│    (INTERNAL)    │      │    (INTERNAL)    │      │      (INTERNAL)          │
└──────────────────┘      └──────────────────┘      └──────────────────────────┘
         │                         │                            │
         │                         │                 ┌──────────┴──────────┐
         ▼                         ▼                 │                     │
<release>-qwc           <release>-qwcdb         ┌────▼────┐          ┌─────▼─────┐
qgisserver/ows/              :5432              │  Auth   │          │   Data    │
                                                │ Service │          │  Service  │
                                                └─────────┘          └───────────┘
                                                /auth/               /api/v1/data/
                                                     │
                                            ┌────────┴────────┐
                                            │                 │
                                       ┌────▼────┐      ┌─────▼─────┐
                                       │   OGC   │      │ Permalink │
                                       │ Service │      │  Service  │
                                       └─────────┘      └───────────┘
                                        /ows/           /api/v1/permalink/
```

---

## 4. Configuration in `tenantConfig.json`

Service references are defined in the ConfigMap and use mustache syntax `{{VAR}}` for variable substitution:

```json
{
  "name": "mapViewer",
  "config": {
    "auth_service_url": "http://{{QWC_AUTH_HOST}}/auth/",
    "data_service_url": "http://{{QWC_DATA_HOST}}/api/v1/data/",
    "ogc_service_url": "http://{{QWC_OGC_HOST}}/ows/",
    "permalink_service_url": "http://{{QWC_PERMALINK_HOST}}/api/v1/permalink/"
  }
}
```

---

## 5. Configuration Options

### Option A: Internal Communication (Default - Recommended)

No configuration needed. Services use internal Kubernetes service names:

```yaml
qwcConfigService:
  # apiGatewayHostname not set or empty
```

### Option B: External Gateway

Set `apiGatewayHostname` to route through an external Ingress/Gateway:

```yaml
qwcConfigService:
  apiGatewayHostname: "qwc.example.com"
```

This is useful when:

- You need centralized authentication at the gateway level
- You want TLS termination at the gateway
- You need to expose services externally

---

## 6. Complete Service List

| Service Name | Type | Port |
|---|---|---|
| `<release>-qwcadmingui` | Deployment | 9090 |
| `<release>-qwcauthservice` | Deployment | 9090 |
| `<release>-qwcconfigservice` | Deployment | 9090 |
| `<release>-qwcdataservice` | Deployment | 9090 |
| `<release>-qwcmapviewer` | Deployment | 9090 |
| `<release>-qwcogcservice` | Deployment | 9090 |
| `<release>-qwcpermalinkservice` | Deployment | 9090 |
| `<release>-qwcqgisserver` | Deployment | 80 |
| `<release>-qwcdb` | StatefulSet | 5432 |
