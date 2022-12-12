# Helm Charts to Deploy Cluster API

## Why?

`clusterctl` is very opinionated, it will pull down some kustomize generated maifests, then do some environment substitution on them.
This isn't compatible with ArgoCD for example, hence this project.

## How

In simple terms, we run `kubectl kustomize`, chop up the manifests and auto generate templates.
When we encounter one of the annoying evironment variables, we replace it with Go templating, then add the replacement into `values.yaml`.

## Deploying Prerequisites

This chart requires the following to be installed on the target cluster first:

### Cert-Manager

<details>
<summary>Helm</summary>

```shell
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager --version v1.10.1 --namespace cert-manager --create-namespace
```
</details>

<details>
<summary>ArgoCD</summary>

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  generateName: cert-manager-
  namespace: argocd
  labels:
    project.unikorn.eschercloud.ai: ${PROJECT}
    controlplane.unikorn.eschercloud.ai: ${CONTROL_PLANE}
spec:
  project: default
  source:
    chart: cert-manager
    repoURL: https://charts.jetstack.io
    targetRevision: v1.10.1
    helm:
      releaseName: cert-manager
      parameters:
      - name: installCRDs
        value: true
  destination:
    name: ${TARGET_VCLUSTER}
    namespace: cert-manager
  syncPolicy:
    automated:
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```
</details>

## Deploying One-Shot

There is a top level chart-of-charts that will just install everything as a big bang operation.

<details>
<summary>Helm</summary>

```shell
helm repo add eschercloudai-capi https://eschercloudai.github.io/helm-cluster-api
helm repo update
helm install eschercloudai-capi/cluster-api --version v0.1.0
```
</details>

<details>
<summary>ArgoCD</summary>

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cluster-api
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://eschercloudai.github.io/helm-cluster-api
    chart: cluster-api
    targetRevision: v0.1.0
  destination:
    server: https://172.18.255.200:443
  ignoreDifferences:
  # Aggregated roles are mangically updated by the API.
  - group: rbac.authorization.k8s.io
    kind: ClusterRole
    name: capi-aggregated-manager-role
    jsonPointers:
    - /rules
  - group: rbac.authorization.k8s.io
    kind: ClusterRole
    name: capi-kubeadm-control-plane-aggregated-manager-role
    jsonPointers:
    - /rules
  # CA certs are injected by cert-manager mutation
  - group: apiextensions.k8s.io
    kind: CustomResourceDefinition
    jsonPointers:
    - /spec/conversion/webhook/clientConfig/caBundle
  syncPolicy:
    automated:
      selfHeal: true
    syncOptions:
    - RespectIgnoreDifferences=true
```
</details>

## Deploying Main Components

You may want to be a little less gung-ho and deploy the pieces as separate applications.

### Core

<details>
<summary>Helm</summary>

```shell
helm repo add eschercloudai-capi https://eschercloudai.github.io/helm-cluster-api
helm repo update
helm install eschercloudai-capi/cluster-api-core --version v0.1.0
```
</details>

<details>
<summary>ArgoCD</summary>

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  generateName: cluster-api-core-
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://eschercloudai.github.io/helm-cluster-api
    chart: cluster-api-core
    targetRevision: v0.1.0
  destination:
    server: https://172.18.255.200:443
  ignoreDifferences:
  # Aggregated roles are mangically updated by the API.
  - group: rbac.authorization.k8s.io
    kind: ClusterRole
    name: capi-aggregated-manager-role
    jsonPointers:
    - /rules
  # CA certs are injected by cert-manager mutation
  - group: apiextensions.k8s.io
    kind: CustomResourceDefinition
    jsonPointers:
    - /spec/conversion/webhook/clientConfig/caBundle
  syncPolicy:
    automated:
      selfHeal: true
    syncOptions:
    - RespectIgnoreDifferences=true
```
</details>

### Bootstrap

<details>
<summary>Helm</summary>

```shell
helm repo add eschercloudai-capi https://eschercloudai.github.io/helm-cluster-api
helm repo update
helm install eschercloudai-capi/cluster-api-bootstrap-kubeadm --version v0.1.0
```
</details>

<details>
<summary>ArgoCD</summary>

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  generateName: cluster-api-bootstrap-kubeadm-
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://eschercloudai.github.io/helm-cluster-api
    chart: cluster-api-bootstrap-kubeadm
    targetRevision: v0.1.0
  destination:
    server: https://172.18.255.200:443
  ignoreDifferences:
  - group: apiextensions.k8s.io
    jsonPointers:
    - /spec/conversion/webhook/clientConfig/caBundle
    kind: CustomResourceDefinition
  syncPolicy:
    automated:
      selfHeal: true
    syncOptions:
    - RespectIgnoreDifferences=true
```
</details>

### Control Plane

<details>
<summary>Helm</summary>

```shell
helm repo add eschercloudai-capi https://eschercloudai.github.io/helm-cluster-api
helm repo update
helm install eschercloudai-capi/cluster-api-control-plane-kubeadm --version v0.1.0
```
</details>

<details>
<summary>ArgoCD</summary>

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  generateName: cluster-api-control-plane-kubeadm-
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://eschercloudai.github.io/helm-cluster-api
    chart: cluster-api-control-plane-kubeadm
    targetRevision: v0.1.0
  destination:
    server: https://172.18.255.200:443
  ignoreDifferences:
  - group: rbac.authorization.k8s.io
    jsonPointers:
    - /rules
    kind: ClusterRole
    name: capi-kubeadm-control-plane-aggregated-manager-role
  - group: apiextensions.k8s.io
    jsonPointers:
    - /spec/conversion/webhook/clientConfig/caBundle
    kind: CustomResourceDefinition
  syncPolicy:
    automated:
      selfHeal: true
    syncOptions:
    - RespectIgnoreDifferences=true
```
</details>

## Deploying Infrastructure Providers

Add providers to allow CAPI to talk to various cloud providers.

### OpenStack

<details>
<summary>Helm</summary>

```shell
helm repo add eschercloudai-capi https://eschercloudai.github.io/helm-cluster-api
helm repo update
helm install eschercloudai-capi/cluster-api-provider-openstack --version v0.1.0
```
</details>

<details>
<summary>ArgoCD</summary>

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  generateName: cluster-api-provider-openstack-
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://eschercloudai.github.io/helm-cluster-api
    chart: cluster-api-provider-openstack
    targetRevision: v0.1.0
  destination:
    server: https://172.18.255.200:443
  ignoreDifferences:
  - group: apiextensions.k8s.io
    jsonPointers:
    - /spec/conversion/webhook/clientConfig/caBundle
    kind: CustomResourceDefinition
  syncPolicy:
    automated:
      selfHeal: true
    syncOptions:
    - RespectIgnoreDifferences=true
```
</details>

## Developers

It's a simple as:

* Bump the versions in `Makefile` and `charts/cluster-api/Chart.yaml`
* Run `make`
* Commit and merge.
