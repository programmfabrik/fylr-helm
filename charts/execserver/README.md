# execserver

part of fylr that processes assets, e.g. to generate previews

## deployment

If you do not deploy execserver as part of the fylr helm chart, but separately, then use this helm chart.

1. get [values.yaml](https://github.com/programmfabrik/fylr-helm/blob/main/charts/execserver/values.yaml)
2. change at least `- host: chart-example.local`
3. install via helm:
```
helm repo add programmfabrik https://programmfabrik.github.io/fylr-helm

helm install execserver-helm programmfabrik/execserver -f values.yaml --namespace=execserver-helm --create-namespace
```
