# Prepare the PIs
<!-- `sudo apt-get install -y qemu-user-static binfmt-support` -->
<!-- sudo update-binfmts --enable -->
<!-- sudo systemctl restart systemd-binfmt.service -->


# Setup Pi
```
cd ~

# Setup Network
#sudo nmcli c show
sudo nmcli c mod 'Wired connection 1' ipv4.addresses 10.7.0.73/24 ipv4.method manual
sudo nmcli c mod 'Wired connection 1' ipv4.gateway 10.7.0.1
sudo nmcli c mod 'Wired connection 1' ipv4.dns 8.8.8.8
sudo nmcli c down 'Wired connection 1' && sudo nmcli c up 'Wired connection 1'

# Install packages
sudo apt update
sudo apt install -y git curl wget jq fzf bat zsh neovim btop
NEO_VERSION=$(curl -s https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest | jq -r '.name')
CPU_ARCH=aarch64
wget https://github.com/fastfetch-cli/fastfetch/releases/download/$NEO_VERSION/fastfetch-linux-$CPU_ARCH.deb -O fastfetch.deb
sudo apt install ./fastfetch.deb

# Setup ENV
git clone https://github.com/atanasna/dotfiles
cd dotfiles/zsh
# FOLLOW THE setup.sh

# Install K3S
# /boot/firmware/cmdline.txt should look like this:
# console=serial0,115200 console=tty1 root=PARTUUID=3e567cc5-02 rootfstype=ext4 fsck.repair=yes rootwait quiet splash plymouth.ignore-serial-consoles cgroup_memory=1 cgroup_enable=memory
reboot
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --token=K10d58c287785a1f76f19999282188a0e35c8f043d9311e4cdf4f269c97d2e95fab::server:alabala123balalala --server=https://10.7.0.71:6443 --flannel-backend=host-gw --tls-san=10.7.0.73 --bind-address=10.7.0.73 --advertise-address=10.7.0.73 --node-ip=10.7.0.73" sh -s -

```

# Installation
1. Apply namespaces `kubectl apply -f k3s/namespaces.yaml`
1. Apply patches
    1. Traefik set IP: `kubectl patch svc -n kube-system traefik -p '{"spec":{"loadBalancerIP":"10.7.0.70"}}' `
    1. Decide where in the cluster you will attach the ext drive for bitcoin node data and set: `kubectl label nodes k3s01 bitcoin=true`
1. Apply system controllers
    1. Metallb: `./k3s/system/metallb/up.sh`
    1. CertManager: `./k3s/system/certmanager/up.sh`
1. Apply data 
    1. Storage `kubectl apply -f k3s/data/storage.yaml`
    1. Redis `kubectl apply -k k3s/data/redis`
    1. Postgres `kubectl apply -k k3s/data/postgres`
1. Apply watch 
    1. Storage `kubectl apply -f k3s/watch/storage.yaml`
    1. NodeExporter `kubectl apply -k k3s/watch/node-exporter`
    1. APIExporter `kubectl apply -k k3s/watch/api-exporter`
    1. SNMPExporter `kubectl apply -k k3s/watch/snmp-exporter`
    1. Prometheus `kubectl apply -k k3s/watch/prometheus`
    1. Grafana `kubectl apply -k k3s/watch/grafana`
1. Apply apps 
    1. Storage `kubectl apply -f k3s/apps/storage.yaml`
    1. Storage `kubectl apply -f k3s/apps/middleware.yaml`
    1. Label the nodes
        - `kubectl label nodes k3s03 allowed.bitcoin=true`
        - `kubectl label nodes k3s01 allowed.paperless=true`
    1. N8N `kubectl apply -k k3s/apps/n8n`
    1. Pihole `kubectl apply -k k3s/apps/pihole`
    1. Paperless `kubectl apply -k k3s/apps/paperless`
    1. Warden `kubectl apply -k k3s/apps/warden`
    1. Nostr `kubectl apply -k k3s/apps/nostr`
    1. Mattermost `kubectl apply -k k3s/apps/mattermost`
    1. Bitcoin `kubectl apply -k k3s/apps/bitcoin`



