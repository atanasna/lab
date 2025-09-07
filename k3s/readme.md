# Prepare the PIs
<!-- `sudo apt-get install -y qemu-user-static binfmt-support` -->
<!-- sudo update-binfmts --enable -->
<!-- sudo systemctl restart systemd-binfmt.service -->


# Installation
1. Export secretes `source .env`
1. Apply namespaces `kubectl apply -f k3s/namespaces.yaml`
1. Apply pathech
    1. Traefik set IP: `kubectl patch svc -n kube-system traefik -p '{"spec":{"loadBalancerIP":"10.7.0.70"}}' `
1. Apply extensions
    1. Metallb: `kubectl apply -k k3s/extensions/metallb`
    1. CertManager: `kubectl apply -k k3s/extensions/certmanager`
1. Apply infra 
    1. Storage `kubectl apply -f k3s/infra/storage.yaml`
    1. Redis `kubectl apply -k k3s/infra/redis`
    1. Postgres `kubectl apply -k k3s/infra/postgres`
1. Apply analytics 
    1. Storage `kubectl apply -f k3s/analytics/storage.yaml`
    1. Prometheus `kubectl apply -k k3s/analytics/prometheus`
    1. Grafana `kubectl apply -k k3s/analytics/grafana`
    1. APIExporter `kubectl apply -k k3s/analytics/api-exporter`
1. Apply apps 
    1. Storage `kubectl apply -f k3s/apps/storage.yaml`
    1. N8N `kubectl apply -k k3s/apps/n8n`
    1. Pihole `kubectl apply -k k3s/apps/pihole`
    1. Paperless `kubectl apply -k k3s/apps/paperless`



