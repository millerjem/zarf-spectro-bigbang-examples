{{- define "zta-workload-hardening.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "zta-workload-hardening.labels" -}}
app.kubernetes.io/name: {{ include "zta-workload-hardening.name" . | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
zta.spectrocloud.com/pillar: "applications-and-workloads"
{{- end -}}

{{- define "zta-workload-hardening.exclude" -}}
exclude:
  any:
    - resources:
        namespaces:
{{ toYaml .Values.policy.excludeNamespaces | indent 10 }}
{{- end -}}
