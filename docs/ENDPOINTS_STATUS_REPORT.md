# Endpoints Status Report

> Report based on live testing via `scripts/test-services.sh`
> Date: 2025-12-15

## Executive Summary

All **9 services** are deployed, running, and reachable within the cluster. Health checks and functional endpoint tests passed for all services. The platform is fully operational.

## Status Matrix

| Service | Status | Port | Health Endpoint | Functional Endpoint | Observation |
| --------- | -------- | ------ | ----------------- | --------------------- | ------------- |
| **qwc-db** | 🟢 PASSED | 5432 | TCP Connect | N/A | Connection successful. |
| **qwc-qgis-server** | � PASSED | 1080 | `/` (200 OK) | `GetCapabilities` (200 OK) | Server is correctly serving OGC Capabilities. |
| **qwc-config-service** | 🟢 PASSED | 9090 | `/maps` (200 OK) | `/maps` (200 OK) | Service is answering core requests. |
| **qwc-map-viewer** | 🟢 PASSED | 9090 | `/healthz` (200 OK) | `/` (200 OK) | Frontend is serving assets. |
| **qwc-ogc-service** | 🟢 PASSED | 9090 | `/healthz` (200 OK) | `/ows/` (200 OK) | Proxy is working correctly. |
| **qwc-data-service** | 🟢 PASSED | 9090 | `/healthz` (200 OK) | `/ready` (200 OK) | API is ready. |
| **qwc-auth-service** | 🟢 PASSED | 9090 | `/healthz` (200 OK) | `/auth/login` (200 OK) | Authentication endpoints are responsive. |
| **qwc-admin-gui** | 🟢 PASSED | 9090 | `/` (302 Found) | `/` (302 Found) | Redirects to login page as expected. |
| **qwc-permalink-service** | 🟢 PASSED | 9090 | `/healthz` (200 OK) | `/ready` (200 OK) | Service is ready. |

---

## Service Verification Details

### 1. ✅ QGIS Server (WMS/WFS)

The QGIS Server is successfully loading project files and responding to OGC WMS GetCapabilities requests.

- **Request**: `/ows/?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities&MAP=/data/demo.qgs`
- **Response**: `HTTP 200 OK`

### 2. ✅ OGC Service Proxy

The OGC Service (frontend proxy for QGIS Server) is healthy and routing traffic correctly.

- **Request**: `/ows/`
- **Response**: `HTTP 200 OK`

### 3. ✅ Admin GUI

Returns `HTTP 302`.

- **Observation**: Correct behavior for unauthenticated access (redirection to login).

### 4. ✅ Auth Service

Returns `HTTP 200` on `/auth/login`.

- **Observation**: Authentication service is potentially ready to accept login requests.
