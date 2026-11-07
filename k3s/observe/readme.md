# Monitoring

vmagent scrapes exporters and remote-writes samples to VictoriaMetrics. Grafana
uses `vmetrics` as its default metrics data source. vmalert and Alertmanager handle
alerts. There is no separate Prometheus deployment or rule evaluation.

## Remove the retired Prometheus deployment

The manifests and deployment task have been removed. Existing clusters need this
one-time cleanup; applying the other kustomizations does not delete old resources.

First verify both vmagent and VictoriaMetrics are ready and that
`up{job="vmagent"}` returns `1` in Grafana. Apply the Grafana configuration to
remove the provisioned `lab` data source and make `vmetrics` the default:

```sh
kubectl --context local apply -k k3s/observe/grafana
kubectl --context local -n observe rollout status deployment/grafana --timeout=180s
```

Only after that rollout succeeds, remove the Prometheus-specific resources:

```sh
kubectl --context local -n observe delete deployment,service,ingress,serviceaccount prometheus --ignore-not-found
kubectl --context local delete clusterrolebinding prometheus --ignore-not-found
kubectl --context local delete clusterrole prometheus --ignore-not-found
```

Old `prometheus-config-*` ConfigMaps are inert after the Deployment is deleted.
List them with `kubectl --context local -n observe get configmaps` and delete only
those names explicitly if desired. Do not delete `observe-pvc`, `observe-pv`, or
the shared namespace. The historical Prometheus database stays in the
`prometheus` directory on the shared monitoring volume; it is not migrated or
deleted by this cleanup.

Prometheus alert rules are retired, not migrated. vmalert and Alertmanager are
unchanged. Active provisioned dashboards use `vmetrics`; any manually created
dashboard or alert still using `lab` needs its data source changed. The archived,
unprovisioned `grafana/configs/dashboards/depricated/nodes_old.json` is unchanged.
