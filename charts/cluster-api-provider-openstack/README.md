# Installing the OpenStack Infrastructure Provider

## Helm

```shell
helm repo add eschercloudai-capi https://eschercloudai.github.io/helm-cluster-api
helm repo update
helm install eschercloudai-capi/cluster-api-provider-openstack --version v0.1.1
```

## ArgoCD

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
    targetRevision: v0.1.1
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
