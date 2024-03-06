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
Selector labels for project resource volume
*/}}
{{- define "qwcConfigService.projectResourceVolumeLabels" -}}
app.kubernetes.io/part-of: qwc
app.kubernetes.io/instance: {{ .Release.Name }}
volume-name: qgis-proj-res
{{- end }}

{{/*
Claim name for project resource volume
*/}}
{{- define "qwcConfigService.projectResourceVolumeClaim" -}}
{{- if .Values.claimOverrides.projectResourceVolumeClaim }}
{{- .Values.claimOverrides.projectResourceVolumeClaim }}
{{- else }}
{{- printf "%s-%s-claim" (include "qwcConfigService.fullname" .) "qgis-proj-res" }}
{{- end }}
{{- end }}

{{/*
Selector labels for config input volume
*/}}
{{- define "qwcConfigService.configInputVolumeLabels" -}}
app.kubernetes.io/part-of: qwc
app.kubernetes.io/instance: {{ .Release.Name }}
volume-name: config-input
{{- end }}

{{/*
Claim name for project resource volume
*/}}
{{- define "qwcConfigService.configInputVolumeClaim" -}}
{{- if .Values.claimOverrides.configInputVolumeClaim }}
{{- .Values.claimOverrides.configInputVolumeClaim }}
{{- else }}
{{- printf "%s-%s-claim" (include "qwcConfigService.fullname" .) "config-input" }}
{{- end }}
{{- end }}

{{/*
Selector labels for config output volume
*/}}
{{- define "qwcConfigService.configVolumeLabels" -}}
app.kubernetes.io/part-of: qwc
app.kubernetes.io/instance: {{ .Release.Name }}
volume-name: config
{{- end }}

{{/*
Claim name for project resource volume
*/}}
{{- define "qwcConfigService.configVolumeClaim" -}}
{{- if .Values.claimOverrides.configVolumeClaim }}
{{- .Values.claimOverrides.configVolumeClaim }}
{{- else }}
{{- printf "%s-%s-claim" (include "qwcConfigService.fullname" .) "config" }}
{{- end }}
{{- end }}

{{/*
Selector labels for qwc application volume
*/}}
{{- define "qwcConfigService.qwcAppVolumeLabels" -}}
app.kubernetes.io/part-of: qwc
app.kubernetes.io/instance: {{ .Release.Name }}
volume-name: qwc-app
{{- end }}

{{/*
Claim name for project resource volume
*/}}
{{- define "qwcConfigService.qwcAppVolumeClaim" -}}
{{- if .Values.claimOverrides.qwcAppVolumeClaim }}
{{- .Values.claimOverrides.qwcAppVolumeClaim }}
{{- else }}
{{- printf "%s-%s-claim" (include "qwcConfigService.fullname" .) "qwc-app" }}
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
