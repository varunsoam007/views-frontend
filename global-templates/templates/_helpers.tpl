{{/*
Copyright (C) 2024 XM Cyber
Author: Devops Infra Team
*/}}

{{/*
  Render an array of env variables, the input can be a map or a slice.
  Usage: 
    {{- include "helpers.toEnvArray" (dict "container" . "global" $global_values "context" $) }}
*/}}
{{- define "helpers.toEnvArray" -}}
{{- $envArray := list -}}
{{- $global := .global -}}

{{/* Process regular env variables */}}
{{- if kindIs "map" .container.env }}
  {{- range $key, $value := .container.env }}
    {{- if kindIs "map" $value }}
      {{- $envArray = append $envArray (dict "name" $key "valueFrom" $value.valueFrom) -}}
    {{- else }}
      {{- $envArray = append $envArray (dict "name" $key "value" $value) -}}
    {{- end }}
  {{- end }}
{{- else if kindIs "slice" .container.env }}
  {{- $envArray = .container.env -}}
{{- end }}

{{- range $envArray }}
{{- if hasKey . "value" }}
{{- $renderedValue := include "helpers.renderGlobalIfExists" (dict "value" (.value | quote) "global" $global) }}
- name: {{ .name }}
  value: {{ $renderedValue }}
{{- else if hasKey . "valueFrom" }}
- name: {{ .name }}
  valueFrom:
    {{- toYaml .valueFrom | nindent 4 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
  Render the image full path
  Usage: 
    {{ include "helpers.image.fullPath" (dict "container" . "global" $global_values) }}
*/}}
{{- define "helpers.image.fullPath" -}}

{{- $images := dict -}}
{{- $registry := "" -}}
{{- $container := .container -}}

{{- if .global -}}
  {{- $images = .global.images -}}
  {{- $registry = .global.registry -}}
{{- end -}}


{{- $image := dict -}}

{{- if $container.image }}
  {{- if not $container.image.repository }}
    {{- fail "Image repository must be provided" -}}
  {{- end -}}
  {{- $_ := set $image "registry" ($container.image.registry | default $registry) -}}
  {{- $_ := set $image "repository" $container.image.repository -}}
  {{- $_ := set $image "tag" (or $container.image.tag "") -}}
  {{- $_ := set $image "sha" (or $container.image.sha "") -}}
{{- else if $container.imageKey }}
  {{- $imgConf := get $images $container.imageKey -}}
  {{- if not $imgConf }}
    {{- fail (printf "Image with key '%s' not found" $container.imageKey) -}}
  {{- end -}}
  {{- if not $imgConf.repository }}
    {{- fail (printf "Image repository must be provided for key '%s'" $container.imageKey) -}}
  {{- end -}}
  {{- if and (not $imgConf.registry) (not $registry) }}
    {{- fail (printf "Registry must be provided either in the image configuration for key '%s' or globally using 'global.registry'" $container.imageKey) -}}
  {{- end -}}
  {{- $_ := set $image "registry" (default $registry $imgConf.registry) -}}
  {{- $_ := set $image "repository" $imgConf.repository -}}
  {{- $_ := set $image "tag" (or $imgConf.tag "") -}}
  {{- $_ := set $image "sha" (or $imgConf.sha "") -}}
{{- else }}
  {{- fail "Either image or imageKey must be provided for the container" -}}
{{- end -}}


{{- if and (not $image.tag) (not $image.sha) }}
  {{- fail "Either tag or sha must be provided" -}}
{{- end -}}

{{- if $image.sha }}
  {{- printf "%s/%s@%s" $image.registry $image.repository $image.sha -}}
{{- else }}
  {{- printf "%s/%s:%s" $image.registry $image.repository $image.tag -}}
{{- end -}}
{{- end -}}

{{/*
  Copy an array
  Usage: 
    {{ include "helpers.copyArray" . }}
*/}}
{{- define "helpers.copyArray" -}}
[{{ range $index, $element := . }}{{ if $index }},{{ end }}"{{ $element }}"{{ end }}]
{{- end -}}

{{/* 
  Helper function to determine the namespace
  Usage: 
    {{ include "helpers.namespace" . }}
*/}}
{{- define "helpers.namespace" -}}
{{- $ns := .ns | default "default" }}
{{- $overrideNs := .overrideNs -}}
{{- if and $overrideNs (ne $overrideNs "default") }}
{{- $overrideNs }}
{{- else }}
{{- $ns }}
{{- end }}
{{- end -}}

