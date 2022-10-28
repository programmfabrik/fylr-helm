# fylr-helm

A Helm-Chart for the fylr application

## Requirements

- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
- [helm](https://github.com/helm/helm/)
- [ct](https://github.com/helm/chart-testing)
- A local Kubernetes cluster either via [Minikube](https://minikube.sigs.k8s.io/docs/start/), [Kind](https://kind.sigs.k8s.io/) or [Docker-Desktop](https://www.docker.com/products/docker-desktop/)
- *Yamllint*, *Yamale* simply install these packages with `make dep-install`

## Charts

- [execserver](https://programmfabrik.github.io/fylr-helm/charts/execserver/)
- [fylr](https://programmfabrik.github.io/fylr-helm/charts/fylr/)

## Lint charts

```bash
make lint
```

## Test Install charts

```bash
make install
```
