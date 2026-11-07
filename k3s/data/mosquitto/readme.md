# Mosquitto

Single MQTT broker for Shelly H&T Gen3 sensors:

- LAN endpoint: `10.7.0.250:1883` (MetalLB).
- Cluster endpoint: `mosquitto.data.svc.cluster.local:1883`.
- Anonymous access disabled; Kustomize generates the `mosquitto-auth-<hash>` Secret
  from a Git-ignored password file.
- Retained messages and persistent sessions use a 1Gi K3s `local-path` PVC.

Port 1883 is **unencrypted**: keep it on a trusted LAN, allow the sensor Wi-Fi
network to reach it, and do not forward it from the Internet. Authenticated clients
can access all topics; use a dedicated MQTT password. Add TLS and per-device ACLs
before sharing the broker with untrusted clients. The local-path volume survives
pod restarts but is tied to its node; this is not a highly available broker or a
sensor history database.

## Deploy

From the repository root, confirm that `local` points at the home cluster:

```sh
kubectl --context local get nodes
kubectl --context local get storageclass local-path
kubectl --context local apply -f k3s/namespaces.yaml
```

Create a password file interactively using Docker (or a locally installed
`mosquitto_passwd`). `k3s/data/mosquitto/.secrets/` is ignored by Git. Use the same
credentials on the sensor and subscriber; do not commit the password file or
rendered Secret YAML. Run password generation only once: `-c` overwrites the file.

```sh
mkdir -p k3s/data/mosquitto/.secrets
docker run --rm -it --user "$(id -u):$(id -g)" \
  -v "$PWD/k3s/data/mosquitto/.secrets:/auth" eclipse-mosquitto:2.0.22 \
  mosquitto_passwd -c /auth/passwords shelly
```

If you already generated `.secrets/mosquitto-passwords` using the previous
instructions, copy it to `k3s/data/mosquitto/.secrets/passwords` instead of generating
a new password (create the destination directory first).

Apply the configuration; this creates both the Secret and broker:

```sh
kubectl --context local apply -k k3s/data/mosquitto
kubectl --context local -n data rollout status deployment/mosquitto
kubectl --context local -n data get service mosquitto
```

For subsequent deployments: `task data:mosquitto`. If the password file is missing,
Kustomize fails before applying any resources. After updating the password file,
apply again: the generated Secret name changes and automatically restarts the pod.
The task commands use your current context, like the other services in this repo.

## Shelly H&T Gen3

Wake the battery-powered sensor with its button to configure it in its web UI.
Under MQTT settings, set:

| Setting | Value |
| --- | --- |
| Enable MQTT | Yes |
| Server | `10.7.0.250:1883` |
| Username | `shelly` |
| Password | The password chosen above |
| TLS | Disabled |
| Topic prefix | Leave default (unique device ID) |
| RPC notifications (`rpc_ntf`) | Enabled |
| Status notifications (`status_ntf`) | Enabled |

Reboot if requested. Gen3 uses the Gen2+ MQTT API, **not** the Gen1
`shellies/<id>/sensor/...` topic layout. Component status is published on
`<device-id>/status/temperature:0` and `<device-id>/status/humidity:0`;
RPC notifications are on `<device-id>/events/rpc`.

Battery operation sleeps between reports: disconnects and delayed updates are
normal. Wake the sensor to test; do not expect a continuous stream.

## Verify

With Mosquitto clients installed, subscribe from a machine on the sensor network:

```sh
mosquitto_sub -h 10.7.0.250 -p 1883 -u shelly -P '<mqtt-password>' \
  -t '+/status/#' -t '+/events/rpc' -v
```

Wake the sensor and check for temperature/humidity messages. For broker logs:

```sh
kubectl --context local -n data logs deployment/mosquitto --tail=50
```

Check authentication rejection (must fail, not connect):

```sh
mosquitto_sub -h 10.7.0.250 -p 1883 -t '#' -W 5
```

References: [Shelly MQTT API](https://shelly-api-docs.shelly.cloud/gen2/ComponentsAndServices/Mqtt/),
[H&T Gen3](https://shelly-api-docs.shelly.cloud/gen2/Devices/Gen3/ShellyHTG3/).
