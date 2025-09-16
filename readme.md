# Prepare the PIs
<!-- `sudo apt-get install -y qemu-user-static binfmt-support` -->
<!-- sudo update-binfmts --enable -->
<!-- sudo systemctl restart systemd-binfmt.service -->


# Installation
1. Apply namespaces `kubectl apply -f k3s/namespaces.yaml`
1. Apply patches
    1. Traefik set IP: `kubectl patch svc -n kube-system traefik -p '{"spec":{"loadBalancerIP":"10.7.0.70"}}' `
    1. Decide where in the cluster you will attach the ext drive for bitcoin node data and set: `kubectl label nodes k3s01 bitcoin=true`
1. Apply system controllers
    1. Metallb: `kubectl apply -k k3s/extensions/metallb`
    1. CertManager: `kubectl apply -k k3s/extensions/certmanager`
1. Apply data 
    1. Storage `kubectl apply -f k3s/data/storage.yaml`
    1. Redis `kubectl apply -k k3s/data/redis`
    1. Postgres `kubectl apply -k k3s/data/postgres`
1. Apply watch 
    1. Storage `kubectl apply -f k3s/watch/storage.yaml`
    1. Prometheus `kubectl apply -k k3s/watch/prometheus`
    1. Grafana `kubectl apply -k k3s/watch/grafana`
    1. APIExporter `kubectl apply -k k3s/watch/api-exporter`
1. Apply apps 
    1. Storage `kubectl apply -f k3s/apps/storage.yaml`
    1. Storage `kubectl apply -f k3s/apps/middleware.yaml`
    1. N8N `kubectl apply -k k3s/apps/n8n`
    1. Pihole `kubectl apply -k k3s/apps/pihole`
    1. Paperless `kubectl apply -k k3s/apps/paperless`



