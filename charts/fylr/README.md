# fylr

## Getting started

The following instructions show you how to install and run *fylr* on your Kubernetes cluster. For these steps, you must have access to a Kubernetes cluster and have Helm installed. The following example also assumes that you have a working ingress controller installed, such as [nginx-ingress](https://kubernetes.github.io/ingress-nginx/deploy/), and that you have a domain name pointing to the ingress controller. In addition, we assume that you have access to an S3-compatible object storage provider and have created a bucket for fylr. The following steps will guide you through the installation of fylr.

1. Add the fylr Helm repository:

```bash
helm repo add fylr https://programmfabrik.github.io/fylr-helm
```

2. Create a values file for fylr:

```bash
export RELEASE_NAME=fylr
export DOMAIN=fylr.mydomain.com
export STORAGE_CLASS=local-path

cat <<EOF > values.yaml
ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
  hosts:
  - host: ${DOMAIN}
    paths:
    - path: /
      pathType: ImplementationSpecific
  tls:
  - secretName: chart-example-tls
    hosts:
      - ${DOMAIN}
fylr:
  externalURL: https://${DOMAIN}
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
minio:
  enabled: false
postgresql-ha:
  enabled: true
  persistence:
    storageClass: ${STORAGE_CLASS}
elasticsearch:
  master:
    persistence:
      storageClass: ${STORAGE_CLASS}
  data:
    persistence:
      storageClass: ${STORAGE_CLASS}
EOF
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

## Good to know

### Secrets

- `<deployment-name>-fylr-oauth2`
- `<deployment-name>-fylr-utils`

These two secrets are used by the fylr installation to sign, encrypt, and configure the OAuth2 client and server. The values are generated during installation and are not updated during upgrades or deleted during uninstallation. If you want to change the values, you must adjust them manually.

So if you want to know the secret to connect as "webclient", the default clientID:

```bash
kubectl -n ${NAMESPACE} get secrets REPLACE_ME-fylr-oauth2 -o go-template={{.data.oauth2WebappClientSecret}} | base64 -d;echo
```

To get the secret name:

```bash
kubectl -n ${NAMESPACE} get secrets
```

Choose the scret name ending in `-fylr-oauth2`

### Persistent Volumes

Depending on your configuration, you can deploy fylr with a persistent volume. If you do this, these volumes are created once and are not deleted when you uninstall fylr. If you want to delete the volumes, you must do so manually.

## Configuration

The link below contains a table of the configurable parameters of the fylr diagram and their default values.

See: https://programmfabrik.github.io/fylr-helm/charts/fylr/
