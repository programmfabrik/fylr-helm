# fylr-helm

This repository provides all the components to deploy fylr on a Kubernetes cluster. The deployment is done using Helm.

## Getting started

### Prerequisites

- A Kubernetes cluster and the permissions needed to create, update, and delete resources (tested on >= 1.23.0)
- Helm (>= 3.8.0)

### Installing

To install *fylr* or the *execserver*, you need to add the fylr-helm repository to your helm installation:

```bash
helm repo add fylr https://programmfabrik.github.io/fylr-helm
```

If this step was successful, you should be able to search the repository for charts::

```bash
helm search repo fylr
```

The output should look like this:

```bash
NAME                            CHART VERSION   APP VERSION     DESCRIPTION
programmfabrik/execserver       0.1.1           v6.1.0-beta.8   A Helm chart for Kubernetes
programmfabrik/fylr             0.1.2           v6.1.0-beta.8   Deploy fylr to your Kubernetes cluster
```

More information about the charts can be found in the README.md files in the respective chart directories. To see the respective values you can either use `helm show values [chart]` or go to [fylr](https://programmfabrik.github.io/fylr-helm/charts/fylr/) and [execserver](https://programmfabrik.github.io/fylr-helm/charts/execserver/).

## Getting started (development)

Before you can start development, you need to install a few tools and set up a few things in your environment. The following instructions are for a *Linux* environment, but should be easily adaptable to other environments.

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

If the installation of the requirements was successful, you can now lint the charts. To do this, simply run `make lint-execserver` or `make lint-fylr`. This will color the chart and the value files.

### Testing

If the installation of the *ct* tool was successful, you can now test the charts. To do this, simply run `make test-execserver` or `make test-fylr`. This will install the chart in the current (`kubectl config current-context`) Kubernetes cluster and then delete it again.

### Install

To install the chart in the current Kubernetes cluster, simply run `make install-execserver` or `make install-fylr`. This will install the chart in the current (`kubectl config current-context`) Kubernetes cluster. Please note that the chart will not be uninstalled automatically. To uninstall the chart, please refer to [Uninstall](#uninstall).

### Uninstall

In order to uninstall the chart, simply run `make uninstall-execserver` or `make uninstall-fylr`. This will uninstall the chart in the current (`kubectl config current-context`) Kubernetes cluster.
