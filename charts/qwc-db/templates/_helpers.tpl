{{/*
Expand the name of the chart.
*/}}
{{- define "qwcDb.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" | lower }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "qwcDb.fullname" -}}
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
{{- define "qwcDb.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" | lower }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "qwcDb.labels" -}}
helm.sh/chart: {{ include "qwcDb.chart" . }}
{{ include "qwcDb.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "qwcDb.selectorLabels" -}}
app.kubernetes.io/name: {{ include "qwcDb.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Claim name for pgData volume
*/}}
{{- define "qwcDb.pgDataVolumeClaim" -}}
{{- if .Values.claimOverrides.pgData }}
{{- .Values.claimOverrides.pgData }}
{{- else if .Values.global.persistence.db.claimOverride }}
{{- .Values.global.persistence.db.claimOverride }}
{{- else }}
{{- printf "%s-%s-claim" .Release.Name "pg" }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "qwcDb.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "qwcDb.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the secret for pg_service.conf
*/}}
{{- define "qwcDb.secrets" -}}
{{- printf "%s-secret" (include "qwcDb.fullname" .) }}
{{- end }}
