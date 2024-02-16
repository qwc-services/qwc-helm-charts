{{/*
Expand the name of the chart.
*/}}
{{- define "qwcAdminUI.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" | lower }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "qwcAdminUI.fullname" -}}
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
{{- define "qwcAdminUI.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" | lower }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "qwcAdminUI.labels" -}}
helm.sh/chart: {{ include "qwcAdminUI.chart" . }}
{{ include "qwcAdminUI.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "qwcAdminUI.selectorLabels" -}}
app.kubernetes.io/name: {{ include "qwcAdminUI.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Selector labels for project resource volume
*/}}
{{- define "qwcAdminUI.projectResourceVolumeLabels" -}}
app.kubernetes.io/part-of: qwc
app.kubernetes.io/instance: {{ .Release.Name }}
volume-name: qgis-proj-res
{{- end }}

{{/*
Claim name for project resource volume
*/}}
{{- define "qwcAdminUI.projectResourceVolumeClaim" -}}
{{- printf "%s-%s-claim" (include "qwcAdminUI.fullname" .) "qgis-proj-res" }}
{{- end }}

{{/*
Selector labels for config input volume
*/}}
{{- define "qwcAdminUI.configInputVolumeLabels" -}}
app.kubernetes.io/part-of: qwc
app.kubernetes.io/instance: {{ .Release.Name }}
volume-name: config-input
{{- end }}

{{/*
Claim name for project resource volume
*/}}
{{- define "qwcAdminUI.configInputVolumeClaim" -}}
{{- printf "%s-%s-claim" (include "qwcAdminUI.fullname" .) "config-input" }}
{{- end }}

{{/*
Selector labels for config output volume
*/}}
{{- define "qwcAdminUI.configVolumeLabels" -}}
app.kubernetes.io/part-of: qwc
app.kubernetes.io/instance: {{ .Release.Name }}
volume-name: config
{{- end }}

{{/*
Claim name for project resource volume
*/}}
{{- define "qwcAdminUI.configVolumeClaim" -}}
{{- printf "%s-%s-claim" (include "qwcAdminUI.fullname" .) "config" }}
{{- end }}

{{/*
Selector labels for qwc application volume
*/}}
{{- define "qwcAdminUI.qwcAppVolumeLabels" -}}
app.kubernetes.io/part-of: qwc
app.kubernetes.io/instance: {{ .Release.Name }}
volume-name: qwc-app
{{- end }}

{{/*
Claim name for project resource volume
*/}}
{{- define "qwcAdminUI.qwcAppVolumeClaim" -}}
{{- printf "%s-%s-claim" (include "qwcAdminUI.fullname" .) "qwc-app" }}
{{- end }}

{{/*
Selector labels for qwc application volume
*/}}
{{- define "qwcAdminUI.infoTemplateVolumeLabels" -}}
app.kubernetes.io/part-of: qwc
app.kubernetes.io/instance: {{ .Release.Name }}
volume-name: info-tpl
{{- end }}

{{/*
Claim name for project resource volume
*/}}
{{- define "qwcAdminUI.infoTemplateVolumeClaim" -}}
{{- printf "%s-%s-claim" (include "qwcAdminUI.fullname" .) "info-tpl" }}
{{- end }}
{{/*
Create the name of the service account to use
*/}}
{{- define "qwcAdminUI.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "qwcAdminUI.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the secret for pg_service.conf
*/}}
{{- define "qwcAdminUI.secrets" -}}
{{- printf "%s-secret" (include "qwcAdminUI.fullname" .) }}
{{- end }}
