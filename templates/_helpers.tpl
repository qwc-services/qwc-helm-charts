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
Selector labels for project resource volume
*/}}
{{- define "qwc.projectResourceVolumeLabels" -}}
volume-name: qgis-project-resources
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
{{- define "qwc.configVolumeLabels" -}}
volume-name: config
{{- end }}

{{/*
Selector labels for qwc application volume
*/}}
{{- define "qwc.qwcAppVolumeLabels" -}}
volume-name: qwc-app
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
Create the name of the secret for pg_service.conf
*/}}
{{- define "qwc.pgServiceConfSecret" -}}
{{- printf "%s-secret-pg-service" (include "qwc.fullname" .) }}
{{- end }}
