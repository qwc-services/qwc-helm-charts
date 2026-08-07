{{/*
Expand the name of the chart.
*/}}
{{- define "qwcAdminGUI.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" | lower }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "qwcAdminGUI.fullname" -}}
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
{{- define "qwcAdminGUI.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" | lower }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "qwcAdminGUI.labels" -}}
helm.sh/chart: {{ include "qwcAdminGUI.chart" . }}
{{ include "qwcAdminGUI.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "qwcAdminGUI.selectorLabels" -}}
app.kubernetes.io/name: {{ include "qwcAdminGUI.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Claim name for qgis resources volume
*/}}
{{- define "qwcAdminGUI.qgisResourcesVolumeClaim" -}}
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
{{- define "qwcAdminGUI.configInputVolumeClaim" -}}
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
{{- define "qwcAdminGUI.configOutputVolumeClaim" -}}
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
{{- define "qwcAdminGUI.qwcAppVolumeClaim" -}}
{{- if .Values.claimOverrides.qwcApp }}
{{- .Values.claimOverrides.qwcApp }}
{{- else if .Values.global.persistence.qwcApp.claimOverride }}
{{- .Values.global.persistence.qwcApp.claimOverride }}
{{- else }}
{{- printf "%s-%s-claim" .Release.Name "qwc-app" }}
{{- end }}
{{- end }}

{{/*
Claim name for info templates volume
*/}}
{{- define "qwcAdminGUI.infoTemplatesVolumeClaim" -}}
{{- if .Values.claimOverrides.infoTemplates }}
{{- .Values.claimOverrides.infoTemplates }}
{{- else if .Values.global.persistence.infoTemplates.claimOverride }}
{{- .Values.global.persistence.infoTemplates.claimOverride }}
{{- else }}
{{- printf "%s-%s-claim" .Release.Name "info-templates" }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "qwcAdminGUI.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "qwcAdminGUI.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
