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
Workload failure domain.
*/}}
{{- define "openstack.failureDomain.compute.workload" -}}
{{ .pool.machine.failureDomain | default .values.openstack.computeFailureDomain }}
{{- end }}

{{/*
Workload volume failure domain.
*/}}
{{- define "openstack.failureDomain.volume.workload" -}}
{{ .pool.machine.disk.failureDomain | default .values.openstack.volumeFailureDomain }}
{{- end }}

{{/*
Control plane node labels.
*/}}
{{- define "openstack.nodelabels.control-plane" -}}
{{- $labels := list (printf "topology.%s/node-pool=control-plane" .Values.labelDomain) }}
{{- join "," $labels }}
{{- end }}

{{/*
Worker pool node labels.
For some reason $.Values doesn't work in an included template so please
see the logic in workload.yaml for seeding names, regions etc.
*/}}
{{- define "openstack.nodelabels.workload" -}}
{{- $context := . }}
{{- $labels := list (printf "topology.%s/node-pool=%s" .values.labelDomain .name) }}
{{- with $autoscaling := .pool.autoscaling }}
  {{- with $scheduler := $autoscaling.scheduler }}
    {{- with $gpu := $scheduler.gpu }}
      {{- $labels = append $labels (printf "cluster-api/accelerator=%s" $context.pool.machine.flavor) }}
    {{- end }}
  {{- end }}
{{- end }}
{{- range $key, $value := .pool.labels }}
  {{- $labels = append $labels (printf "%s=%s" $key $value) }}
{{- end }}
{{- join "," $labels }}
{{- end }}

{{/*
Control plane pool names.
Many of the CAPI/CAPO resources are immutable and to trigger an upgrade we need
to create new resources.  Rather than mess about with individual values, some
of which may not get added here, we try design the API in a way that we can just
take a whole object and marshal it.
*/}}
{{- define "openstack.discriminator.control-plane.api" -}}
{{- $value := dict }}
{{- with $api := .Values.api }}
{{- $value = set $value "certificateSANs" $api.certificateSANs }}
{{- end }}
{{- $value | mustToJson | sha256sum }}
{{- end }}

{{- define "openstack.discriminator.control-plane" -}}
{{- (dict "api" (include "openstack.discriminator.control-plane.api" .) "pool" .Values.controlPlane.machine) | mustToJson | sha256sum | trunc 8 }}
{{- end }}

{{/*
Workload pool names.
*/}}
{{- define "openstack.discriminator.workload" -}}
{{- (dict "pool" .pool.machine) | mustToJson | sha256sum | trunc 8 }}
{{- end }}

{{/*
Taints
*/}}
{{- define "openstack.taints.control-plane" -}}
- key: node-role.kubernetes.io/control-plane
  effect: NoSchedule
{{- with $cluster := .Values.cluster }}
{{- with $taints := $cluster.taints }}
{{- range $taint := $taints }}
- key: {{ $taint.key }}
  effect: {{ $taint.effect }}
{{- if .value }}
  value: '{{ $taint.value }}'
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{- define "openstack.taints.workload" -}}
{{- with $cluster := .Values.cluster }}
{{- with $taints := $cluster.taints }}
{{- range $taint := $taints }}
- key: {{ $taint.key }}
  effect: {{ $taint.effect }}
{{- if .value }}
  value: '{{ $taint.value }}'
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
