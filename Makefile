VERSION=v1.2.6

all:
	./generate.py --chart cluster-api --path https://github.com/kubernetes-sigs/cluster-api/config/default?ref=$(VERSION)
	./generate.py --chart cluster-api-bootstrap --path https://github.com/kubernetes-sigs/cluster-api/bootstrap/kubeadm/config/default?ref=$(VERSION)
	./generate.py --chart cluster-api-control-plane --path https://github.com/kubernetes-sigs/cluster-api/controlplane/kubeadm/config/default?ref=$(VERSION)
