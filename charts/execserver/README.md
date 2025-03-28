# execserver

![Version: 0.1.72](https://img.shields.io/badge/Version-0.1.72-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: v6.19.0](https://img.shields.io/badge/AppVersion-v6.19.0-informational?style=flat-square)

A Helm chart for fylr as execserver in Kubernetes

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| programmfabrik | <support@programmfabrik.de> | <https://programmfabrik.de> |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | The affinity settings to use. See https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity |
| autoscaling.enabled | bool | `false` | Whether to create an HorizontalPodAutoscaler resource |
| autoscaling.maxReplicas | int | `5` | The maximum number of replicas |
| autoscaling.minReplicas | int | `1` | The minimum number of replicas |
| autoscaling.targetCPUUtilizationPercentage | int | `80` | The target CPU utilization percentage |
| extraEnvVars | list | `[]` | extra environment variables |
| fullnameOverride | string | `""` |  |
| fylr | object | `{"execserver":{"waitGroups":{"fast":8,"medium":6,"slow":2}},"logger":{"addHostname":true,"format":"console","level":"info","noColor":false,"timeFormat":"2006-01-02T15:04:05Z07:00"}}` | Application configuration |
| fylr.execserver | object | `{"waitGroups":{"fast":8,"medium":6,"slow":2}}` | Settings related to the execserver |
| fylr.execserver.waitGroups | object | `{"fast":8,"medium":6,"slow":2}` | Parallelism of the execserver define several groups with a different number of jobs running in parallel we expect a map[string]int |
| fylr.logger | object | `{"addHostname":true,"format":"console","level":"info","noColor":false,"timeFormat":"2006-01-02T15:04:05Z07:00"}` | Log settings |
| fylr.logger.addHostname | bool | `true` | add hostname to log output |
| fylr.logger.format | string | `"console"` | Set to "json" or "console". Default: "console" |
| fylr.logger.level | string | `"info"` | Set zerolog log level: trace, debug, info, warn, error, fatal, panic default to "info". |
| fylr.logger.noColor | bool | `false` | turn off color for zerolog's underlying ConsoleWriter format: "console" only. |
| fylr.logger.timeFormat | string | `"2006-01-02T15:04:05Z07:00"` | timeFormat is the Go representation to format the time in the log output. zerolog's time keeping resolution is always set to milliseconds by FYLR. Use "", "UNIXMS" or "UNIXMICRO" to output a unix timestamp (json format only). Defaults to "" |
| image | object | `{"pullPolicy":"IfNotPresent","repository":"docker.fylr.io/fylr/fylr"}` | The image to use for the execserver |
| image.pullPolicy | string | `"IfNotPresent"` | The image pull policy. See https://kubernetes.io/docs/concepts/containers/images/#updating-images |
| image.repository | string | `"docker.fylr.io/fylr/fylr"` | The image repository |
| imagePullSecrets | list | `[]` | Pull secrets for the image. Useful for private registries. See https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/ |
| ingress | object | `{"annotations":{},"className":"","enabled":false,"hosts":[{"host":"chart-example.local","paths":[{"path":"/","pathType":"ImplementationSpecific"}]}],"tls":[]}` | Ingress configuration |
| ingress.annotations | object | `{}` | The annotations of the ingress |
| ingress.className | string | `""` | The class of the ingress |
| ingress.enabled | bool | `false` | Enable ingress |
| ingress.hosts | list | `[{"host":"chart-example.local","paths":[{"path":"/","pathType":"ImplementationSpecific"}]}]` | The list of hosts to expose |
| ingress.tls | list | `[]` | The list of TLS secrets |
| monitoring | object | `{"pod":{"enabled":false,"interval":"30s"},"service":{"enabled":false,"interval":"30s"}}` | Whether to configure monitoring for the application |
| monitoring.pod | object | `{"enabled":false,"interval":"30s"}` | Whether to create a PodMonitor resource for Prometheus Operator |
| monitoring.pod.enabled | bool | `false` | Enable pod monitor |
| monitoring.pod.interval | string | `"30s"` | The interval at which metrics should be scraped |
| monitoring.service | object | `{"enabled":false,"interval":"30s"}` | Whether to create a ServiceMonitor resource for Prometheus Operator |
| monitoring.service.enabled | bool | `false` | Enable service monitor |
| monitoring.service.interval | string | `"30s"` | The interval at which metrics should be scraped |
| nameOverride | string | `""` |  |
| nodeSelector | object | `{}` | The node selector settings to use. See https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#nodeselector |
| persistent | object | `{"tmp":{"accessModes":["ReadWriteOnce"],"enabled":false,"size":"20Gi","storageClass":""}}` | defines the storage settings in case /tmp needs to be keept across redeploy |
| persistent.tmp | object | `{"accessModes":["ReadWriteOnce"],"enabled":false,"size":"20Gi","storageClass":""}` | To make the /tmp fylr dir persistent across redeploy |
| persistent.tmp.enabled | bool | `false` | Wether to enable persistance for tmp dir or not |
| persistent.tmp.size | string | `"20Gi"` | size is the size of the disk to be claimed and used by fylr tmp dir. |
| persistent.tmp.storageClass | string | `""` | storageClass is the storage class of the file system. Check your kubernetes infrastructure for the available storage classes. |
| podAnnotations | object | `{}` | Pod annotations to add to the deployment. |
| podSecurityContext | object | `{}` | Pod Security Context. See https://kubernetes.io/docs/tasks/configure-pod-container/security-context/ |
| replicaCount | int | `1` |  |
| resources | object | `{}` | The resources to allocate to the pod |
| securityContext | object | `{}` |  |
| service.port | int | `8070` | The port on which to expose the service |
| service.type | string | `"ClusterIP"` | The type of service to create |
| serviceAccount | object | `{"annotations":{},"create":true,"name":""}` | Service account to be used by the pod |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.create | bool | `true` | Specifies whether a service account should be created |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template |
| tolerations | list | `[]` | The tolerations settings to use. See https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/ |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
