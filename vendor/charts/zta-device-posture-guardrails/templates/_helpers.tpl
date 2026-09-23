{{- define "zta-device-posture-guardrails.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "zta-device-posture-guardrails.labels" -}}
app.kubernetes.io/name: {{ include "zta-device-posture-guardrails.name" . | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
zta.spectrocloud.com/pillar: "devices"
{{- end -}}
