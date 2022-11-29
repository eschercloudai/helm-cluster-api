CAPI_VERSION=v1.2.6
CAPO_VERSION=v0.6.4


all:
	./generate.py --chart cluster-api --path https://github.com/kubernetes-sigs/cluster-api/config/default?ref=$(CAPI_VERSION)
	./generate.py --chart cluster-api-bootstrap --path https://github.com/kubernetes-sigs/cluster-api/bootstrap/kubeadm/config/default?ref=$(CAPI_VERSION)
	./generate.py --chart cluster-api-control-plane --path https://github.com/kubernetes-sigs/cluster-api/controlplane/kubeadm/config/default?ref=$(CAPI_VERSION)
	./generate.py --chart cluster-api-provider-openstack --path https://github.com/kubernetes-sigs/cluster-api-provider-openstack/config/default?ref=${CAPO_VERSION}