{{/*
  Render the metadata lables
  Usage:
  {{ include "helpers.labels" (dict "context" $ "customLabels" .labels "defaultLabels" $common_defaults.labels) }}
*/}}
{{- define "helpers.labels" -}}
{{- $standardLabels := (include "common.labels.standard" .context | fromYaml) }}
{{- $customLabels := .customLabels | default dict }}
{{- $defaultLabels := .defaultLabels | default dict }}
{{- $combinedLabels := merge $standardLabels $customLabels $defaultLabels }}
{{- include "common.tplvalues.render" (dict "value" $combinedLabels "context" .context) }}
{{- end }}

{{/*
  Render the metadata annotation
  Usage:
    {{ include "helpers.annotations" (dict "context" $ "customAnnotations" .annotations "defaultAnnotations" $common_defaults.annotations "reloaderEnabled" .reloaderEnabled) }}
*/}}
{{- define "helpers.annotations" -}}
{{- $customAnnotations := .customAnnotations | default dict }}
{{- $defaultAnnotations := .defaultAnnotations | default dict }}
{{- $combinedAnnotations := merge $defaultAnnotations $customAnnotations }}
{{- if .reloaderEnabled }}
{{- $combinedAnnotations := merge $combinedAnnotations (dict "reloader.stakater.com/auto" "true") }}
{{- end }}
{{- include "common.tplvalues.render" (dict "value" $combinedAnnotations "context" .context) }}
{{- end }}

{{/*
  Validate an enum value
  Usage:
    {{ include "helpers.validateEnumValue" (list .value (list "Option1" "Option2" "Option3")) }}
*/}}
{{- define "helpers.validateEnumValue" -}}
{{- $value := index . 0 }}
{{- $list := index . 1 }}
{{- if not (has $value $list) }}
{{ fail (printf "Invalid value: %s. Must be one of: %s" $value (join ", " $list)) }}
{{- end }}
{{- end }}

{{/*
  Prefix a single namespace
  Usage:
    {{ include "helpers.prefixNamespace" (dict "namespace" "my-namespace" "global" $global_values) }}
*/}}
{{- define "helpers.prefixNamespace" -}}
{{- $prefix := "" -}}
{{- if .global }}
  {{- $prefix = .global.nsPrefix | default "" -}}
{{- end -}}
{{- $namespace := include "helpers.renderGlobalIfExists" (dict "value" (.namespace | required "namespace is required") "global" .global) }}
{{- if $prefix }}
  {{- printf "%s-%s" $prefix $namespace -}}
{{- else }}
  {{- $namespace -}}
{{- end -}}
{{- end -}}

{{/*
  Prefix multiple namespaces
  Usage:
    {{ include "helpers.prefixNamespaces" (dict "namespaces" .namespaces "global" $global_values) }}
*/}}
{{- define "helpers.prefixNamespaces" -}}
{{- $global := .global | required "global is required" -}}
{{- $namespaces := .namespaces | required "namespaces are required" -}}
{{- range $namespace := $namespaces }}
- {{ include "helpers.prefixNamespace" (dict "namespace" $namespace "global" $global) }}
{{- end -}}
{{- end -}}

