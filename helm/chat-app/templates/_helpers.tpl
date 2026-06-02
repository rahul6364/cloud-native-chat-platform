{{- define "chat-app.namespace" -}}
{{- .Values.namespace | default .Release.Namespace -}}
{{- end -}}

{{- define "chat-app.labels.frontend" -}}
app: frontend
{{- end -}}

{{- define "chat-app.labels.backend" -}}
app: backend
{{- end -}}

{{- define "chat-app.labels.mongodb" -}}
app: mongodb
{{- end -}}
