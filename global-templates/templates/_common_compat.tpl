{{/*
Compatibility helpers replacing minimal subset of bitnami/common functions used in templates
Now that the common dependency is removed, we must supply equivalents for:
- common.labels.standard
- common.labels.matchLabels
- common.tplvalues.render
- common.affinities.pods
- common.affinities.nodes
*/}}

{{- define "common.tplvalues.render" -}}
{{- /* In original common chart this rendered values supporting tpl. Here we just toYaml the value. */ -}}
{{- $value := .value -}}
{{- if kindIs "string" $value -}}
{{- tpl $value .context -}}
{{- else -}}
{{- toYaml $value -}}
{{- end -}}
{{- end -}}

{{- define "common.labels.standard" -}}
{{- $ctx := . -}}
app.kubernetes.io/managed-by: {{ $ctx.Release.Service | quote }}
app.kubernetes.io/instance: {{ $ctx.Release.Name | quote }}
helm.sh/chart: {{ printf "%s-%s" $ctx.Chart.Name $ctx.Chart.Version | quote }}
app.kubernetes.io/name: {{ $ctx.Chart.Name | quote }}
{{- end -}}

{{- define "common.labels.matchLabels" -}}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
app.kubernetes.io/name: {{ .Chart.Name | quote }}
{{- end -}}

{{- define "common.affinities.pods" -}}
{{- /* Simplified pod affinity presets */ -}}
{{- $type := .type | default "" -}}
{{- if eq $type "soft" -}}
preferredDuringSchedulingIgnoredDuringExecution:
  - weight: 100
    podAffinityTerm:
      topologyKey: kubernetes.io/hostname
      labelSelector: { }
{{- else if eq $type "hard" -}}
requiredDuringSchedulingIgnoredDuringExecution:
  - topologyKey: kubernetes.io/hostname
    labelSelector: { }
{{- end -}}
{{- end -}}

{{- define "common.affinities.nodes" -}}
{{- /* Simplified node affinity */ -}}
{{- $type := .type | default "" -}}
{{- if eq $type "soft" -}}
preferredDuringSchedulingIgnoredDuringExecution:
  - weight: 100
    preference:
      matchExpressions:
        - key: {{ .key | default "kubernetes.io/os" }}
          operator: In
          values: {{ toYaml (.values | default (list "linux")) | nindent 12 }}
{{- else if eq $type "hard" -}}
requiredDuringSchedulingIgnoredDuringExecution:
  nodeSelectorTerms:
    - matchExpressions:
        - key: {{ .key | default "kubernetes.io/os" }}
          operator: In
          values: {{ toYaml (.values | default (list "linux")) | nindent 12 }}
{{- end -}}
{{- end -}}

{{- /* Simplified common.names.fullname (bitnami chart usually mixes release and chart name) */ -}}
{{- define "common.names.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- /* Ingress API version capability check */ -}}
{{- define "common.capabilities.ingress.apiVersion" -}}
{{- print "networking.k8s.io/v1" -}}
{{- end -}}
