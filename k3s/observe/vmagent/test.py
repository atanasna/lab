"""Render the manifests and validate the scrape config with the actual vmagent binary."""

from pathlib import Path
import subprocess

import yaml


ROOT = Path(__file__).resolve().parents[3]


def render(service):
    output = subprocess.check_output(
        ["kubectl", "kustomize", str(ROOT / "k3s/observe" / service)], text=True
    )
    return list(yaml.safe_load_all(output))


def main():
    storage = render("victoriametrics")
    agent = render("vmagent")
    vm = next(obj for obj in storage if obj["kind"] == "Deployment")["spec"]["template"]["spec"]
    assert vm["automountServiceAccountToken"] is False
    assert "serviceAccountName" not in vm
    assert not any(obj["kind"] in ("ConfigMap", "ClusterRole", "ClusterRoleBinding", "ServiceAccount") for obj in storage)
    container = vm["containers"][0]
    assert container["args"] == ["-storageDataPath=/victoriametrics", "-retentionPeriod=3y"]
    assert container["volumeMounts"] == [{"name": "observe-pvc", "mountPath": "/victoriametrics", "subPath": "victoriametrics"}]

    resources = {obj["kind"]: obj for obj in agent}
    deployment = resources["Deployment"]["spec"]
    assert deployment["replicas"] == 1 and deployment["strategy"]["type"] == "Recreate"
    pod = deployment["template"]
    assert resources["Service"]["spec"]["selector"] == pod["metadata"]["labels"]
    spec = pod["spec"]
    assert spec["serviceAccountName"] == resources["ServiceAccount"]["metadata"]["name"] == "vmagent"
    binding = resources["ClusterRoleBinding"]
    assert binding["roleRef"]["name"] == resources["ClusterRole"]["metadata"]["name"]
    assert binding["subjects"] == [{"kind": "ServiceAccount", "name": "vmagent", "namespace": "observe"}]
    volumes = {volume["name"]: volume for volume in spec["volumes"]}
    assert volumes["config"]["configMap"]["name"] == resources["ConfigMap"]["metadata"]["name"]
    assert volumes["observe-pvc"]["persistentVolumeClaim"]["claimName"] == "observe-pvc"
    container = spec["containers"][0]
    assert "-remoteWrite.url=http://victoriametrics:8428/api/v1/write" in container["args"]
    assert "-remoteWrite.tmpDataPath=/vmagent" in container["args"]
    assert "-remoteWrite.maxDiskUsagePerURL=1GB" in container["args"]
    assert {"name": "observe-pvc", "mountPath": "/vmagent", "subPath": "vmagent"} in container["volumeMounts"]
    config = yaml.safe_load(resources["ConfigMap"]["data"]["prometheus.yaml"])
    jobs = {job["job_name"]: job for job in config["scrape_configs"]}
    assert set(jobs) == {
        "victoriametrics", "vmagent", "victorialogs", "shelly-ht", "vlagent",
        "k3s-pods", "kube-state-metrics", "k3s-nodes", "air-quality", "synology-nas", "mikrotik",
    }
    assert jobs["victoriametrics"]["static_configs"][0]["targets"] == ["victoriametrics:8428"]
    assert jobs["shelly-ht"]["static_configs"][0]["targets"] == ["mqtt-exporter:9273"]
    tasks = yaml.safe_load((ROOT / ".ci/tasks/observe.yaml").read_text())["tasks"]
    commands = tasks["all"]["cmds"]
    assert commands.index({"task": "victoriametrics"}) < commands.index({"task": "vmagent"})
    assert any("rollout status deployment/victoriametrics" in cmd for cmd in commands if isinstance(cmd, str))

    subprocess.run([
        "docker", "run", "--rm",
        "-v", f"{Path(__file__).parent.resolve() / 'configs'}:/config:ro",
        container["image"],
        *(arg.replace("/etc/vmagent/prometheus.yaml", "/config/prometheus.yaml") for arg in container["args"]),
        "-promscrape.config.dryRun",
    ], check=True)
    print("PASS: storage/scraper separation, RBAC, persistent queue, scrape jobs, cutover order, and vmagent config validation")


if __name__ == "__main__":
    main()
