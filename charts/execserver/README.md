# fylr execserver

The following examples show how to install and run *execserver* on Kubernetes. You need access to an already existing Kubernetes cluster. You need Helm installed on your local machine where you execute the following commands.

This chart can either be used stand-alone (execservers used my multiple fylr instances)

or as a dependecy of the fylr helm chart (execservers for one fylr instance).

## As a dependecy of the fylr helm chart


1. Add the fylr Helm repository:

```bash
helm repo add fylr https://programmfabrik.github.io/fylr-helm
```

2. Create a file `values.yaml` for fylr:

This helmchart is then configured in the `execserver:`-part of values.yaml:


```yaml
ingress:
[...]

fylr:
[...]

execserver:
  enabled: true
  fylr:
    logger:
      level: debug
    execserver:
      waitGroups:
        slow: 2
        medium: 6
        fast: 10

minio:
[...]

elasticsearch:
[...]

postgresql-ha:
[...]

postgresql:
[...]
```

3. Install the fylr Helm chart:

```bash
export NAMESPACE=fylr
export RELEASE_NAME=fylr

helm install ${RELEASE_NAME} fylr/fylr \
    --namespace ${NAMESPACE} \
    --create-namespace \
    -f values.yaml
```

## As stand alone execserver

1. Add the fylr Helm repository:

```bash
helm repo add fylr https://programmfabrik.github.io/fylr-helm
```

2. Create a file `values.yaml` for fylr:

```yaml
fylr:
  #logger:
    #level: debug
  execserver:
    waitGroups:
      slow: 2
      medium: 6
      fast: 10
```

3. Install the fylr Helm chart:

```bash
export NAMESPACE=fylr
export RELEASE_NAME=fylr

helm install ${RELEASE_NAME} fylr/execserver \
    --namespace ${NAMESPACE} \
    --create-namespace \
    -f values.yaml
```

## separate plugin executions to separate waitgroups

To not mix asset processing with plugin execution in the same waitgroups, put into `values.yaml`:

```yaml
fylr:
  #logger:
    #level: debug
  execserver:
    waitGroups:
      slow: 2
      medium: 6
      fast: 10
      binaries: 4
      nodeplugins: 4
      pythonplugins: 4
    services:
      exec:
        waitgroup: binaries
      python3:
        waitgroup: pythonplugins
      node:
        waitgroup: nodeplugins
```
Now, in comparison to the defaults, three new waitgroups are created: binaries, pythonplugins, nodeplugins.

## set imagemagick limits for execserver jobs

To limit each ImageMagick process to 0.5 GB RAM, 5 GB temporary storage and to make ImageMagick use fylr's directory structure for execserver jobs, put into `values.yaml`:

```yaml
fylr:
  services:
    execserver:
      env:
        - MAGICK_MEMORY_LIMIT=512MiB
        - MAGICK_MAP_LIMIT=512MiB
        - MAGICK_DISK_LIMIT=5GiB
        - MAGICK_TEMPORARY_PATH=.
  execserver:
    # just an example, see explanation below
    parallel: 2

```

As fylr.execerver.parallel is 2, one pod might use double the RAM and storage of the above limit for asset processing.

