# Installing an OpenStack Cluster

... is quite involved!  

## Helm

When using Helm directly, deprovisioning will delete the identity secret used to access OpenStack immediately and result in a deadlock.
Don't use this :smile:

At the very least, you will need something like:

```shell
helm install foo eschercloudai-capi/cluster-api-cluster-openstack --version 0.1.2 \
	--namespace foo --create-namespace \
	--set openstack.cloud=my-cloud \
	--set openstack.cloudsYAML=$(cat ~/.config/openstack/clouds.yaml | base64 -w0) \
	--set openstack.externalNetworkID=4383d669-aae3-4aca-8e2e-d47cdc76d92b \
	--set openstack.ca=$(cat /etc/ssl/certs/ISRG_Root_X1.pem | base64 -w0) \
	--set openstack.cloudProviderConfiguration=$(cat meow | base64 -w0) \
	--set openstack.image=ubuntu-22.04-kubernetes-1.25.2 \
	--set openstack.sshKeyName=johndoe
```

See the [heml values file](values.yaml) file for all the things that can be altered.

It's recommended that `openstack.cloudsYAML` be sanitized to remove extra clouds that aren't needed.
The `openstack.externalNetworkID` can be attained from `openstack --os-cloud my-cloud network list --external`.
The `openstack.ca` you'll need to figure out, usually via `openssl s_client -host my.cloud.com -port 5000`.
The `openstack.cloudProviderConfiguration` can be derived from `clouds.yaml`, sadly CAPO doesn't do the conversion for you, so you'll need to follow the [configuration documentation](https://github.com/kubernetes/cloud-provider-openstack/blob/master/docs/openstack-cloud-controller-manager/using-openstack-cloud-controller-manager.md#config-openstack-cloud-controller-manager).
The `openstack.image` can be attained from `openstack --os-cloud my-cloud image list`, similarly `openstack --os-cloud my-cloud keypair list`.

Those are just the required values, you'll want to modify `controlplane`, `workload` and `kubernetes` parameters to tailor them for your specific environment.

## ArgoCD

Please consult the Helm documentation above for how to configure.

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
      parameters:
      - name: openstack.cloudsYAML
        value: REDACTED
      - name: openstack.cloud
        value: my-cloud
      - name: openstack.ca
        value: REDACTED
      - name: openstack.image
        value: ubuntu-22.04-kubernetes-1.25.2
      - name: openstack.cloudProviderConfiguration
        value: REDACTED
      - name: openstack.externalNetworkID
        value: 4383d669-aae3-4aca-8e2e-d47cdc76d92b
      - name: openstack.sshKeyName
        value: johndoe
      - name: openstack.failureDomain
        value: nova
      - name: controlPlane.replicas
        value: "3"
      - name: controlPlane.flavor
        value: m1.large
      - name: workload.replicas
        value: "3"
      - name: workload.flavor
        value: m1.large
      - name: network.nodeCIDR
        value: 192.168.0.0/16
      - name: network.serviceCIDRs[0]
        value: 172.16.0.0/12
      - name: network.podCIDRs[0]
        value: 10.0.0.0/8
      - name: network.dnsNameservers[0]
        value: 8.8.8.8
      - name: kubernetes.version
        value: v1.25.2
  syncPolicy:
    automated:
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```
