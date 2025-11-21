{{/*
Expand the name of the chart.
*/}}
{{- define "qwcConfigService.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" | lower }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "qwcConfigService.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" | lower }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" | lower }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" | lower }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "qwcConfigService.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" | lower }}
{{- end }}


{{/*
Bootstrap configMap name for entrypoint
*/}}
{{- define "qwcConfigService.bootstrapEntrypoint" -}}
{{- default (printf "%s-bootstrap-entrypoint" (include "qwcConfigService.fullname" .)) .Values.bootstrapEntrypoint }}
{{- end }}

{{/*
Bootstrap configMap name for common scripts
*/}}
{{- define "qwcConfigService.bootstrapCommonScripts" -}}
{{- default (printf "%s-bootstrap-common-scripts" .Release.Name) .Values.bootstrapCommonScripts }}
{{- end }}

{{/*
Bootstrap configMap name for config input
*/}}
{{- define "qwcConfigService.bootstrapConfigIn" -}}
{{- default (printf "%s-bootstrap-config-in" .Release.Name) .Values.bootstrapConfigIn }}
{{- end }}


{{/*
Common labels
*/}}
{{- define "qwcConfigService.labels" -}}
helm.sh/chart: {{ include "qwcConfigService.chart" . }}
{{ include "qwcConfigService.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "qwcConfigService.selectorLabels" -}}
app.kubernetes.io/name: {{ include "qwcConfigService.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Claim name for qgis resources volume
*/}}
{{- define "qwcConfigService.qgisResourcesVolumeClaim" -}}
{{- if .Values.claimOverrides.qgisResources }}
{{- .Values.claimOverrides.qgisResources }}
{{- else if .Values.global.persistence.qgisResources.claimOverride }}
{{- .Values.global.persistence.qgisResources.claimOverride }}
{{- else }}
{{- printf "%s-%s-claim" .Release.Name "qgis-resources" }}
{{- end }}
{{- end }}

{{/*
Claim name for config input volume
*/}}
{{- define "qwcConfigService.configInputVolumeClaim" -}}
{{- if .Values.claimOverrides.configInput }}
{{- .Values.claimOverrides.configInput }}
{{- else if .Values.global.persistence.configInput.claimOverride }}
{{- .Values.global.persistence.configInput.claimOverride }}
{{- else }}
{{- printf "%s-%s-claim" .Release.Name "config-input" }}
{{- end }}
{{- end }}

{{/*
Claim name for config output volume
*/}}
{{- define "qwcConfigService.configOutputVolumeClaim" -}}
{{- if .Values.claimOverrides.configOutput }}
{{- .Values.claimOverrides.configOutput }}
{{- else if .Values.global.persistence.configOutput.claimOverride }}
{{- .Values.global.persistence.configOutput.claimOverride }}
{{- else }}
{{- printf "%s-%s-claim" .Release.Name "config-output" }}
{{- end }}
{{- end }}

{{/*
Claim name for qwcApp volume
*/}}
{{- define "qwcConfigService.qwcAppVolumeClaim" -}}
{{- if .Values.claimOverrides.qwcApp }}
{{- .Values.claimOverrides.qwcApp }}
{{- else if .Values.global.persistence.qwcApp.claimOverride }}
{{- .Values.global.persistence.qwcApp.claimOverride }}
{{- else }}
{{- printf "%s-%s-claim" .Release.Name "qwc-app" }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "qwcConfigService.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "qwcConfigService.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the secret for pg_service.conf
*/}}
{{- define "qwcConfigService.secrets" -}}
{{- printf "%s-secret" (include "qwcConfigService.fullname" .) }}
{{- end }}
