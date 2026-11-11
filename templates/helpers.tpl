{{/*
The namespace
*/}}
{{- define "mongodb.namespace" }}
{{- if or .Values.namespace .Values.createNamespace }}
{{- .Values.namespace | trim }}
{{- else }}
{{- .Release.Namespace | trim | quote }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "mongodb.chart" }}
{{- printf "%s" .Chart.Name | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the name of the chart.
*/}}
{{- define "mongodb.name" }}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end -}}
