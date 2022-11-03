# fylr-helm

A Helm-Chart for the fylr application (WIP)

## Requirements

- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
- [helm](https://github.com/helm/helm/)
- [ct](https://github.com/helm/chart-testing)
- A local Kubernetes cluster either via [Minikube](https://minikube.sigs.k8s.io/docs/start/), [Kind](https://kind.sigs.k8s.io/) or [Docker-Desktop](https://www.docker.com/products/docker-desktop/)
- *Yamllint*, *Yamale* simply install these packages with `make dep-install`

## Development

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
