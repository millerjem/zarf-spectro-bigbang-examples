{{- define "oscal-kyverno-operator.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "oscal-kyverno-operator.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "oscal-kyverno-operator.name" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "oscal-kyverno-operator.labels" -}}
app.kubernetes.io/name: {{ include "oscal-kyverno-operator.name" . | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
zta.spectrocloud.com/pillar: "governance"
{{- end -}}
