{{/*
Expand the name of the chart.
*/}}
{{- define "qwcOgcService.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" | lower }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "qwcOgcService.fullname" -}}
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
{{- define "qwcOgcService.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" | lower }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "qwcOgcService.labels" -}}
helm.sh/chart: {{ include "qwcOgcService.chart" . }}
{{ include "qwcOgcService.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "qwcOgcService.selectorLabels" -}}
app.kubernetes.io/name: {{ include "qwcOgcService.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Claim name for config output volume
*/}}
{{- define "qwcOgcService.configOutputVolumeClaim" -}}
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
{{- define "qwcOgcService.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "qwcOgcService.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
