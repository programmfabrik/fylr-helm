# fylr

## Getting started

The following steps show how to install and run *fylr* on Kubernetes. You need access to an already existing Kubernetes cluster. You need Helm installed on your local machine where you execute the following commands. The following example also assumes that you have a working ingress controller installed, such as [nginx-ingress](https://kubernetes.github.io/ingress-nginx/deploy/), and that you have a domain name pointing to the ingress controller.

1. Add the fylr Helm repository:

```bash
helm repo add fylr https://programmfabrik.github.io/fylr-helm
```

2. Create a file `values.yaml` for fylr:

```yaml
ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
    nginx.ingress.kubernetes.io/enable-modsecurity: "false"
    nginx.ingress.kubernetes.io/proxy-request-buffering: "off"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "300"
  hosts:
  - host: fylr.example.com
    paths:
    - path: /
      pathType: ImplementationSpecific
  tls:
  - secretName: fylr-example-tls
    hosts:
      - fylr.example.com
fylr:
  externalURL: "https://fylr.example.com"
  persistent:
    defaults:
      originals: "disk1"
      versions: "disk1"
      backups: "disk1"
    definitions:
      disk1:
        kind: disk
        allowPurge: false
        disk:
          storageClass: "local-path"
          accessModes: ["ReadWriteOnce"]
          size: 10Gi
minio:
  enabled: false
postgresql-ha:
  enabled: true
  persistence:
    storageClass: local-path
elasticsearch:
  master:
    persistence:
      storageClass: local-path
  data:
    persistence:
      storageClass: local-path
```

You may want to replace all strings with example, local-path and letsencrypt.

3. Install the fylr Helm chart:

```bash
export NAMESPACE=fylr
export RELEASE_NAME=fylr

helm install ${RELEASE_NAME} fylr/fylr \
    --namespace ${NAMESPACE} \
    --create-namespace \
    -f values.yaml
```

## Good to know

### Storage locations known bug

Known Bug: Locations are only created if they are present in at least one of the three lines below `defaults:` (`originals:`, `versions:`, `backups:`), so it is currently not enough to just define them below `definitions:`, you also have to use them in the `defaults:` mapping.

### Storage and fylr replicas

If you use ReadWriteOnce volumes, as in the example above, then these cannot be shared among multiple fylr replicas and thus you can only use one fylr replica (per fylr instance, so for example per customer). For more than one replica you need to either find a solution with ReadWriteMany volumes or, what fylr was designed for, s3 storage:

### s3 storage

You may place assets and backups into e.g. amazon s3 instead of kubernetes volumes, by replacing the persistent part in the values.yaml above with:

```yaml
  persistent:
    defaults:
      originals: "s3"
      versions: "s3"
      backups: "s3"
    definitions:
      s3:
        kind: "s3"
        allowPurge: false
        s3:
          path: ""
          bucket: "fylr"
          endpoint: "s3.amazonaws.com"
          accessKey: "awss3accesskey"
          secretKey: "awss3secretkey"
          region: "us-east-1"
          useSSL: true
          allowRedirect: true
```

Note: fylr does not create the bucket.

### Persistent Volumes

Depending on your configuration, you can deploy fylr with a persistent volume. If you do this, these volumes are created once and are not deleted when you uninstall fylr. If you want to delete the volumes, you must do so manually.

### Secrets

- `<deployment-name>-fylr-oauth2`
- `<deployment-name>-fylr-utils`

These two secrets are used by the fylr installation to sign, encrypt, and configure the OAuth2 client and server. The values are generated during installation and are not updated during upgrades or deleted during uninstallation. If you want to change the values, you must adjust them manually.

So if you want to know the secret to connect as "web-client", the default OAuth2 clientID:

Get the secret name:

```bash
kubectl -n ${NAMESPACE} get secrets
```

Choose the secret name ending in `-fylr-oauth2`. For this example, we assume the name is `example-fylr-oauth2`.

```bash
kubectl -n ${NAMESPACE} get secrets example-fylr-oauth2 -o go-template={{.data.oauth2WebappClientSecret}} | base64 -d;echo
```

## Configuration

The link below contains a table of the configurable parameters and their default values.

See: https://programmfabrik.github.io/fylr-helm/charts/fylr/

## Troubleshooting

Such messages can be safely ignored:
> could not obtain lock on row in relation

> WRN Error occurred in NewIntrospectionRequest error=request_unauthorized Env=api

> WRN Accepting token failed error

In case of problems, also try to allocate more resources via:
* [replicaCount](https://github.com/programmfabrik/fylr-helm/blob/fylr-0.1.11/charts/fylr/values.yaml#L5)
* [maxOpenConns](https://github.com/programmfabrik/fylr-helm/blob/fylr-0.1.11/charts/fylr/values.yaml#L255)
