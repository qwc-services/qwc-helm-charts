# Changelog

All notable changes to this chart and subcharts will be documented in this file.

## **3.2.0** - 2026-11-20

### Added

- *Auth*:
  - Add extra env var support

### Documentation

- *no scope*:
  - Add LICENSE file

### Fixed

- *Qgis-server*:
  - Correct bad template for envExtraSecret

- *Qwc-db*:
  - Improve db password storage
    **BREAKING**
  - Change chart appVersion to latest qwc-base-db tag. See README
    **BREAKING**: umbrella chart MUST fix it DB tag. See README.md

- *Script*:
  - Catch curl error instead of just returning 000
  - Use regexp to change project name
  - Improve catch curl error

- *no scope*:
  - Add annotation to PVC to tell Helm we do not want PV to be deleted

### Ci

- *no scope*:
  - Add chart build
  - Add github jobs
  - Remove sast job as already defined in GitHub settings
  - Remove bad version flag
  - Fix package path to cleanup
  - Fix cleanup by selecting the version to delete
  - Add tgz releases

## **3.1.0** - 2026-08-31

### Added

- Split auth service in 2: old db and new oidc

### Fixed

- Improve log format in common.sh
- Remove useless secret functions from helper
- Improve test-services.sh and try to fix test-qwc.sh
- Test failed when endpoint failed
- FsGroup field does not exist anymore
- Wrong usage of tpl function

## **3.0.1** - 2026-06-22

bump to tag latest-2026-lts and chart 3.0.1

## **3.0.0** - 2026-06-05

### Added

- Create gateway to access app with local minikube
- Get assets from upstream stock app
- First customization for Nadara
- Make db creation optional
- Add Helm chart version in assets/help.html file

### Documentation

- Harmonize documentation about volumes
- Explain the usage of volumePath
- Fix tables
- Remove numbered headings
- Review doc and cleanup

### Fixed

- Move from configmap file file content to configmap that load file content
- Move global.env.serviceUID etc block from subchart to main values.yaml as one is enough
- Clean up volumes and claims to work with any storageClassName
- Format values files
- Create value files for local and aks cluster
- Postgresql paths in db chart
- Move configuration files into the subchart
- Use plural info-templates everywhere
- Move/rename bootstrap files
- Small changes
- Replace bad conditional by eq
- Remove unused config services and fix some parameters
- Get config.json from upstream qwc stock app
- Remove default aks values for gateway in sub charts
- Rework scripts to improve config change detection
- Update probes: increases the delays so that the probes are called less often and use /healthz and /ready
- Remove rsync and inotify as useless
- Add bootstrap assets
- Typo in bootstrap script
- Do not create gateway in aks
- Add colorschemes link in bootstrap index
- Move info-template pvc in main template folder
- Move config output pvc in main template folder
- Move config input pvc in main template folder
- Move project resource pvc in main template folder
- Move qwcApp pvc in main template folder
- Move db pvc in main template folder
- Move attachment pvc in main template folder
- Rename and harmonize qgis resources volume
- Rename and harmonize info templates volume
- Rename and harmonize attachments volume
- Rename and harmonize qwcApp volume
- Harmonize pgData volume
- Rename and harmonize configOutput volume
- Harmonize configInput volume
- Get more generic configuration from QWC upstream
- Do not create claim or volume when qwcDb chart is disabled
- Add checks in parse_inplace
- Config map used a wrong name and can be retrieved
- Improve log in configmap_to_files
- Avoid to call parse_inplace on root $INPUT_CONFIG_PATH in entrypoint.sh
- Do not create claim or volume when qwcDb chart is disabled (bis)
- Make "values.httproute.enable" mandatory
- Set default value for qgisserver httproute to /ogc/
- Add log when watchdog file is not present
- Add bootstrap configuration samples in values.yaml and rename bootstrap configuration variables
- Add uwsgi queue size parameter
- Make env var serviceUID and serviceGID global with default values
- Make env var jwtSecret global with default values
- Make env var jwtCookieCSRFProtect global with default values
- Make uwsgi env var global with default values
- Add extra env var support in deployment
- Ensure generate_config is called even if bootstap has been called
- Use same options than test-qwc.sh
- Move envExtra and envExtraSecret at the end of env var declaration
- Add support for default QGIS_OPTIONS_PATH volume management
- Migrate from "python" to "uv run"

### Config

- Remove disabled print service

## **2.0.0** - 2025-12-19

- Main chart version updated from `1.2.0` to `2.0.0`

### Removed Components

- **qwc-api-gateway**: Complete removal of the API Gateway subchart - using cluster-level Envoy Gateway instead
- **Ingress resources**: All Ingress templates replaced with HTTPRoute (Gateway API)
- **Code cleanup and simplification**: Removed unused resources (HPA, ServiceAccount templates, test-connection templates, local-storage template)

### Networking Changes

- **Migrated from Ingress to HTTPRoute**: All services now use Gateway API HTTPRoute instead of Kubernetes Ingress
- **Custom hostname support**: HTTPRoute templates support custom hostnames via `global.hostnames` (shared across all services) or service-specific `httpRoute.hostnames` per-service configuration
- **Centralized Gateway configuration**: Gateway reference configurable via `global.gateway` with service-specific fallback to `httpRoute.gateway` settings
- **Configurable path matching**: Custom path rules configurable via `httpRoute.paths` array in each service's values

### Storage & Volumes

- **Fixed `createVolumes` functionality**: Previously non-functional, now properly working with `global.createVolumes` flag for centralized control
- **Customizable storage size**: Added configurable storage size parameters (e.g., `configInputSize`, `configOutputSize`, `qwcAppSize`) instead of hardcoded 10Gi
- **Customizable storage classes**: Added `storageClassName` configuration option, removed hardcoded `local-storage`
- **Simplified volume paths**: Replaced complex `volumePaths` array with direct path references in service-specific values
- **Updated PVC templates**: Modified all PersistentVolumeClaim templates to support new storage configuration structure

### Template Improvements

- **Fixed release name references in `_helpers.tpl`**: Updated template helpers to use `.Release.Name` instead of `qwc.fullname` for shared resources (global secrets, database hostname, shared volume claims) to ensure correct resource naming across subcharts
- **Enhanced deployment templates**: Improved configurability and consistency across all services

### Configuration Management

- **values.yaml refactoring**: Major improvements to configuration structure and organization

## How to

Replace `MY_PREV_TAG` and run: `docker run -t -v "$(pwd)":/app/ "ghcr.io/orhun/git-cliff/git-cliff:latest" --unreleased --prepend CHANGELOG.md -- MY_PREV_TAG..HEAD`
