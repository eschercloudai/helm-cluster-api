# Helm Charts to Deploy Cluster API

## Why?

`clusterctl` is very opinionated, it will pull down some kustomize generated maifests, then do some environment substitution on them.
This isn't compatible with ArgoCD for example, hence this project.

## How

In simple terms, we run `kubectl kustomize`, chop up the manifests and auto generate templates.
When we encounter one of the annoying evironment variables, we replace it with Go templating, then add the replacement into `values.yaml`.

## Using with ArgoCD

Deploy the core components:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  generateName: cluster-api-core-
  namespace: argocd
spec:
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
  project: default
  source:
    path: cluster-api
    repoURL: https://github.com/eschercloudai/helm-cluster-api
    targetRevision: HEAD
  syncPolicy:
    automated:
      selfHeal: true
    syncOptions:
    - RespectIgnoreDifferences=true
```

Deploy the boostrap components:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  generateName: cluster-api-bootstrap-
  namespace: argocd
spec:
  destination:
    server: https://172.18.255.200:443
  ignoreDifferences:
  - group: apiextensions.k8s.io
    jsonPointers:
    - /spec/conversion/webhook/clientConfig/caBundle
    kind: CustomResourceDefinition
  project: default
  source:
    path: cluster-api-bootstrap
    repoURL: https://github.com/eschercloudai/helm-cluster-api
    targetRevision: HEAD
  syncPolicy:
    automated:
      selfHeal: true
    syncOptions:
    - RespectIgnoreDifferences=true
```

Deploy the control plane components:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  generateName: cluster-api-control-plane-
  namespace: argocd
spec:
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
  project: default
  source:
    path: cluster-api-control-plane
    repoURL: https://github.com/eschercloudai/helm-cluster-api
    targetRevision: HEAD
  syncPolicy:
    automated:
      selfHeal: true
    syncOptions:
    - RespectIgnoreDifferences=true
```

### Providers

Add providers to allow CAPI to talk to various cloud providers.

#### OpenStack

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  generateName: cluster-api-provider-openstack-
  namespace: argocd
spec:
  destination:
    server: https://172.18.255.200:443
  ignoreDifferences:
  - group: apiextensions.k8s.io
    jsonPointers:
    - /spec/conversion/webhook/clientConfig/caBundle
    kind: CustomResourceDefinition
  project: default
  source:
    path: cluster-api-provider-openstack
    repoURL: https://github.com/eschercloudai/helm-cluster-api
    targetRevision: HEAD
  syncPolicy:
    automated:
      selfHeal: true
    syncOptions:
    - RespectIgnoreDifferences=true
```

## Developers

It's a simple as:

```shell
make -e VERSION=v1.2.6
```
