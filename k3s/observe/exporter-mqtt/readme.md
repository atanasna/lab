# Shelly MQTT metrics

Telegraf subscribes to `voyager/+/ht/events/rpc` on Mosquitto and exposes
Prometheus metrics at `mqtt-exporter.observe.svc.cluster.local:9273/metrics`.
vmagent collects them every 60 seconds and remote-writes them to VictoriaMetrics.

Use prefixes such as `voyager/f1/ht`, `voyager/f2/ht`, etc. Each series has `site`,
`floor`, and `sensor` (Shelly device ID) labels. Both `NotifyFullStatus` and partial
`NotifyStatus` payloads work; missing measurements do not overwrite previous ones.

## Deploy

Create `k3s/observe/exporter-mqtt/.secrets/mqtt.env` (Git-ignored) with the same
credentials used by the sensor. This subscriber needs the **original password**,
not Mosquitto's password hash:

```dotenv
MQTT_USERNAME=shelly
MQTT_PASSWORD=replace-with-your-mqtt-password
```

From the repository root:

```sh
kubectl --context local apply -k k3s/observe/exporter-mqtt
kubectl --context local -n observe rollout status deployment/mqtt-exporter
kubectl --context local apply -k k3s/observe/vmagent
kubectl --context local -n observe rollout status deployment/vmagent
```

Kustomize creates the credentials Secret and rolls the exporter when credentials
change. Subsequent deployments can use `task observe:exporter-mqtt` and
`task observe:vmagent` (these use the current kubectl context). For the initial
split from the built-in scraper, follow the [vmagent cutover](../vmagent/readme.md)
first.

## Verify

Wake the sensor, wait five seconds for the exporter to flush, then:

```sh
kubectl --context local -n observe logs deployment/mqtt-exporter --tail=50
kubectl --context local -n observe port-forward service/mqtt-exporter 9273:9273
```

In another terminal:

```sh
curl -s http://localhost:9273/metrics | grep '^shelly_ht_'
```

After the next scrape, query VictoriaMetrics or Grafana:

```promql
shelly_ht_temperature_celsius{site="voyager", floor="f1"}
shelly_ht_humidity_percent{site="voyager", floor="f1"}
shelly_ht_battery_percent{site="voyager", floor="f1"}
time() - shelly_ht_last_report_timestamp_seconds{site="voyager", floor="f1"}
```

The final query is seconds since the latest sensor-reported timestamp and depends
on the sensor's clock being correct. It measures contact age, not the age of every
individual field in a partial report. `up{job="shelly-ht"}` checks the exporter,
not the sensor.

Readings are cached for three hours to cover the two-hour wakeup period in the
sample payload, then expire. Scraped timestamps are scrape times, not original
measurement times. The cache is in memory: after an exporter restart, readings
return on the next sensor report. The persistent MQTT session may queue QoS 1
messages during downtime but does not replace the cache or guarantee replay of
QoS 0 messages.

## Local test

With Docker running, run `python3 k3s/observe/exporter-mqtt/test.py`. This starts
isolated, temporary Mosquitto and Telegraf containers, publishes full and partial
reports, and checks their `/metrics` output. It does not connect to the cluster.
