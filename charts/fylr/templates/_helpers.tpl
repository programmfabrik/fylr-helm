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

{{- define "fylr.webapp.labels" -}}
{{ include "fylr.labels" . }}
app.kubernetes.io/component: webapp
{{- end }}

{{- define "fylr.api.labels" -}}
{{ include "fylr.labels" . }}
app.kubernetes.io/component: api
{{- end }}

{{- define "fylr.backend.labels" -}}
{{ include "fylr.labels" . }}
app.kubernetes.io/component: backend
{{- end }}

{{/*
Selector labels
*/}}
{{- define "fylr.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fylr.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
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

{{- define "fylr.secret.storage.name" -}}
{{- printf "%s-%s" (include "fylr.fullname" .) "storage" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "fylr.secret.init.name" -}}
{{- printf "%s-%s" (include "fylr.fullname" .) "init" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "fylr.secret.utils" -}}
{{- printf "%s-%s" (include "fylr.fullname" .) "utils" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified metrics name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "fylr.monitoring.fullname" -}}
{{- printf "%s-%s" (include "fylr.fullname" .) "metrics" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* s3 default configuration */}}
{{- define "fylr.default_s3_config" -}}
system:
  config:
    location_defaults:
      originals: S3
      versions: S3
      backups: S3
{{- end }}

{{/* define the storage volume name for local asset storage */}}
{{- define "fylr.storage.volumes.asset.name" -}}
{{- printf "%s-%s" (include "fylr.fullname" .) "disk-1" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "fylr.storage.volumes.version.name" -}}
{{- printf "%s-%s" (include "fylr.fullname" .) "disk-2" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "fylr.storage.volumes.backup.name" -}}
{{- printf "%s-%s" (include "fylr.fullname" .) "disk-3" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* define the storage volume name for tmp configuration */}}
{{- define "fylr.storage.volumes.tmp.name" -}}
{{- printf "%s-%s" (include "fylr.fullname" .) "tmp" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* define the storage volume name for webDAVHotfolder configuration */}}
{{- define "fylr.storage.volumes.webDAVHotfolder.name" -}}
{{- printf "%s-%s" (include "fylr.fullname" .) "webdav-hotfolder" | trunc 63 | trimSuffix "-" }}
{{- end }}



{{- define "fylr.deployment.volume.mounts" -}}
{{/* add persistent volume mounts */}}
{{ $persistent := .Values.fylr.persistent }}
{{- range $key, $val := $persistent.definitions -}}
{{- if eq $val.kind "disk" -}}
{{/* check whether the key matches any default rule, if so, we add a mount path to it */}}
{{- if or (eq $key $persistent.defaults.originals) (eq $key $persistent.defaults.versions) (eq $key $persistent.defaults.backups) -}}
{{/* check if key is defined as original */}}
{{- if eq $key $persistent.defaults.originals -}}
- name: "disk-one"
  mountPath: "/fylr/files/assets/originals"
  subPath: "originals"
{{/* end if is originals */}}
{{- end }}
{{/* check if key is defined as versions */}}
{{- if eq $key $persistent.defaults.versions -}}
{{- if eq $key $persistent.defaults.originals -}}
- name: "disk-one"
  mountPath: "/fylr/files/assets/versions"
  subPath: "versions"
{{- else }}
- name: "disk-two"
  mountPath: "/fylr/files/assets/versions"
  subPath: "versions"
{{/* end if key is originals as well */}}
{{- end }}
{{/* end if is versions */}}
{{- end }}
{{/* check if key is defined as backups */}}
{{- if eq $key $persistent.defaults.backups -}}
{{/* check if key is same as originals*/}}
{{- if eq $key $persistent.defaults.originals -}}
- name: "disk-one"
  mountPath: "/fylr/files/backups"
  subPath: "backups"
{{/* else if $key is not the same as defaults.originals */}}
{{- else -}}
{{- if and (eq $key $persistent.defaults.versions) (ne $key $persistent.defaults.originals) -}}
- name: "disk-two"
  mountPath: "/fylr/files/backups"
  subPath: "backups"
{{- else }}
{{/* key is not the same as defaults.originals and defaults.versions */}}
- name: "disk-three"
  mountPath: "/fylr/files/backups"
  subPath: "backups"
{{/* end if key eq defaults.versions and ne defaults.originals */}}
{{- end }}
{{/* end if key is originals */}}
{{- end }}
{{/* end if key is backups */}}
{{- end }}
{{/* end if key is any of originals, versions, backups */}}
{{- end }}
{{/* end if is kind disk */}}
{{- end }}
{{/* end loop */}}
{{- end }}
{{/* end define */}}
{{- end -}}

{{/* volume to be added to the deployment of fylr */}}
{{- define "fylr.deployment.volumes" -}}
{{ $helmValues := . }}
{{ $persistent := .Values.fylr.persistent }}
{{- range $key, $val := $persistent.definitions -}}
{{- if eq $val.kind "disk" -}}
{{/* check whether the key matches any default rule, if so, we add a mount path to it */}}
{{- if or (eq $key $persistent.defaults.originals) (eq $key $persistent.defaults.versions) (eq $key $persistent.defaults.backups) -}}

{{/* check if key is defined as original */}}
{{- if eq $key $persistent.defaults.originals -}}
- name: "disk-one"
  persistentVolumeClaim:
    claimName: {{ include "fylr.storage.volumes.asset.name" $helmValues }}
{{/* end if is originals */}}
{{- end -}}

{{/* check if key is defined as versions */}}
{{- if and (eq $key $persistent.defaults.versions) (ne $key $persistent.defaults.originals) -}}
- name: "disk-two"
  persistentVolumeClaim:
    claimName: {{ include "fylr.storage.volumes.version.name" $helmValues }}
{{/* end if and is versions and not originals*/}}
{{- end -}}

{{/* check if key is defined as backups */}}
{{- if and (eq $key $persistent.defaults.backups) (ne $key $persistent.defaults.versions) (ne $key $persistent.defaults.originals) -}}
- name: "disk-three"
  persistentVolumeClaim:
    claimName: {{ include "fylr.storage.volumes.backup.name" $helmValues }}
{{/* end if and is versions and not originals*/}}
{{- end -}}

{{/* end if or originals, versions, backups */}}
{{- end -}}
{{/* end if kind is disk */}}
{{- end -}}
{{/* end loop */}}
{{- end -}}
{{/* end define */}}
{{- end -}}


{{- define "fylr.config.init.location.defaults" -}}
{{/* location defaults settings */}}
{{ $persistent := .Values.fylr.persistent }}
{{- range $key, $val := $persistent.definitions -}}
{{- if or (eq $key $persistent.defaults.originals) (eq $key $persistent.defaults.versions) (eq $key $persistent.defaults.backups) -}}
{{/* check if it is a disk */}}
{{- if eq $val.kind "disk" -}}
{{- if eq $key $persistent.defaults.originals -}}
originals: originals
{{/* end if for key is originals */}}
{{- end -}}
{{- if eq $key $persistent.defaults.versions -}}
versions: versions
{{/* end if for key is versions */}}
{{- end -}}
{{- if eq $key $persistent.defaults.backups -}}
backups: backups
{{/* end if for key is backups */}}
{{- end -}}
{{/* check if the defined config is kind s3*/}}
{{- else if eq $val.kind "s3" -}}
{{- range $defaultKey, $defaultValue := $persistent.defaults -}}
{{- if eq $key $defaultValue -}}
{{ $defaultKey }}: {{ $key }}
{{/* end if $key eq $defaultValue*/}}
{{- end -}}
{{/* end for $persistent.defaults */}}
{{- end -}}
{{- else -}}
{{/* fail if kind is not s3 or disk */}}
{{- fail "Invalid Persistent Storage Kind. Supported values are 's3' and 'disk'." -}}
{{/* end if is kind disk */}}
{{- end -}}
{{/* end if key is one of originals, versions, backups */}}
{{- end -}}
{{/* end range */}}
{{- end -}}
{{/* end define */}}
{{- end -}}