{{/*
  Parse contents from file
  Usage:
  {{- $parsedData := include "helpers.parseYamlFile" (dict "Files" $files "Filename" .file) }}
*/}}
{{- define "helpers.parseYamlFile" -}}
{{- if not (.Files.Get .Filename) -}}
{{- fail (printf "Error: File %s does not exist" .Filename) -}}
{{- else -}}
{{- $fileContents := .Files.Get .Filename | fromYaml | default dict -}}
{{- range $key, $val := $fileContents }}
{{ $key }}: |
{{- $val | trim | nindent 4 }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Aggregator */}}
{{- define "global-templates.all" -}}
{{- $ctx := dict "Values" .Values "Release" .Release "Chart" .Chart "Capabilities" .Capabilities -}}
{{- if .Values.deployments }}{{- $ctx = merge $ctx (dict "deployments" .Values.deployments) }}{{- end }}
{{- if .Values.statefulsets }}{{- $ctx = merge $ctx (dict "statefulsets" .Values.statefulsets) }}{{- end }}
{{- if .Values.cronjobs }}{{- $ctx = merge $ctx (dict "cronjobs" .Values.cronjobs) }}{{- end }}
{{- if .Values.services }}{{- $ctx = merge $ctx (dict "services" .Values.services) }}{{- end }}
{{- if .Values.configmaps }}{{- $ctx = merge $ctx (dict "configmaps" .Values.configmaps) }}{{- end }}
{{- if .Values.externalsecrets }}{{- $ctx = merge $ctx (dict "externalsecrets" .Values.externalsecrets) }}{{- end }}
{{- if .Values.clusterexternalsecrets }}{{- $ctx = merge $ctx (dict "clusterexternalsecrets" .Values.clusterexternalsecrets) }}{{- end }}
{{- if .Values.hpas }}{{- $ctx = merge $ctx (dict "hpas" .Values.hpas) }}{{- end }}
{{- if .Values.pdbs }}{{- $ctx = merge $ctx (dict "pdbs" .Values.pdbs) }}{{- end }}
{{- if .Values.roles }}{{- $ctx = merge $ctx (dict "roles" .Values.roles) }}{{- end }}
{{- if .Values.rolebindings }}{{- $ctx = merge $ctx (dict "rolebindings" .Values.rolebindings) }}{{- end }}
{{- if .Values.serviceaccounts }}{{- $ctx = merge $ctx (dict "serviceaccounts" .Values.serviceaccounts) }}{{- end }}
{{- if .Values.ingresses }}{{- $ctx = merge $ctx (dict "ingresses" .Values.ingresses) }}{{- end }}
{{- if .Values.httproutes }}{{- $ctx = merge $ctx (dict "httproutes" .Values.httproutes) }}{{- end }}
{{- if .Values.certificates }}{{- $ctx = merge $ctx (dict "certificates" .Values.certificates) }}{{- end }}
{{- if .Values.clusterissuers }}{{- $ctx = merge $ctx (dict "clusterissuers" .Values.clusterissuers) }}{{- end }}
{{- if .Values.issuers }}{{- $ctx = merge $ctx (dict "issuers" .Values.issuers) }}{{- end }}
{{- if .Values.sealedsecrets }}{{- $ctx = merge $ctx (dict "sealedsecrets" .Values.sealedsecrets) }}{{- end }}
{{- if .Values.secrets }}{{- $ctx = merge $ctx (dict "secrets" .Values.secrets) }}{{- end }}
{{- if .Values.scaledobjects }}{{- $ctx = merge $ctx (dict "scaledobjects" .Values.scaledobjects) }}{{- end }}
{{- if .Values.triggerauthentications }}{{- $ctx = merge $ctx (dict "triggerauthentications" .Values.triggerauthentications) }}{{- end }}
{{- if .Values.servicemonitors }}{{- $ctx = merge $ctx (dict "servicemonitors" .Values.servicemonitors) }}{{- end }}
{{- if .Values.grafanafolders }}{{- $ctx = merge $ctx (dict "grafanafolders" .Values.grafanafolders) }}{{- end }}
{{- if .Values.grafanadashboards }}{{- $ctx = merge $ctx (dict "grafanadashboards" .Values.grafanadashboards) }}{{- end }}
{{- if .Values.grafanaDashboardTemplates }}{{- $ctx = merge $ctx (dict "grafanaDashboardTemplates" .Values.grafanaDashboardTemplates) }}{{- end }}
{{- if .Values.authorizationpolicies }}{{- $ctx = merge $ctx (dict "authorizationpolicies" .Values.authorizationpolicies) }}{{- end }}
{{- if .Values.auth }}{{- $ctx = merge $ctx (dict "auth" .Values.auth) }}{{- end }}
{{- if .Values.networkPolicy }}{{- $ctx = merge $ctx (dict "networkPolicy" .Values.networkPolicy) }}{{- end }}
{{- if $ctx.deployments }}{{ include "global-templates.deployment" $ctx }}{{- end }}
{{- if $ctx.statefulsets }}{{ include "global-templates.statefulset" $ctx }}{{- end }}
{{- if $ctx.cronjobs }}{{ include "global-templates.cronjob" $ctx }}{{- end }}
{{- if $ctx.services }}{{ include "global-templates.service" $ctx }}{{- end }}
{{- if $ctx.configmaps }}{{ include "global-templates.configmap" $ctx }}{{- end }}
{{- if $ctx.externalsecrets }}{{ include "global-templates.externalsecret" $ctx }}{{- end }}
{{- if $ctx.clusterexternalsecrets }}{{ include "global-templates.clusterexternalsecret" $ctx }}{{- end }}
{{- if $ctx.hpas }}{{ include "global-templates.hpa" $ctx }}{{- end }}
{{- if $ctx.pdbs }}{{ include "global-templates.pdb" $ctx }}{{- end }}
{{- if $ctx.roles }}{{ include "global-templates.role" $ctx }}{{- end }}
{{- if $ctx.rolebindings }}{{ include "global-templates.rolebinding" $ctx }}{{- end }}
{{- if $ctx.serviceaccounts }}{{ include "global-templates.serviceaccount" $ctx }}{{- end }}
{{- if $ctx.ingresses }}{{ include "global-templates.ingress" $ctx }}{{- end }}
{{- if $ctx.httproutes }}{{ include "global-templates.httproute" $ctx }}{{- end }}
{{- if $ctx.certificates }}{{ include "global-templates.certificate" $ctx }}{{- end }}
{{- if $ctx.clusterissuers }}{{ include "global-templates.clusterissuer" $ctx }}{{- end }}
{{- if $ctx.issuers }}{{ include "global-templates.issuer" $ctx }}{{- end }}
{{- if $ctx.sealedsecrets }}{{ include "global-templates.sealedsecrets" $ctx }}{{- end }}
{{- if $ctx.secrets }}{{ include "global-templates.secret" $ctx }}{{- end }}
{{- if $ctx.scaledobjects }}{{ include "global-templates.scaledobject" $ctx }}{{- end }}
{{- if $ctx.triggerauthentications }}{{ include "global-templates.triggerauthentication" $ctx }}{{- end }}
{{- if $ctx.servicemonitors }}{{ include "global-templates.servicemonitor" $ctx }}{{- end }}
{{- if $ctx.grafanafolders }}{{ include "global-templates.grafanafolder" $ctx }}{{- end }}
{{- if $ctx.grafanadashboards }}{{ include "global-templates.grafanadashboard" $ctx }}{{- end }}
{{- if $ctx.grafanaDashboardTemplates }}{{ include "global-templates.dashboardTemplates.render" $ctx }}{{- end }}
{{- if or $ctx.authorizationpolicies $ctx.auth }}{{ include "global-templates.authorizationpolicy" $ctx }}{{- end }}
{{- if $ctx.networkPolicy }}{{ include "global-templates.networkpolicy" $ctx }}{{- end }}
{{- end -}}

