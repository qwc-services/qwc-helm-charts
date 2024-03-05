{{/*
Expand the name of the chart.
*/}}
{{- define "qwcMapViewer.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" | lower }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "qwcMapViewer.fullname" -}}
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
{{- define "qwcMapViewer.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" | lower }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "qwcMapViewer.labels" -}}
helm.sh/chart: {{ include "qwcMapViewer.chart" . }}
{{ include "qwcMapViewer.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "qwcMapViewer.selectorLabels" -}}
app.kubernetes.io/name: {{ include "qwcMapViewer.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Selector labels for config output volume
*/}}
{{- define "qwcMapViewer.configVolumeLabels" -}}
app.kubernetes.io/part-of: qwc
app.kubernetes.io/instance: {{ .Release.Name }}
volume-name: config
{{- end }}

{{/*
Claim name for config output volume
*/}}
{{- define "qwcMapViewer.configVolumeClaim" -}}
{{- printf "%s-%s-claim" (include "qwcMapViewer.fullname" .) "config" }}
{{- end }}

{{/*
Selector labels for qwc application volume
*/}}
{{- define "qwcMapViewer.qwcAppVolumeLabels" -}}
app.kubernetes.io/part-of: qwc
app.kubernetes.io/instance: {{ .Release.Name }}
volume-name: qwc-app
{{- end }}

{{/*
Claim name for project resource volume
*/}}
{{- define "qwcMapViewer.qwcAppVolumeClaim" -}}
{{- printf "%s-%s-claim" (include "qwcMapViewer.fullname" .) "qwc-app" }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "qwcMapViewer.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "qwcMapViewer.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the secret for pg_service.conf
*/}}
{{- define "qwcMapViewer.secrets" -}}
{{- printf "%s-secret" (include "qwcMapViewer.fullname" .) }}
{{- end }}
