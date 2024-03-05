{{/*
Expand the name of the chart.
*/}}
{{- define "qwcDataService.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" | lower }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "qwcDataService.fullname" -}}
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
{{- define "qwcDataService.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" | lower }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "qwcDataService.labels" -}}
helm.sh/chart: {{ include "qwcDataService.chart" . }}
{{ include "qwcDataService.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "qwcDataService.selectorLabels" -}}
app.kubernetes.io/name: {{ include "qwcDataService.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Selector labels for config output volume
*/}}
{{- define "qwcDataService.configVolumeLabels" -}}
app.kubernetes.io/part-of: qwc
app.kubernetes.io/instance: {{ .Release.Name }}
volume-name: config
{{- end }}

{{/*
Claim name for config output volume
*/}}
{{- define "qwcDataService.configVolumeClaim" -}}
{{- printf "%s-%s-claim" (include "qwcDataService.fullname" .) "config" }}
{{- end }}

{{/*
Selector labels for attachment volume
*/}}
{{- define "qwcDataService.attachmentVolumeLabels" -}}
app.kubernetes.io/part-of: qwc
app.kubernetes.io/instance: {{ .Release.Name }}
volume-name: attachment
{{- end }}

{{/*
Claim name for attachment volume
*/}}
{{- define "qwcDataService.attachmentVolumeClaim" -}}
{{- printf "%s-%s-claim" (include "qwcDataService.fullname" .) "attachment" }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "qwcDataService.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "qwcDataService.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the secret for pg_service.conf
*/}}
{{- define "qwcDataService.secrets" -}}
{{- printf "%s-secret" (include "qwcDataService.fullname" .) }}
{{- end }}
