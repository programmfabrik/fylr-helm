{{/*
Expand the name of the chart.
*/}}
{{- define "fylr.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "fylr.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "fylr.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "fylr.labels" -}}
helm.sh/chart: {{ include "fylr.chart" . }}
{{ include "fylr.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "fylr.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fylr.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: server
app.kubernetes.io/part-of: fylr-server
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "fylr.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "fylr.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Service names
*/}}
{{- define "fylr.service-webapp-name" -}}
{{- printf "%s-%s" (include "fylr.fullname" .) "webapp" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "fylr.service-api-name" -}}
{{- printf "%s-%s" (include "fylr.fullname" .) "api" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "fylr.service-backend-name" -}}
{{- printf "%s-%s" (include "fylr.fullname" .) "backend" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Secret names
*/}}
{{- define "fylr.secret.db.name" -}}
{{- printf "%s-%s" (include "fylr.fullname" .) "db" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "fylr.secret.elastic.name" -}}
{{- printf "%s-%s" (include "fylr.fullname" .) "elastic" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "fylr.secret.s3.name" -}}
{{- printf "%s-%s" (include "fylr.fullname" .) "s3" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "fylr.secret.oauth2.name" -}}
{{- printf "%s-%s" (include "fylr.fullname" .) "oauth2" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "fylr.secret.utils" -}}
{{- printf "%s-%s" (include "fylr.fullname" .) "utils" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* s3 default configuration */}}
{{- define "fylr.default_s3_config" -}}
system:
  config:
    location_defaults:
      originals: S3
      versions: S3
      backups: S3
{{- end }}