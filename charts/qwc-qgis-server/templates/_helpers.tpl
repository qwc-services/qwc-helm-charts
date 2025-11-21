{{/*
Expand the name of the chart.
*/}}
{{- define "qwcQgisServer.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" | lower }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "qwcQgisServer.fullname" -}}
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
{{- define "qwcQgisServer.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" | lower }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "qwcQgisServer.labels" -}}
helm.sh/chart: {{ include "qwcQgisServer.chart" . }}
{{ include "qwcQgisServer.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "qwcQgisServer.selectorLabels" -}}
app.kubernetes.io/name: {{ include "qwcQgisServer.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Claim name for qgis resources volume
*/}}
{{- define "qwcQgisServer.qgisResourcesVolumeClaim" -}}
{{- if .Values.claimOverrides.qgisResources }}
{{- .Values.claimOverrides.qgisResources }}
{{- else if .Values.global.persistence.qgisResources.claimOverride }}
{{- .Values.global.persistence.qgisResources.claimOverride }}
{{- else }}
{{- printf "%s-%s-claim" .Release.Name "qgis-resources" }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "qwcQgisServer.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "qwcQgisServer.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
