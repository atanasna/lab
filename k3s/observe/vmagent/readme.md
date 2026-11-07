# Metrics collection with vmagent

vmagent owns the scrape configuration in `configs/prometheus.yaml` and sends
samples to `http://victoriametrics:8428/api/v1/write`. VictoriaMetrics only stores
and serves metrics. Grafana and vmalert continue using VictoriaMetrics at port
8428; neither needs a URL change. The separate Prometheus deployment has been
retired; see the [cleanup instructions](../readme.md#remove-the-retired-prometheus-deployment).

All previous jobs are preserved. The VictoriaMetrics self-scrape now targets its
Service instead of localhost, so its `instance` label changes from `localhost:8428`
to `victoriametrics:8428`. A new `vmagent` job collects the scraper's own metrics.

## Initial cutover

Run from the repository root. Stop the built-in scraper before starting vmagent
to avoid duplicate scraping. Do not delete VictoriaMetrics or its PVC.

```sh
kubectl --context local apply -k k3s/observe/victoriametrics
kubectl --context local -n observe rollout status deployment/victoriametrics --timeout=180s
kubectl --context local apply -k k3s/observe/vmagent
kubectl --context local -n observe rollout status deployment/vmagent --timeout=180s
```

Only proceed to the next command if the preceding command succeeds. This causes
a short collection gap during cutover but does not remove historical samples.

After both rollouts succeed, remove the old discovery permissions. `apply` does
not delete resources that were removed from a kustomization:

```sh
kubectl --context local delete clusterrolebinding victoriametrics --ignore-not-found
kubectl --context local delete clusterrole victoriametrics --ignore-not-found
kubectl --context local -n observe delete serviceaccount victoriametrics --ignore-not-found
```

Old `victoriametrics-config-*` ConfigMaps are unused and can be removed after
verifying collection. They do not enable scraping on their own.

Subsequent scraper changes: `task observe:vmagent` or
`kubectl --context local apply -k k3s/observe/vmagent`. Storage changes remain under
`task observe:victoriametrics`. `task observe:all` waits for the storage-only
VictoriaMetrics rollout before applying vmagent. Task commands use the current
kubectl context.

## Verify

```sh
kubectl --context local -n observe logs deployment/vmagent --tail=100
kubectl --context local -n observe port-forward service/vmagent 8429:8429
```

Open http://localhost:8429/targets to check every scrape job (this page is now on
vmagent, not VictoriaMetrics). For discovery targets, check errors for missing
Kubernetes permissions as well as endpoint errors.

After at least a minute, query the existing VictoriaMetrics data source in Grafana:

```promql
up
up{job="vmagent"}
up{job="shelly-ht"}
shelly_ht_temperature_celsius
time() - timestamp(up{job="vmagent"})
```

The final query should stay near the scrape interval, confirming new samples are
arriving rather than only historical data. Inspect vmagent logs for remote-write
errors if targets are healthy but samples do not reach VictoriaMetrics.

## Persistent queue

One vmagent replica uses `Recreate` so two instances cannot share its queue.
Buffered samples live in the `vmagent` subdirectory of the existing NFS-backed
`observe-pvc`, separate from the `victoriametrics` data directory. The queue
survives pod replacement and can follow the pod to another node.

Disk buffering is capped at 1GB for the single destination; when full, the oldest
queued data is dropped. This is a cap, not a reserved allocation, and consumes
space on the shared monitoring volume. It covers temporary VictoriaMetrics
outages, not a NAS outage: both storage and the queue depend on the same NAS.

## Local checks

Run `python3 k3s/observe/vmagent/test.py` with Docker running and PyYAML installed.
It renders both kustomizations, checks scraper/storage separation and persistence,
and asks the vmagent image to validate the full scrape configuration without
connecting to the cluster.
