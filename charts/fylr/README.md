# fylr

![Version: 0.1.122](https://img.shields.io/badge/Version-0.1.122-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: v6.14.0](https://img.shields.io/badge/AppVersion-v6.14.0-informational?style=flat-square)

Deploy fylr to your Kubernetes cluster

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| programmfabrik | <support@programmfabrik.de> | <https://programmfabrik.de> |

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://charts.bitnami.com/bitnami | elasticsearch | 19.5.0 |
| https://charts.bitnami.com/bitnami | opensearch | 1.2.6 |
| https://charts.bitnami.com/bitnami | postgresql | 12.1.0 |
| https://charts.bitnami.com/bitnami | postgresql-ha | 10.0.1 |
| https://charts.min.io/ | minio | 4.0.14 |
| https://programmfabrik.github.io/fylr-helm | execserver | 0.1.60 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| autoscaling.enabled | bool | `false` |  |
| autoscaling.maxReplicas | int | `100` |  |
| autoscaling.minReplicas | int | `1` |  |
| autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| extraEnvVars | list | `[]` |  |
| extraVolumeMounts | list | `[]` |  |
| extraVolumes | list | `[]` |  |
| fullnameOverride | string | `""` |  |
| fylr.allowPurge | bool | `true` |  |
| fylr.configAsConfigmap | string | `""` | Optionnaly provides additional configmap having fylr config to be merged with the config file made out of the values provided here, the configmap needs to be present in the same namespace as the helm release |
| fylr.db | object | `{"driver":"postgres","init":{"email":{"from":""},"email_server":{"cram_md5_auth":{"password":"","username":""},"helo_domain":"","insecure_skip_verify":false,"login_auth":{"password":"","username":""},"plain_auth":{"password":"","username":""},"server_addr":"","type":"starttls"}},"maxIdleConns":10,"maxOpenConns":100,"postgres":{"database":"fylr","host":"localhost","options":{},"password":"password","port":5432,"sslmode":"disable","user":"fylr"}}` | defines database settings |
| fylr.db.driver | string | `"postgres"` | driver defines the driver for the database server. NOTE: this is ignored if postgresql-ha.enabled is set to true. |
| fylr.db.init | object | `{"email":{"from":""},"email_server":{"cram_md5_auth":{"password":"","username":""},"helo_domain":"","insecure_skip_verify":false,"login_auth":{"password":"","username":""},"plain_auth":{"password":"","username":""},"server_addr":"","type":"starttls"}}` | The init block is used to pre-fill the database when its created or purged. |
| fylr.db.maxIdleConns | int | `10` | maxIdleConns has to be not more than maxOpenConns https://golang.org/pkg/database/sql/#DB.SetMaxIdleConns, default: 0 |
| fylr.db.maxOpenConns | int | `100` | This has to be at 4 + execserver.parallel + elastic.parallel. Two of these connections will be dedicated to a separate connection pool managing the sequences (Postgres only) https://golang.org/pkg/database/sql/#DB.SetMaxOpenConns, default: 0 |
| fylr.db.postgres | object | `{"database":"fylr","host":"localhost","options":{},"password":"password","port":5432,"sslmode":"disable","user":"fylr"}` | postgresql connection settings NOTE: this is ignored if postgresql-ha.enabled is set to true. |
| fylr.db.postgres.database | string | `"fylr"` | database is the database to use for the postgres connection. |
| fylr.db.postgres.host | string | `"localhost"` | host is the host of the postgres server. |
| fylr.db.postgres.options | object | `{}` | options is a map of additional options to be passed to the database connection string. See https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-PARAMKEYWORDS |
| fylr.db.postgres.password | string | `"password"` | password is the password to use for the postgres connection. |
| fylr.db.postgres.port | int | `5432` | port is the port of the postgres server. |
| fylr.db.postgres.sslmode | string | `"disable"` | sslmode is the sslmode to use for the postgres connection. |
| fylr.db.postgres.user | string | `"fylr"` | user is the user to use for the postgres connection. |
| fylr.debug.easDownloadSkipCheckRights | bool | `false` |  |
| fylr.elastic.addresses | list | `["http://localhost:9200"]` | addresses of the elastic servers NOTE: This is ignored if elasticsearch.enabled is set to true. |
| fylr.elastic.fielddata | bool | `false` | fielddata (debug feature). if set to true, fields are mapped including their fielddata in the reverse index. with that, the inspect view of the indexed version of the object shows a per field list of stored terms. This can be useful for debugging of analyzer settings. |
| fylr.elastic.logger | string | `""` | logger used for the elastic client "Text": TextLogger prints the log message in plain text. "Color": ColorLogger prints the log message in a terminal-optimized plain text. "Curl": CurlLogger prints the log message as a runnable curl command. "JSON": JSONLogger prints the log message as JSON. |
| fylr.elastic.maxMem | string | `"100mb"` | limit of payloads sent to Elastic |
| fylr.elastic.objectsPerJob | int | `100` | number of objects per job passed to the indexer process |
| fylr.elastic.parallel | int | `4` | number of parallel workers to index documents, default to 1, set to 0 to disable |
| fylr.elastic.password | string | `""` | password for the elastic server NOTE: This is ignored if elasticsearch.enabled is set to true. |
| fylr.elastic.settings | string | `""` | Where to find the Elastic search index settings. If you provide your own file make sure to base it on the default resources/index/index_settings.json which is included in the distribution. |
| fylr.elastic.username | string | `""` | username for the elastic server NOTE: This is ignored if elasticsearch.enabled is set to true. |
| fylr.execserver | object | `{"addresses":[],"connectTimeoutSec":120,"parallel":4,"pluginJobTimeoutSec":2400}` | defines the settings for the execserver connection |
| fylr.execserver.addresses | list | `[]` | addresses represents a list of execserver services. If execserver.enabled is set to true, this option will be ignored. We expect the url in the format of "http://localhost:8080". # NOTE: This is merged with the execserver service address provided by the execserver helm chart, if execserver.enabled is set to true. |
| fylr.execserver.connectTimeoutSec | int | `120` | connectTimeout sets the maximum seconds the server will wait until a worker gets a job. Defaults to 120 seconds. |
| fylr.execserver.parallel | int | `4` | number of parallel file workers, default to 1, set to 0 to disable |
| fylr.execserver.pluginJobTimeoutSec | int | `2400` | pluginJobTimeoutSec sets the maximum seconds a callback is allowed to run. Defaults to 2400 seconds. |
| fylr.externalURL | string | `"http://localhost"` | public external url of the server. This url needs to be fully qualified |
| fylr.license | multi string | `""` | set fylr license, start by a | to define multi string |
| fylr.livenessProbe.enabled | bool | `false` |  |
| fylr.livenessProbe.failureThreshold | int | `11` |  |
| fylr.livenessProbe.initialDelaySeconds | int | `1` |  |
| fylr.livenessProbe.periodSeconds | int | `30` |  |
| fylr.livenessProbe.successThreshold | int | `1` |  |
| fylr.livenessProbe.timeoutSeconds | int | `5` |  |
| fylr.logger | object | `{"addHostname":true,"format":"console","level":"info","noColor":false,"timeFormat":"2006-01-02 15:04:05 -07:00"}` | settings related to the logging |
| fylr.logger.addHostname | bool | `true` | addHostname adds the hostname to the logs. |
| fylr.logger.format | string | `"console"` | format is the format of the logs. Valid values are "json" and "console". |
| fylr.logger.level | string | `"info"` | level is the minimum level of logs to be logged. Valid values are "trace", "debug", "info", "warn", "error", "fatal", "panic". |
| fylr.logger.noColor | bool | `false` | noColor disables colorized output. |
| fylr.logger.timeFormat | string | `"2006-01-02 15:04:05 -07:00"` | timeFormat is the Go representation to format the time in the log output. zerolog's time keeping resolution is always set to milliseconds by FYLR. Use "", "UNIXMS" or "UNIXMICRO" to output a unix timestamp (json format only). Defaults to "2006-01-02 15:04:05" |
| fylr.persistent | object | `{"defaults":{"backups":"s3","originals":"s3","versions":"s3"},"definitions":{"s3":{"allowPurge":false,"kind":"s3","s3":{"accessKey":"fylr","allowRedirect":false,"bucket":"fylr","endpoint":"http://testinstance-minio:9000","path":"","region":"us-east-1","secretKey":"fylrsecret123","useSSL":false}}},"tmp":{"accessModes":["ReadWriteMany"],"enabled":false,"size":"30Gi","storageClass":""},"webDAVHotfolder":{"accessModes":["ReadWriteMany"],"enabled":false,"size":"30Gi","storageClass":""}}` | defines the storage settings required for the persistence of data (e.g. files, backups, etc.) |
| fylr.persistent.defaults | object | `{"backups":"s3","originals":"s3","versions":"s3"}` | defines the persistent storage definitions for the server |
| fylr.persistent.defaults.backups | string | `"s3"` | the storage definition for backups The value is a reference to a storage definition in the storage fylr.persistent.definitions section. |
| fylr.persistent.defaults.originals | string | `"s3"` | the storage definition for originals The value is a reference to a storage definition in the storage fylr.persistent.definitions section. |
| fylr.persistent.defaults.versions | string | `"s3"` | the storage definition for versions The value is a reference to a storage definition in the storage fylr.persistent.definitions section. |
| fylr.persistent.definitions | object | `{"s3":{"allowPurge":false,"kind":"s3","s3":{"accessKey":"fylr","allowRedirect":false,"bucket":"fylr","endpoint":"http://testinstance-minio:9000","path":"","region":"us-east-1","secretKey":"fylrsecret123","useSSL":false}}}` | the storage definitions We expect at least one storage definition to be defined. |
| fylr.persistent.definitions.s3 | object | `{"allowPurge":false,"kind":"s3","s3":{"accessKey":"fylr","allowRedirect":false,"bucket":"fylr","endpoint":"http://testinstance-minio:9000","path":"","region":"us-east-1","secretKey":"fylrsecret123","useSSL":false}}` | a storage definition referenced by the `fylr.persistent.defaults` values |
| fylr.persistent.definitions.s3.allowPurge | bool | `false` | allow fylr to purge files from the disk. This is a dangerous setting and should be used for development purposes only. |
| fylr.persistent.definitions.s3.kind | string | `"s3"` | kind is the kind of the storage. Valid values are "s3" and "disk". |
| fylr.persistent.definitions.s3.s3 | object | `{"accessKey":"fylr","allowRedirect":false,"bucket":"fylr","endpoint":"http://testinstance-minio:9000","path":"","region":"us-east-1","secretKey":"fylrsecret123","useSSL":false}` | s3 is the configuration for the s3 storage. |
| fylr.persistent.definitions.s3.s3.accessKey | string | `"fylr"` | accessKey is the access key to use. |
| fylr.persistent.definitions.s3.s3.allowRedirect | string | `false` | allowRedirect specifies whether we expose s3 urls to the outside world. If you are using the included minio server, this should be set to false. For public s3 providers like AWS, this should be set to true. |
| fylr.persistent.definitions.s3.s3.bucket | string | `"fylr"` | bucket is the name of the bucket to use. |
| fylr.persistent.definitions.s3.s3.endpoint | string | `"http://testinstance-minio:9000"` | endpoint is the endpoint of the s3 server. If you are using the included minio server, this should be set to "http://<deployment-name>-minio.<namespace>.svc:9000" |
| fylr.persistent.definitions.s3.s3.path | string | `""` | path represents the path in the s3 bucket. |
| fylr.persistent.definitions.s3.s3.region | string | `"us-east-1"` | region is the region of the s3 server. |
| fylr.persistent.definitions.s3.s3.secretKey | string | `"fylrsecret123"` | secretKey is the secret key to use. |
| fylr.persistent.definitions.s3.s3.useSSL | string | `false` | useSSL enables SSL for the s3 connection. |
| fylr.persistent.tmp | object | `{"accessModes":["ReadWriteMany"],"enabled":false,"size":"30Gi","storageClass":""}` | To make the /tmp fylr dir persistent across redeploy |
| fylr.persistent.tmp.enabled | bool | `false` | Wether to enable persistance for tmp dir or not |
| fylr.persistent.tmp.size | string | `"30Gi"` | size is the size of the disk to be claimed and used by fylr tmp dir. |
| fylr.persistent.tmp.storageClass | string | `""` | storageClass is the storage class of the file system. Check your kubernetes infrastructure for the available storage classes. |
| fylr.persistent.webDAVHotfolder.size | string | `"30Gi"` | size is the size of the disk to be claimed and used by fylr tmp dir. |
| fylr.persistent.webDAVHotfolder.storageClass | string | `""` | storageClass is the storage class of the file system. Check your kubernetes infrastructure for the available storage classes. |
| fylr.plugin | object | `{"defaults":{"easydb-connector-plugin":{"enabled":false,"update":"never"}},"paths":["/fylr/files/plugins/easydb/easydb-barcode-display-pdf-plugin","/fylr/files/plugins/easydb/easydb-barcode-display-plugin","/fylr/files/plugins/easydb/easydb-basemigration-plugin","/fylr/files/plugins/easydb/easydb-coin-viewer-plugin","/fylr/files/plugins/easydb/easydb-connector-plugin","/fylr/files/plugins/easydb/easydb-custom-data-type-cerlthesaurus","/fylr/files/plugins/easydb/easydb-custom-data-type-gazetteer","/fylr/files/plugins/easydb/easydb-custom-data-type-geonames","/fylr/files/plugins/easydb/easydb-custom-data-type-georef","/fylr/files/plugins/easydb/easydb-custom-data-type-gn250","/fylr/files/plugins/easydb/easydb-custom-data-type-gnd","/fylr/files/plugins/easydb/easydb-custom-data-type-goobi","/fylr/files/plugins/easydb/easydb-custom-data-type-html-editor","/fylr/files/plugins/easydb/easydb-custom-data-type-iconclass","/fylr/files/plugins/easydb/easydb-custom-data-type-iucn","/fylr/files/plugins/easydb/easydb-custom-data-type-link","/fylr/files/plugins/easydb/easydb-custom-data-type-location","/fylr/files/plugins/easydb/easydb-custom-data-type-nomisma","/fylr/files/plugins/easydb/easydb-custom-data-type-tnadiscovery","/fylr/files/plugins/easydb/easydb-custom-mask-splitter-detail-linked-plugin","/fylr/files/plugins/easydb/easydb-detail-map-plugin","/fylr/files/plugins/easydb/easydb-display-field-values-plugin","/fylr/files/plugins/easydb/easydb-drupal-plugin","/fylr/files/plugins/easydb/easydb-easydb4migration-plugin","/fylr/files/plugins/easydb/easydb-editor-tagfilter-defaults-plugin","/fylr/files/plugins/easydb/easydb-eventmanager-plugin","/fylr/files/plugins/easydb/easydb-export-transport-ftp-plugin","/fylr/files/plugins/easydb/easydb-falconio-plugin","/fylr/files/plugins/easydb/easydb-hijri-gregorian-converter-plugin","/fylr/files/plugins/easydb/easydb-orcid-plugin","/fylr/files/plugins/easydb/easydb-pdf-creator-plugin","/fylr/files/plugins/easydb/easydb-presentation-pptx-plugin","/fylr/files/plugins/easydb/easydb-remote-plugin","/fylr/files/plugins/easydb/easydb-typo3-plugin","/fylr/files/plugins/easydb/easydb-wordpress-plugin"]}` | defines plugin settings |
| fylr.plugin.defaults | object | `{"easydb-connector-plugin":{"enabled":false,"update":"never"}}` | explicitly defines settings for the plugin with the given name. |
| fylr.plugin.defaults.easydb-connector-plugin | object | `{"enabled":false,"update":"never"}` | a plugin to be configured (by name) |
| fylr.plugin.defaults.easydb-connector-plugin.enabled | bool | `false` | enable, set to false to disable the plugin, defaults to true |
| fylr.plugin.defaults.easydb-connector-plugin.update | string | `"never"` | update_policy: automatic, always, never, defaults to automatic |
| fylr.plugin.paths | list | `["/fylr/files/plugins/easydb/easydb-barcode-display-pdf-plugin","/fylr/files/plugins/easydb/easydb-barcode-display-plugin","/fylr/files/plugins/easydb/easydb-basemigration-plugin","/fylr/files/plugins/easydb/easydb-coin-viewer-plugin","/fylr/files/plugins/easydb/easydb-connector-plugin","/fylr/files/plugins/easydb/easydb-custom-data-type-cerlthesaurus","/fylr/files/plugins/easydb/easydb-custom-data-type-gazetteer","/fylr/files/plugins/easydb/easydb-custom-data-type-geonames","/fylr/files/plugins/easydb/easydb-custom-data-type-georef","/fylr/files/plugins/easydb/easydb-custom-data-type-gn250","/fylr/files/plugins/easydb/easydb-custom-data-type-gnd","/fylr/files/plugins/easydb/easydb-custom-data-type-goobi","/fylr/files/plugins/easydb/easydb-custom-data-type-html-editor","/fylr/files/plugins/easydb/easydb-custom-data-type-iconclass","/fylr/files/plugins/easydb/easydb-custom-data-type-iucn","/fylr/files/plugins/easydb/easydb-custom-data-type-link","/fylr/files/plugins/easydb/easydb-custom-data-type-location","/fylr/files/plugins/easydb/easydb-custom-data-type-nomisma","/fylr/files/plugins/easydb/easydb-custom-data-type-tnadiscovery","/fylr/files/plugins/easydb/easydb-custom-mask-splitter-detail-linked-plugin","/fylr/files/plugins/easydb/easydb-detail-map-plugin","/fylr/files/plugins/easydb/easydb-display-field-values-plugin","/fylr/files/plugins/easydb/easydb-drupal-plugin","/fylr/files/plugins/easydb/easydb-easydb4migration-plugin","/fylr/files/plugins/easydb/easydb-editor-tagfilter-defaults-plugin","/fylr/files/plugins/easydb/easydb-eventmanager-plugin","/fylr/files/plugins/easydb/easydb-export-transport-ftp-plugin","/fylr/files/plugins/easydb/easydb-falconio-plugin","/fylr/files/plugins/easydb/easydb-hijri-gregorian-converter-plugin","/fylr/files/plugins/easydb/easydb-orcid-plugin","/fylr/files/plugins/easydb/easydb-pdf-creator-plugin","/fylr/files/plugins/easydb/easydb-presentation-pptx-plugin","/fylr/files/plugins/easydb/easydb-remote-plugin","/fylr/files/plugins/easydb/easydb-typo3-plugin","/fylr/files/plugins/easydb/easydb-wordpress-plugin"]` | paths is a list of paths to search for plugins. Defaults to the plugins directories for easydb and fylr. |
| fylr.readinessProbe.enabled | bool | `false` |  |
| fylr.readinessProbe.failureThreshold | int | `11` |  |
| fylr.readinessProbe.initialDelaySeconds | int | `1` |  |
| fylr.readinessProbe.periodSeconds | int | `30` |  |
| fylr.readinessProbe.successThreshold | int | `1` |  |
| fylr.readinessProbe.timeoutSeconds | int | `5` |  |
| fylr.services | object | `{"api":{"oauth2Server":{"allowHttpRedirects":true,"clients":{"ci-hub":{"public":true,"redirectURIs":["https://ci-hub.azurewebsites.net/api/v1/auth/login/fylr","https://ci-hub-beta.azurewebsites.net/api/v1/auth/login/fylr","https://ci-hub-test.azurewebsites.net/api/v1/auth/login/fylr","http://localhost:8080/api/v1/auth/login/fylr"],"scopes":["read","write","offline"]},"fylr-mobile-app":{"public":true,"redirectURIs":["fylr.app.scheme:///"],"scopes":["read","write","offline"]},"santa-cruz":{"public":true,"redirectURIs":["https://fylr.linkrui.com/oauth","https://stage-fylr.linkrui.com/oauth"],"scopes":["read","write","offline"]}}}},"webapp":{"basicAuth":{}}}` | defines settings for services that fylr should start. |
| fylr.services.api | object | `{"oauth2Server":{"allowHttpRedirects":true,"clients":{"ci-hub":{"public":true,"redirectURIs":["https://ci-hub.azurewebsites.net/api/v1/auth/login/fylr","https://ci-hub-beta.azurewebsites.net/api/v1/auth/login/fylr","https://ci-hub-test.azurewebsites.net/api/v1/auth/login/fylr","http://localhost:8080/api/v1/auth/login/fylr"],"scopes":["read","write","offline"]},"fylr-mobile-app":{"public":true,"redirectURIs":["fylr.app.scheme:///"],"scopes":["read","write","offline"]},"santa-cruz":{"public":true,"redirectURIs":["https://fylr.linkrui.com/oauth","https://stage-fylr.linkrui.com/oauth"],"scopes":["read","write","offline"]}}}}` | define settings for the api service |
| fylr.services.api.oauth2Server | object | `{"allowHttpRedirects":true,"clients":{"ci-hub":{"public":true,"redirectURIs":["https://ci-hub.azurewebsites.net/api/v1/auth/login/fylr","https://ci-hub-beta.azurewebsites.net/api/v1/auth/login/fylr","https://ci-hub-test.azurewebsites.net/api/v1/auth/login/fylr","http://localhost:8080/api/v1/auth/login/fylr"],"scopes":["read","write","offline"]},"fylr-mobile-app":{"public":true,"redirectURIs":["fylr.app.scheme:///"],"scopes":["read","write","offline"]},"santa-cruz":{"public":true,"redirectURIs":["https://fylr.linkrui.com/oauth","https://stage-fylr.linkrui.com/oauth"],"scopes":["read","write","offline"]}}}` | configures oauth2 related settings |
| fylr.services.api.oauth2Server.clients | object | `{"ci-hub":{"public":true,"redirectURIs":["https://ci-hub.azurewebsites.net/api/v1/auth/login/fylr","https://ci-hub-beta.azurewebsites.net/api/v1/auth/login/fylr","https://ci-hub-test.azurewebsites.net/api/v1/auth/login/fylr","http://localhost:8080/api/v1/auth/login/fylr"],"scopes":["read","write","offline"]},"fylr-mobile-app":{"public":true,"redirectURIs":["fylr.app.scheme:///"],"scopes":["read","write","offline"]},"santa-cruz":{"public":true,"redirectURIs":["https://fylr.linkrui.com/oauth","https://stage-fylr.linkrui.com/oauth"],"scopes":["read","write","offline"]}}` | additional oauth2 clients to be added to the oauth2 server. For the web application, we automatically generate a key pair and assign it to the oauth2 client. |
| fylr.services.webapp | object | `{"basicAuth":{}}` | define settings for the wepapp service |
| fylr.services.webapp.basicAuth | object | `{}` | basicAuth is used to protect the web application with additional basic credentials. We expect a map of usernames and passwords in clear text. |
| fylr.startupProbe.enabled | bool | `false` |  |
| fylr.startupProbe.failureThreshold | int | `100` |  |
| fylr.startupProbe.initialDelaySeconds | int | `1` |  |
| fylr.startupProbe.periodSeconds | int | `5` |  |
| fylr.startupProbe.successThreshold | int | `1` |  |
| fylr.startupProbe.timeoutSeconds | int | `10` |  |
| image | object | `{"pullPolicy":"IfNotPresent","repository":"docker.fylr.io/fylr/fylr-server"}` | The image to use for the container |
| image.pullPolicy | string | `"IfNotPresent"` | Docker image pull policy. See https://kubernetes.io/docs/concepts/containers/images/#updating-images |
| image.repository | string | `"docker.fylr.io/fylr/fylr-server"` | Docker image repository |
| imagePullSecrets | list | `[]` |  |
| includeStorageSecret | bool | `true` |  |
| ingress.annotations | object | `{}` |  |
| ingress.className | string | `"nginx"` |  |
| ingress.enabled | bool | `true` |  |
| ingress.hosts[0].host | string | `"localhost"` |  |
| ingress.hosts[0].paths[0].path | string | `"/"` |  |
| ingress.hosts[0].paths[0].pathType | string | `"ImplementationSpecific"` |  |
| ingress.tls | list | `[]` |  |
| monitoring.enabled | bool | `false` | Specifies whether Prometheus monitoring should be enabled |
| monitoring.serviceMonitor | object | `{"enabled":false,"interval":"30s","jobLabel":"","namespace":"default","scrapeTimeout":"10s"}` | Prometheus Operator ServiceMonitor configuration |
| nameOverride | string | `""` |  |
| nodeSelector | object | `{}` |  |
| opensearch.clusterName | string | `"open"` |  |
| opensearch.containerPorts.restAPI | int | `9200` |  |
| opensearch.containerPorts.transport | int | `9300` |  |
| opensearch.enabled | bool | `false` |  |
| opensearch.master.masterOnly | bool | `true` |  |
| opensearch.master.replicaCount | int | `2` |  |
| opensearch.plugins | string | `"analysis-icu"` |  |
| podAnnotations | object | `{}` |  |
| podSecurityContext | object | `{"fsGroup":2000}` | Pod security context |
| podSecurityContext.fsGroup | int | `2000` | This is a requirement when running with attached volumes. |
| postgresql.auth.database | string | `"fylr"` |  |
| postgresql.auth.password | string | `"fylr"` |  |
| postgresql.auth.postgresPassword | string | `"fylr"` |  |
| postgresql.auth.username | string | `"fylr"` |  |
| postgresql.enabled | bool | `false` |  |
| postgresql.image.registry | string | `"docker.io"` |  |
| postgresql.image.repository | string | `"bitnami/postgresql"` |  |
| postgresql.image.tag | string | `"16.3.0-debian-12-r18"` |  |
| postgresql.primary.persistence.storageClass | string | `""` |  |
| replicaCount | int | `1` |  |
| resources | object | `{}` |  |
| securityContext | object | `{}` |  |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.create | bool | `true` | Specifies whether a service account should be created |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template |
| services.api.port | int | `8081` |  |
| services.api.type | string | `"ClusterIP"` |  |
| services.backend.port | int | `8082` |  |
| services.backend.type | string | `"ClusterIP"` |  |
| services.webapp.port | int | `8080` |  |
| services.webapp.type | string | `"ClusterIP"` |  |
| strategy | object | `{"rollingUpdate":{"maxSurge":"25%","maxUnavailable":"25%"},"type":"RollingUpdate"}` | Specifies the strategy used to replace old Pods by new ones See: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#rolling-update-deployment |
| tolerations | list | `[]` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
