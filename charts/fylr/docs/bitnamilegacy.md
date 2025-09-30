# Why other helm charts

To get you started, the fylr Helm chart includes dependencies to PostgreSQL and indexers (choose Elasticsearch or Opensearch).

You may want to replace these by standalone clusters. Or by more recent versions.

In any case, support is not provided by us, Programmfabrik GmbH, as we only support fylr. We still share some information to ease your start.

# Breaking changes

We were made aware that the mentioned Helm charts will have breaking changes by their developer, Bitnami, and want to share this with you:

At August 28th, 2025, Bitnami migrates its containers from the public catalog (docker.io/bitnami) to the “Bitnami Legacy” repository (docker.io/bitnamilegacy).

There is a lot more to this, see: https://github.com/bitnami/containers/issues/83267

Most crucially, to prevent your installation from being unable to find container images, you can adapt your values.yaml, as shown below.


# Using Bitnami legacy containers

Legacy container images will receive no security updates, so even they will have to be replaced in the future. But for now, they give some breathing room.


## PostgreSQL without high availability

For our test, it was enough to add the part below `[...]` to values.yaml:
```yaml
postgresql-ha:
  enabled: false

postgresql:
  enabled: true
[...]
  image:
    repository: bitnamilegacy/postgresql
  volumePermissions:
    image:
      repository: bitnamilegacy/os-shell
  metrics:
    image:
      repository: bitnamilegacy/postgres-exporter
  global:
    security:
      allowInsecureImages: true
```

This is taken from https://github.com/bitnami/containers/issues/83267

In case you need to add version tags, you can look up valid tags at https://hub.docker.com/u/bitnamilegacy.

## PostgreSQL with high availability

For our test, it was enough to add the part below `[...]` to values.yaml:
```yaml
postgresql:
  enabled: false

postgresql-ha:
  enabled: true
[...]
  image:
    repository: bitnamilegacy/postgresql-repmgr
  pgpool:
    image:
      repository: bitnamilegacy/pgpool
  metrics:
    image:
      repository: bitnamilegacy/postgres-exporter
  volumePermissions:
    image:
      repository: bitnamilegacy/os-shell
      tag: 12-debian-12-r49
  global:
    security:
      allowInsecureImages: true
```

In case you need to add version tags (like `12-debian-12-r49` above), you can look up valid tags at https://hub.docker.com/u/bitnamilegacy.

## ElasticSearch

For our test, it was enough to add the part below `[...]` to values.yaml:
```yaml
opensearch:
  enabled: false

elasticsearch:
  enabled: true
[...]
  image:
    repository: bitnamilegacy/elasticsearch
  metrics:
    image:
      repository: bitnamilegacy/elasticsearch-exporter
  volumePermissions:
    image:
      repository: bitnamilegacy/os-shell
      tag: 12-debian-12-r49
  sysctlImage:
    repository: bitnamilegacy/os-shell
    tag: 12-debian-12-r49
  global:
    security:
      allowInsecureImages: true
```

In case you need to add version tags (like `12-debian-12-r49` above), you can look up valid tags at https://hub.docker.com/u/bitnamilegacy.

## OpenSearch

For our test, it was enough to add the part below `[...]` to values.yaml:
```yaml
elasticsearch:
  enabled: false

opensearch:
  enabled: true
[...]
  image:
    repository: bitnamilegacy/opensearch
  dashboards:
    image:
      repository: bitnamilegacy/opensearch-dashboards
  volumePermissions:
    image:
      repository: bitnamilegacy/os-shell
      tag: 12-debian-12-r49
  sysctlImage:
    repository: bitnamilegacy/os-shell
    tag: 12-debian-12-r49
  snapshots:
    image:
      repository: bitnamilegacy/os-shell
      tag: 12-debian-12-r49
  global:
    security:
      allowInsecureImages: true
```

In case you need to add version tags (like `12-debian-12-r49` above), you can look up valid tags at https://hub.docker.com/u/bitnamilegacy.

