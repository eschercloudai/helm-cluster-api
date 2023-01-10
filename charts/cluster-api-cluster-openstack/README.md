# Installing an OpenStack Cluster

... is quite involved!  

## Configuration Variables

Please consult the [`values.yaml`](values.yaml) file for some basic examples.
The [`values.schema.json`](values.schema.json) file documents structure, types and required fields further.

## Helm

When using Helm directly, deprovisioning will delete the identity secret used to access OpenStack immediately and result in a deadlock.
Don't use this :smile:

## ArgoCD

Unlike Helm, ArgoCD can provision and deprovision in "waves", thus we can keep the identity secret alive for the duration of deprovisioning.
This is the only supported method of operation.

Here's an example application:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: foo
  namespace: argocd
spec:
  destination:
    server: kubernetes.default.svc
    namespace: foo
  project: default
  source:
    repoURL: https://eschercloudai.github.io/helm-cluster-api
    chart: cluster-api-cluster-openstack
    targetRevision: v0.1.2
    helm:
      releaseName: foo
      # Remove the default work queue.
      parameters:
      - name: workload.default
        value: null
      values: |-
        openstack:
          cloud: REDACTED
          cloudsYAML: REDACTED
          ca: REDACTED
          sshKeyName: REDACTED
          region: en-west-1
          failureDomain: eu-west-1a
          externalNetworkID: dadfef54-d1c5-447a-8933-f515eeadd822
        cluster:
          taints:
          - key: node.cilium.io/agent-not-ready
            effect: NoSchedule
            value: 'true'
        api:
          allowList:
          - 123.45.67.89
          certificateSANs:
          - kubernetes.my-domain.com
        controlPlane:
          version:  v1.25.4
          image: ubu2204-v1.25.5-9d105bc5
          flavor: g.4.standard
          diskSize: 40
          replicas: 3
        workloadPools:
          general-purpose:
            version:  v1.25.4
            image: ubu2204-v1.25.5-9d105bc5
            flavor: g.4.standard
            diskSize: 100
            replicas: 3
            autoscaling:
              limits:
                minReplicas: 3
                maxReplicas: 10
              scheduler:
                cpu: 4
                memory: 16G
          gpu:
            version: v1.25.4
            image: ubu2204-v1.25.5-gpu-510.73.08-2cbfe3d7
            flavor: g.4.highmem.a100.1g.10gb
            diskSize: 100
            replicas: 3
            autoscaling:
              limits:
                minReplicas: 3
                maxReplicas: 10
              scheduler:
                cpu: 4
                memory: 32G
                gpu:
                  type: nvidia.com/gpu
                  count: 1
        network:
          nodeCIDR: 192.168.0.0/12
          serviceCIDRs:
          - 172.16.0.0/12
          podCIDRs:
          - 10.0.0.0/8
          dnsNameservers:
          - 1.1.1.1
          - 8.8.8.8
  syncPolicy:
    automated:
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

This by itself will not actually provision a working cluster.
See below for more details.

### Getting Working Cluster

To acheive a working cluster that is correctly scaled and works, you will also need to concurrently install:

* A CNI
* [The Openstack cloud provider](https://github.com/kubernetes/cloud-provider-openstack)

To do this, grab the kubeconfig file, subsituting the correct namespace and release name:

```shell
kubectl -n foo foo-kubeconfig -o 'jsonpath={.data.value}' | base64 -d
```

Then use Helm of similar to provision against that kubeconfig.
