#!/usr/bin/env bash
set -exuo pipefail

# Start Docker
sudo systemctl start docker
sudo systemctl enable docker
sudo chown vagrant /var/run/docker.sock

# Install K3s
wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | sudo bash
sudo k3d cluster create csm
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl
mv ./kubectl /usr/local/bin/
mkdir /home/vagrant/.kube
k3d kubeconfig get -a >>/home/vagrant/.kube/config
sudo chown vagrant /home/vagrant/.kube/config
chmod 600 /home/vagrant/.kube/config

# Install helm
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3)"

# Unique to k3s and CSM
sleep 5
GATEWAY_IP="$(kubectl -n kube-system get svc traefik -o json | jq -r '.status.loadBalancer.ingress[0].ip')"
echo "${GATEWAY_IP} api-gw-service-nmn.local" >>/etc/hosts
echo "export GATEWAY_IP=${GATEWAY_IP}" >>/etc/environment
