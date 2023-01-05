{{/*
Expand the name of the chart.
*/}}
{{- define "openstackcluster.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "openstackcluster.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "openstackcluster.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "openstackcluster.labels" -}}
helm.sh/chart: {{ include "openstackcluster.chart" . }}
{{ include "openstackcluster.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "openstackcluster.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openstackcluster.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Autoscaling annotations
*/}}
{{- define "openstackcluster.autoscalingAnnotations" -}}
{{- with $autoscaling := .autoscaling }}
{{- with $limits := $autoscaling.limits -}}
cluster.x-k8s.io/cluster-api-autoscaler-node-group-min-size: '{{ $limits.minReplicas }}'
cluster.x-k8s.io/cluster-api-autoscaler-node-group-max-size: '{{ $limits.maxReplicas }}'
{{- end }}
{{- with $scheduler := $autoscaling.scheduler }}
capacity.cluster-autoscaler.kubernetes.io/cpu: '{{ $scheduler.cpu }}'
capacity.cluster-autoscaler.kubernetes.io/memory: {{ $scheduler.memory }}
{{- with $gpu := $scheduler.gpu }}
capacity.cluster-autoscaler.kubernetes.io/gpu-type: {{ $gpu.type }}
capacity.cluster-autoscaler.kubernetes.io/gpu-count: '{{ $gpu.count }}'
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Control plane node labels.
*/}}
{{- define "openstack.nodelabels.control-plane" -}}
topology.{{ .Values.labelDomain }}/node-pool: control-plane
topology.kubernetes.io/region: {{ .Values.openstack.region }}
topology.kubernetes.io/zone: {{ .Values.openstack.failureDomain }}
{{- end }}

{{/*
Worker pool node labels.
For some reason $.Values doesn't work in an included template so please
see the logic in workload.yaml for seeding names, regions etc.
*/}}
{{- define "openstack.nodelabels.workload" -}}
{{- $pool := . -}}
topology.{{ $pool.labelDomain }}/node-pool: {{ $pool.name }}
topology.kubernetes.io/region: {{ $pool.region }}
topology.kubernetes.io/zone: {{ $pool.failureDomain }}
{{- with $autoscaling := .autoscaling }}
{{- with $scheduler := $autoscaling.scheduler }}
{{- with $gpu := $scheduler.gpu }}
cluster-api/accelerator: {{ $pool.flavor }}
{{- end }}
{{- end }}
{{- end }}
{{- range $key, $value := $pool.nodeLabels }}
{{ $key }}: {{ $value }}
{{- end }}
{{- end }}

{{/*
Control plane pool names.
Many of the CAPI/CAPO resources are immutable and to trigger an upgrade we need
to create new resources.  Rather than mess about with individual values, some
of which may not get added here, we try design the API in a way that we can just
take a whole object and marshal it.
*/}}
{{- define "openstack.discriminator.control-plane" -}}
{{ (dict "openstack" .Values.openstack "kubernetes" .Values.kubernetes "controlPlane" .Values.controlPlane) | mustToJson | sha256sum | trunc 8 }}
{{- end }}
