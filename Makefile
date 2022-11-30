# Update this for every tagged release.
CHART_VERSION = v0.1.0

# Defines the versions to use for cluster API components.
CAPI_VERSION = v1.2.6
CAPO_VERSION = v0.6.4

# All the charts we can generate.
CHARTS = cluster-api-core \
	 cluster-api-bootstrap-kubeadm \
	 cluster-api-control-plane-kubeadm \
	 cluster-api-provider-openstack

# Generator script location.
GENERATE = ./generate.py

all: $(CHARTS)

.PHONY: cluster-api-core
cluster-api-core:
	$(GENERATE) --chart $@ --version $(CHART_VERSION) --app-version $(CAPI_VERSION) --path https://github.com/kubernetes-sigs/cluster-api/config/default?ref=$(CAPI_VERSION)

.PHONY: cluster-api-bootstrap-kubeadm
cluster-api-bootstrap-kubeadm:
	$(GENERATE) --chart $@ --version $(CHART_VERSION) --app-version $(CAPI_VERSION) --path https://github.com/kubernetes-sigs/cluster-api/bootstrap/kubeadm/config/default?ref=$(CAPI_VERSION)

.PHONY: cluster-api-control-plane-kubeadm
cluster-api-control-plane-kubeadm:
	$(GENERATE) --chart $@ --version $(CHART_VERSION) --app-version $(CAPI_VERSION) --path https://github.com/kubernetes-sigs/cluster-api/controlplane/kubeadm/config/default?ref=$(CAPI_VERSION)

.PHONY: cluster-api-provider-openstack
cluster-api-provider-openstack:
	$(GENERATE) --chart $@ --version $(CHART_VERSION) --app-version $(CAPO_VERSION) --path https://github.com/kubernetes-sigs/cluster-api-provider-openstack/config/default?ref=${CAPO_VERSION}

.PHONY: test
test:
	set -e; for chart in $(CHARTS); do helm template $${chart} > /dev/null; done
