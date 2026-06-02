{{- define "chat-app.namespace" -}}
{{- .Values.namespace | default .Release.Namespace -}}
{{- end -}}
