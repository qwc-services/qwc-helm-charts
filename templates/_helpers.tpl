{{/*
Expand the name of the chart.
*/}}
{{- define "qwc.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" | lower }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "qwc.fullname" -}}
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
{{- define "qwc.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" | lower }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "qwc.labels" -}}
helm.sh/chart: {{ include "qwc.chart" . }}
{{ include "qwc.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "qwc.selectorLabels" -}}
app.kubernetes.io/name: {{ include "qwc.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "qwc.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "qwc.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the global secret for pg_service.conf and JWT
*/}}
{{- define "qwc.globalSecret" -}}
{{- printf "%s-global-secret" .Release.Name }}
{{- end }}

{{/*
=== SHARED RESOURCE NAMES ===
These helpers generate names for resources that are shared between subcharts.
They are based on the naming convention: <release>-<subchart>-<resource>-claim
*/}}

{{/*
Selector labels for qgis resources volume
*/}}
{{- define "qwc.qgisResourcesVolumeLabels" -}}
volume-name: qgis-qgis-resources
{{- end }}

{{/*
Selector labels for config input volume
*/}}
{{- define "qwc.configInputVolumeLabels" -}}
volume-name: config-input
{{- end }}

{{/*
Selector labels for config output volume
*/}}
{{- define "qwc.configOutputVolumeLabels" -}}
volume-name: config
{{- end }}

{{/*
Selector labels for qwc application volume
*/}}
{{- define "qwc.qwcAppVolumeLabels" -}}
volume-name: qwc-app
{{- end }}

{{/*
Selector labels for attachments volume
*/}}
{{- define "qwc.attachmentsVolumeLabels" -}}
volume-name: attachments
{{- end }}

{{/*
Selector labels for db volume
*/}}
{{- define "qwc.pgDataVolumeLabels" -}}
volume-name: pg-data
{{- end }}

{{/*
Selector labels for info templates volume
*/}}
{{- define "qwc.infoTemplatesVolumeLabels" -}}
volume-name: info-templates
{{- end }}

{{/*
Claim name for info templates volume
*/}}
{{- define "qwc.infoTemplatesVolumeClaim" -}}
{{- if .Values.global.persistence.infoTemplates.claimOverride }}
{{- .Values.global.persistence.infoTemplates.claimOverride }}
{{- else }}
{{- printf "%s-%s-claim" .Release.Name "info-templates" }}
{{- end }}
{{- end }}

{{/*
Claim name for config input volume
*/}}
{{- define "qwc.configInputVolumeClaim" -}}
{{- if .Values.global.persistence.configInput.claimOverride }}
{{- .Values.global.persistence.configInput.claimOverride }}
{{- else }}
{{- printf "%s-%s-claim" .Release.Name "config-input" }}
{{- end }}
{{- end }}

{{/*
Claim name for attachments volume
*/}}
{{- define "qwc.attachmentsVolumeClaim" -}}
{{- if .Values.global.persistence.attachments.claimOverride }}
{{- .Values.global.persistence.attachments.claimOverride }}
{{- else }}
{{- printf "%s-%s-claim" .Release.Name "attachments" }}
{{- end }}
{{- end }}

{{/*
Claim name for db volume
*/}}
{{- define "qwc.pgDataVolumeClaim" -}}
{{- if .Values.global.persistence.db.claimOverride }}
{{- .Values.global.persistence.db.claimOverride }}
{{- else }}
{{- printf "%s-%s-claim" .Release.Name "pg" }}
{{- end }}
{{- end }}

{{/*
Claim name for qwcApp volume
*/}}
{{- define "qwc.qwcAppVolumeClaim" -}}
{{- if .Values.global.persistence.qwcApp.claimOverride }}
{{- .Values.global.persistence.qwcApp.claimOverride }}
{{- else }}
{{- printf "%s-%s-claim" .Release.Name "qwc-app" }}
{{- end }}
{{- end }}

{{/*
Claim name for qgis resources volume
*/}}
{{- define "qwc.qgisResourcesVolumeClaim" -}}
{{- if .Values.global.persistence.qgisResources.claimOverride }}
{{- .Values.global.persistence.qgisResources.claimOverride }}
{{- else }}
{{- printf "%s-%s-claim" .Release.Name "qgis-resources" }}
{{- end }}
{{- end }}

{{/*
Claim name for config output volume
*/}}
{{- define "qwc.configOutputVolumeClaim" -}}
{{- if .Values.global.persistence.configOutput.claimOverride }}
{{- .Values.global.persistence.configOutput.claimOverride }}
{{- else }}
{{- printf "%s-%s-claim" .Release.Name "config-output" }}
{{- end }}
{{- end }}
