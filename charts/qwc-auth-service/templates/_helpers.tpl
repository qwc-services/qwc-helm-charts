{{/*
Expand the name of the chart.
*/}}
{{- define "qwcAuthService.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" | lower }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "qwcAuthService.fullname" -}}
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
{{- define "qwcAuthService.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" | lower }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "qwcAuthService.labels" -}}
helm.sh/chart: {{ include "qwcAuthService.chart" . }}
{{ include "qwcAuthService.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "qwcAuthService.selectorLabels" -}}
app.kubernetes.io/name: {{ include "qwcAuthService.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Claim name for config output volume
*/}}
{{- define "qwcAuthService.configOutputVolumeClaim" -}}
{{- if .Values.claimOverrides.configOutput }}
{{- .Values.claimOverrides.configOutput }}
{{- else if .Values.global.persistence.configOutput.claimOverride }}
{{- .Values.global.persistence.configOutput.claimOverride }}
{{- else }}
{{- printf "%s-%s-claim" .Release.Name "config-output" }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "qwcAuthService.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "qwcAuthService.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
