{{- define "zta-data-protection-guardrails.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "zta-data-protection-guardrails.labels" -}}
app.kubernetes.io/name: {{ include "zta-data-protection-guardrails.name" . | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
zta.spectrocloud.com/pillar: "data"
{{- end -}}

{{- define "zta-data-protection-guardrails.exclude" -}}
exclude:
  any:
    - resources:
        namespaces:
{{ toYaml .Values.policy.excludeNamespaces | indent 10 }}
{{- end -}}
