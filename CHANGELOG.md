# Changelog

## Version Update

- Main chart version updated from `1.2.0` to `2.0.0`

## Removed Components

- **qwc-api-gateway**: Complete removal of the API Gateway subchart - using cluster-level Envoy Gateway instead
- **Ingress resources**: All Ingress templates replaced with HTTPRoute (Gateway API)
- **Code cleanup and simplification**: Removed unused resources (HPA, ServiceAccount templates, test-connection templates, local-storage template)

## Networking Changes

- **Migrated from Ingress to HTTPRoute**: All services now use Gateway API HTTPRoute instead of Kubernetes Ingress
- **Custom hostname support**: HTTPRoute templates support custom hostnames via `global.hostnames` (shared across all services) or service-specific `httpRoute.hostnames` per-service configuration
- **Centralized Gateway configuration**: Gateway reference configurable via `global.gateway` with service-specific fallback to `httpRoute.gateway` settings
- **Configurable path matching**: Custom path rules configurable via `httpRoute.paths` array in each service's values

## Storage & Volumes

- **Fixed `createVolumes` functionality**: Previously non-functional, now properly working with `global.createVolumes` flag for centralized control
- **Customizable storage size**: Added configurable storage size parameters (e.g., `configInputSize`, `configOutputSize`, `qwcAppSize`) instead of hardcoded 10Gi
- **Customizable storage classes**: Added `storageClassName` configuration option, removed hardcoded `local-storage`
- **Simplified volume paths**: Replaced complex `volumePaths` array with direct path references in service-specific values
- **Updated PVC templates**: Modified all PersistentVolumeClaim templates to support new storage configuration structure

## Template Improvements

- **Fixed release name references in `_helpers.tpl`**: Updated template helpers to use `.Release.Name` instead of `qwc.fullname` for shared resources (global secrets, database hostname, shared volume claims) to ensure correct resource naming across subcharts
- **Enhanced deployment templates**: Improved configurability and consistency across all services

## Configuration Management

- **values.yaml refactoring**: Major improvements to configuration structure and organization
