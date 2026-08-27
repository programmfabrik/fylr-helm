# fylr-helm

A Helm chart for the fylr application

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

------

## Continuous integration

`.github/workflows/chart-ci.yml` runs on every push that touches `charts/`,
`ci/` or the `Makefile`, and on pull requests against `main`.

### render

Lints both charts with `ct`, then renders each overlay in `ci/render-cases/`
and validates every manifest against the Kubernetes API schemas for two
Kubernetes versions. No cluster, about a minute. Reproduce it locally with
[helm](https://helm.sh) and [kubeconform](https://github.com/yannh/kubeconform)
installed:

```bash
make render-check
```

A case file is named `<chart>-<nn>-<slug>.yaml` and is a values overlay for
`charts/<chart>`. Add one whenever a combination of values ought to keep
working — an overlay costs a second and covers a shape nobody installs by hand.

### install and smoke

Installs `charts/fylr` on a single-node minikube cluster and drives the API:
authenticate, check the running version and external URL against the chart,
upload an image, wait for the execserver to produce its versions, and search.
`helm test` on its own only wgets a port, which a fylr that cannot reach its
database still answers.

`ci/values-ci.yaml` slims the stack to what a GitHub-hosted runner can hold —
a single postgres rather than `postgresql-ha`, one minio, smaller volumes — and
enables the three probes the chart ships switched off. Nothing in it changes
how fylr itself is configured.

To reproduce against your own cluster:

```bash
make ci-install
```

```bash
make ci-smoke
```

`ci-smoke` reads the ingress address from `minikube ip`; set `BASE` to override
it. The release must be called `testinstance`, because `values.yaml` hard-codes
the minio endpoint as `http://testinstance-minio:9000`.

```bash
make ci-uninstall
```
