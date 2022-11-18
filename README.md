# fylr-helm

A Helm-Chart for the fylr application

## Default deployment
see [charts/fylr/](https://github.com/programmfabrik/fylr-helm/blob/main/charts/fylr/README.md)

## Deploy execserver separately
... if you do not want to deploy it as part of the fylr helm chart, e.g. to have a pool of execservers that work for many flyr instances:

see [charts/execserver](https://github.com/programmfabrik/fylr-helm/tree/main/charts/execserver)

------

## Contact us

For Issues and questions please write to support@programmfabrik.de

------

## Development and Testing

### Requirements

- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
- [helm](https://github.com/helm/helm/)
- [ct](https://github.com/helm/chart-testing)
- A Kubernetes test cluster, e.g. via [Minikube](https://minikube.sigs.k8s.io/docs/start/), [Kind](https://kind.sigs.k8s.io/) or [Docker-Desktop](https://www.docker.com/products/docker-desktop/)
- *Yamllint*, *Yamale* simply install these packages with `make dep-install`

### Setup

- Install the requirements
- Install the dependencies with `make dep-install`
- Install a local Kubernetes cluster
- Install an Ingress Controller, e.g. [nginx-ingress](https://kubernetes.github.io/ingress-nginx/deploy/)

### Linting

#### Lint execserver

```bash
make lint-execserver
```

#### Lint fylr

```bash
make lint-fylr
```

### Testing

#### Test execserver

```bash
make test-execserver
```

#### Test fylr

```bash
make test-fylr
```

### Install

#### Install execserver

```bash
make install-execserver
```

#### Install fylr

```bash
make install-fylr
```

### Uninstall

#### Uninstall execserver

```bash
make uninstall-execserver
```

#### Uninstall fylr

```bash
make uninstall-fylr
```
