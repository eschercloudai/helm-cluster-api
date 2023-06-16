{{/*
Rather than use the release name directly, we hash to to ensure we don't blow the
63 character name limit that Kubernetes imposes.
*/}}
{{- define "release.hash" }}
{{- .Release.Name | sha256sum | trunc 8 }}
{{- end }}

{{/*
When running multiple CAPO instances against a single cloud, names may alias and
you can end up using the same network for multiple clusters, when this happens its
pretty easy for one to end up deleting the other and vice versa.  To prevent this
we can inject a unique instance ID into the name to preven aliasing.
*/}}
{{- define "controller.hash" }}
{{- .Values.controllerInstance | sha256sum | trunc 8 }}
{{- end }}

{{- define "cluster.name" }}
{{- if .Values.legacyResourceNames }}
  {{- .Release.Name }}
{{- else }}
  {{- printf "cluster-%s" ( include "release.hash" . ) }}
{{- end }}
{{- end }}

{{/*
Ensure with clusters that the resource names are unique as CAPO, at least, uses
names rather than something unique about the resource to find the network.  It's
a classic split-brain problem, but a legitimate one when you consider you can have
dev/staging/production CAPI instances.
*/}}
{{- define "openstackcluster.name" }}
{{- if .Values.legacyResourceNames }}
  {{- .Release.Name }}
{{- else }}
  {{- if .Values.controllerInstance }}
    {{- printf "cluster-%s-instance-%s" ( include "release.hash" . ) ( include "controller.hash" . ) }}
  {{- else }}
    {{- printf "cluster-%s" ( include "release.hash" . ) }}
  {{- end }}
{{- end }}
{{- end }}

{{- define "cloudconfig.name" }}
{{- if .Values.legacyResourceNames }}
  {{- printf "%s-cloud-config" .Release.Name }}
{{- else }}
  {{- printf "cluster-%s-cloud-config" ( include "release.hash" . ) }}
{{- end }}
{{- end }}

{{- define "kubeadmcontrolplane.name" }}
{{- if .Values.legacyResourceNames }}
  {{- printf "%s-control-plane" .Release.Name }}
{{- else }}
  {{- printf "cluster-%s" ( include "release.hash" . ) }}
{{- end }}
{{- end }}

{{/*
The machine templates are a bit special in that their names will directly
influence the hostnames of the nodes.
*/}}
{{- define "controlplane.openstackmachinetemplate.name" }}
{{- if .Values.legacyResourceNames }}
  {{- printf "%s-control-plane-%s" .Release.Name ( include "openstack.discriminator.control-plane" . ) }}
{{- else }}
  {{- printf "cluster-%s-control-plane-%s" ( include "release.hash" . ) ( include "openstack.discriminator.control-plane" . ) }}
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
app.kubernetes.io/name: {{ include "cluster.name" . }}
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

{{/*
The initial $value is legacy and should not be modified unless a change is absolutely
necessary as this triggers a rolling upgrade.  Instead perfer to selectively add and
remove elements to legacy clusters aren't affected.
*/}}
{{- define "openstack.discriminator.control-plane" -}}
{{- $value := dict "api" (include "openstack.discriminator.control-plane.api" .) "pool" .Values.controlPlane.machine }}
{{- $clusterValue := dict }}
{{- with $cluster := .Values.cluster }}
  {{- with $serverMeta := $cluster.serverMetadata }}
    {{- $clusterValue = set $clusterValue "serverMetadata" $serverMeta }}
  {{- end }}
{{- end }}
{{- if not (empty $clusterValue) }}
{{- $value = set $value "cluster" $clusterValue }}
{{- end }}
{{- $value | mustToJson | sha256sum | trunc 8 }}
{{- end }}

{{/*
Workload pool names.
*/}}
{{- define "openstack.discriminator.workload" -}}
{{- $value := dict "pool" .pool.machine }}
{{- $clusterValue := dict }}
{{- with $cluster := .values.cluster }}
  {{- with $serverMeta := $cluster.serverMetadata }}
    {{- $clusterValue = set $clusterValue "serverMetadata" $serverMeta }}
  {{- end }}
{{- end }}
{{- if not (empty $clusterValue) }}
{{- $value = set $value "cluster" $clusterValue }}
{{- end }}
{{- $value | mustToJson | sha256sum | trunc 8 }}
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
