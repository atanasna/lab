"""Docker integration check; no cluster access or real credentials required."""

import json
from pathlib import Path
import subprocess
import tempfile
import time
import uuid


def docker(*args):
    return subprocess.check_output(["docker", *args], text=True, stderr=subprocess.STDOUT)


def main():
    prefix = "shelly-test-" + uuid.uuid4().hex[:8]
    broker, exporter = prefix + "-broker", prefix + "-exporter"
    docker("network", "create", prefix)
    try:
        with tempfile.TemporaryDirectory(prefix=prefix) as temp:
            root = Path(temp)
            (root / "mosquitto.conf").write_text("listener 1883\nallow_anonymous true\n")
            config = (Path(__file__).parent / "configs/telegraf.conf").read_text()
            config = config.replace("mosquitto.data.svc.cluster.local", broker)
            (root / "telegraf.conf").write_text(config)
            docker(
                "run", "-d", "--name", broker, "--network", prefix,
                "-v", f"{root / 'mosquitto.conf'}:/mosquitto/config/mosquitto.conf:ro",
                "eclipse-mosquitto:2.0.22",
            )
            for _ in range(30):
                try:
                    docker("exec", broker, "mosquitto_pub", "-t", "ready", "-m", "ready")
                    break
                except subprocess.CalledProcessError:
                    time.sleep(1)
            else:
                raise AssertionError("Test broker did not start")
            docker(
                "run", "-d", "--name", exporter, "--network", prefix,
                "--user", "100:101",
                "-e", "MQTT_USERNAME=test", "-e", "MQTT_PASSWORD=test",
                "-v", f"{root / 'telegraf.conf'}:/etc/telegraf/telegraf.conf:ro",
                "telegraf:1.36.3-alpine",
            )
            for _ in range(60):
                if "shelly-metrics-exporter" in docker("logs", broker):
                    break
                if docker("inspect", "-f", "{{.State.Running}}", exporter).strip() == "false":
                    raise AssertionError(docker("logs", exporter))
                time.sleep(1)
            else:
                raise AssertionError("Exporter did not connect: " + docker("logs", exporter))

            def publish(floor, sensor, params):
                payload = {"src": sensor, "method": "NotifyStatus", "params": params}
                docker(
                    "exec", broker, "mosquitto_pub", "-q", "1",
                    "-t", f"voyager/{floor}/ht/events/rpc", "-m", json.dumps(payload),
                )

            def wait_for(name, floor, value):
                for _ in range(20):
                    output = docker("exec", exporter, "wget", "-qO-", "http://localhost:9273/metrics")
                    for line in output.splitlines():
                        if line.startswith(name + "{") and f'floor="{floor}"' in line:
                            if float(line.split()[-1]) == value:
                                assert 'site="voyager"' in line
                                assert f'sensor="sensor-{floor}"' in line
                                return
                    time.sleep(1)
                raise AssertionError(f"Missing {name} for {floor} = {value}:\n{output}")

            publish("f1", "sensor-f1", {
                "ts": 1794048663.08,
                "temperature:0": {"id": 0, "tC": 15.1, "tF": 59.2},
                "humidity:0": {"id": 0, "rh": 50.3},
                "devicepower:0": {"battery": {"percent": 100}},
            })
            wait_for("shelly_ht_temperature_celsius", "f1", 15.1)
            wait_for("shelly_ht_humidity_percent", "f1", 50.3)
            wait_for("shelly_ht_battery_percent", "f1", 100)
            wait_for("shelly_ht_last_report_timestamp_seconds", "f1", 1794048663.08)
            publish("f1", "sensor-f1", {"ts": 1794048664, "humidity:0": {"rh": 51.2}})
            wait_for("shelly_ht_humidity_percent", "f1", 51.2)
            wait_for("shelly_ht_temperature_celsius", "f1", 15.1)
            publish("f2", "sensor-f2", {"ts": 1794048665, "temperature:0": {"tC": 18.5}})
            wait_for("shelly_ht_temperature_celsius", "f2", 18.5)
            wait_for("shelly_ht_temperature_celsius", "f1", 15.1)
            print("PASS: full/partial reports, field preservation, report time, and floor/sensor labels")
    finally:
        for container in (exporter, broker):
            subprocess.run(["docker", "rm", "-f", container], capture_output=True)
        subprocess.run(["docker", "network", "rm", prefix], capture_output=True)


if __name__ == "__main__":
    main()
