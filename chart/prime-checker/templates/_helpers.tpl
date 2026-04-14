{{- define "prime-checker.name" -}}
prime-checker
{{- end }}

{{- define "prime-checker.fullname" -}}
{{ .Release.Name }}-prime-checker
{{- end }}

{{- define "prime-checker.labels" -}}
app: {{ include "prime-checker.name" . }}
{{- end }}