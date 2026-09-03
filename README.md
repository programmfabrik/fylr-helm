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
upload an image, wait for the execserver to produce its versions, ask the
execserver which services it offers, then create an objecttype that takes file
uploads, put an object in it holding that file, and search for it. `helm test`
on its own only wgets a port, which a fylr that cannot reach its database still
answers.

The object is the part that makes postgres, the execserver and opensearch prove
they work as one thing — it is the test a person does by hand in the frontend,
and it fails if any of the three is wired up wrong. The datamodel goes in as a
schema, a maskset and a commit, the order the product's own API tests use, and
`OBJECTTYPE` (default `smoke`) names it. An objecttype of that name already in
the datamodel is reused rather than replaced, so the test can be pointed at an
instance that is not empty.

The execserver check reads `/broker/status`, which reports the want-book the
execserver built from its config, and asserts every service named in
`charts/execserver/values.yaml` under `tests.validationServices` is in it. The
execserver is a ClusterIP service, so the script port-forwards to it — give it
`EXECSERVER_SVC` (with `NAMESPACE`) to do that, or `EXECSERVER_URL` if you have
another route. With neither it skips the step, which is what a release that
switches the execserver subchart off wants.

`ci/values-ci.yaml` slims the stack to what a GitHub-hosted runner can hold —
a single postgres rather than `postgresql-ha`, one minio, smaller volumes — and
enables the three probes the chart ships switched off. Nothing in it changes
how fylr itself is configured.

The job restarts fylr between installing and smoke testing. That is not
cosmetic: minio creates its bucket, its policy and the user fylr authenticates
as in `post-install` hooks, so none of them exist while the rest of the release
comes up, and fylr connects its storage locations once at startup without ever
retrying one that failed. A fresh install with the bundled minio therefore
always leaves the S3 location in `error`, and uploads fail until fylr is
restarted — with the chart's own values as much as with these.

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

### the whole thing on one machine

`test_local.sh` runs both jobs end to end against a throwaway minikube, so a
chart change can be tested without any live cluster:

```bash
./test_local.sh
```

About eight minutes cold, most of it pulling the fylr images. It needs `helm`,
`kubectl`, `minikube`, `kubeconform`, `jq`, `curl` and a docker it may talk to,
and nothing else — no helm repositories registered, no kubeconfig, no existing
minikube. A fresh clone on a fresh machine is the case it is written for.

Everything it creates outside the cluster goes into `/tmp/test_helm`: minikube's
home, the kubeconfig, kubectl's and helm's caches, helm's repository list. It
writes nothing into the clone, and your own `~/.minikube` and `~/.config/helm`
are neither read nor written, so the run cannot pick up a repository you happen
to have added — or leave one. The exception is `~/.kube`, which minikube writes
through its own bundled kubectl; the script deletes it afterwards if it created
it, and leaves it untouched if it was already there. Set `WORK` to move the
directory.

The cluster runs in its own minikube profile (`test-helm`) and is deleted
again when the run ends — on success, on failure, and on Ctrl-C — along with
`/tmp/test_helm` and the kicbase image. Nothing is left behind, and `git status`
is the check. A second run therefore pays the downloads again.

### looking at the instance in a browser

`KEEP=1 ./test_local.sh` leaves the cluster up, and the run prints the address:

```
browse it at http://157.90.34.54:9095 - log in as root / admin
```

minikube publishes the ingress on port 9095 of the machine itself, and fylr is
told that is its `externalURL`, so the address works from anywhere without an
ssh tunnel or an `/etc/hosts` entry. It has to agree exactly: a `Host` header
that differs from `fylr.externalURL` — a different port included — earns a 308
to the configured URL rather than a page. The Ingress rule therefore carries no
host at all, because Kubernetes rejects an IP address as an Ingress host.

The address is the one the machine reaches the internet with, as
`ip route get` reports it; reading `ip addr` instead would have to choose
between it and the docker and libvirt bridges. Override any part of it:

| | |
|---|---|
| `PUBLISH_PORT=9096` | a different port on the machine |
| `HOST_IP=10.0.0.5` | a different address of it |
| `EXTERNAL_URL=http://fylr.example.org:9095` | a name, if one resolves |

While a run is going, that port serves a fylr whose root password is `admin` to
anyone who can reach the machine. On a host with a public address, that is the
internet. Runs are minutes; a cluster held with `KEEP=1` is as long as you leave
it.

| | |
|---|---|
| `K8S=1.36.0 ./test_local.sh` | the other Kubernetes version in the matrix |
| `KEEP=1 ./test_local.sh` | leave the cluster up and browse it |
| `./test_local.sh clean` | tear down what an aborted run left |