{{- /*
A helper function to replace placeholders within a string with corresponding global values.
Supports nested values using dot notation.
Returns the original value if:
- No placeholders are found
- The corresponding global value path is not found
- The input is a number

Placeholder format: {{ global.path.to.value_name }}

Example global values:
global:
  db:
    host: localhost
    port: 5432
  api:
    key: secret

Input: "Connect to {{global.db.host}}:{{ global.db.port }} using {{global.api.key}}"
Output: "Connect to localhost:5432 using secret"

Parameters:
- dict:
  - "value": The main value to evaluate
  - "global": The global values object
*/ -}}
{{- define "helpers.renderGlobalIfExists" -}}
{{- $value := .value | default "" -}}
{{- $global := .global | default dict -}}

{{- if or (kindIs "int" $value) (kindIs "float64" $value) -}}
  {{- $value -}}
{{- else if and (kindIs "string" $value) (eq $value "") -}}
  {{- "" -}}
{{- else if eq (len $global) 0 -}}
  {{- $value -}}
{{- else -}}
  {{- /* Find all placeholders matching {{global.path.to.value}} pattern */ -}}
  {{- $regex := "\\{{2}\\s*global\\.([\\w\\-\\.\\_]+)\\s*\\}{2}" -}}
  {{- $result := $value -}}
  
  {{- /* Process each placeholder found */ -}}
  {{- range $placeholder := regexFindAll $regex $value -1 -}}
    {{- /* Extract the path after 'global.' */ -}}
    {{- $path := regexFind "[\\w\\-\\.\\_]+" (regexFind "global\\.([\\w\\-\\.\\_]+)" $placeholder) -}}
    {{- $path = trimPrefix "global." $path -}}
    
    {{- /* Split path into parts and traverse the global object */ -}}
    {{- $current := $global -}}
    {{- $valid := true -}}
    {{- range $part := splitList "." $path -}}
      {{- if hasKey $current $part -}}
        {{- $current = index $current $part -}}
      {{- else -}}
        {{- $valid = false -}}
      {{- end -}}
    {{- end -}}
    
    {{- /* Replace placeholder with value if path is valid and value is a string */ -}}
    {{- if and $valid (kindIs "string" $current) -}}
      {{- $result = replace $placeholder $current $result -}}
    {{- else if and $valid (or (kindIs "int" $current) (kindIs "float64" $current)) -}}
      {{- $result = replace $placeholder (printf "%v" $current) $result -}}
    {{- end -}}
  {{- end -}}
  
  {{- $result -}}
{{- end -}}
{{- end -}}