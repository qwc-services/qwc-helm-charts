{{/*
Expand the name of the chart.
*/}}
{{- define "qwcPermalinkService.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" | lower }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "qwcPermalinkService.fullname" -}}
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
{{- define "qwcPermalinkService.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" | lower }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "qwcPermalinkService.labels" -}}
helm.sh/chart: {{ include "qwcPermalinkService.chart" . }}
{{ include "qwcPermalinkService.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "qwcPermalinkService.selectorLabels" -}}
app.kubernetes.io/name: {{ include "qwcPermalinkService.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Selector labels for config output volume
*/}}
{{- define "qwcPermalinkService.configVolumeLabels" -}}
app.kubernetes.io/part-of: qwc
app.kubernetes.io/instance: {{ .Release.Name }}
volume-name: config
{{- end }}

{{/*
Claim name for config output volume
*/}}
{{- define "qwcPermalinkService.configVolumeClaim" -}}
{{- if .Values.claimOverrides.configVolumeClaim }}
{{- .Values.claimOverrides.configVolumeClaim }}
{{- else }}
{{- printf "%s-%s-claim" (include "qwcPermalinkService.fullname" .) "config" }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "qwcPermalinkService.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "qwcPermalinkService.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the secret for pg_service.conf
*/}}
{{- define "qwcPermalinkService.secrets" -}}
{{- printf "%s-secret" (include "qwcPermalinkService.fullname" .) }}
{{- end }}
