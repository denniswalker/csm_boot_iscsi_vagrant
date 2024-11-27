#!/usr/bin/env bash
set -euo pipefail
sudo zypper refresh
sudo zypper -n in \
  wget \
  curl \
  tmux \
  vim \
  htop \
  docker \
  git \
  bind-utils \
  python39 \
  jq \
  podman \
  s3fs \
  nginx \
  targetcli-fb \
  dhcp-server \
  tftp \
  ansible

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Upgrade Python
# sbps requires python3.9
sudo zypper -n in python39 python39-pip
sudo /usr/bin/python3.9 -m pip install --upgrade pip==20.0.2
sudo /usr/bin/python3.9 -m pip install --upgrade virtualenv

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
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3)"

# Install PowerDNS
git clone https://github.com/cdwv/powerdns-helm
cd powerdns-helm
helm install . --generate-name
echo "127.0.0.1 api-gw-service-nmn.local" >>/etc/hosts
cd "$OLDPWD"

# Install Minio
mkdir -p ~/minio/data

export MINIO_ACCESS_KEY=myaccesskey
echo "export MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY}" | sudo tee -a /etc/environment >/dev/null
export MINIO_SECRET_KEY=mysecretkey
echo "export MINIO_SECRET_KEY=${MINIO_SECRET_KEY}" | sudo tee -a /etc/environment >/dev/null

podman run -d \
  -p 9000:9000 \
  -p 9001:9001 \
  -v ~/minio/data:/data \
  -e "MINIO_ROOT_USER=minioroot" \
  -e "MINIO_ROOT_PASSWORD=miniopass" \
  quay.io/minio/minio server /data --console-address ":9001"

curl https://dl.min.io/client/mc/release/linux-amd64/mc \
  --create-dirs \
  -o "$HOME"/minio-binaries/mc
chmod +x "$HOME"/minio-binaries/mc
mv "$HOME"/minio-binaries/mc /usr/local/bin/mc

mc alias set local http://127.0.0.1:9000 minioroot miniopass
mc admin accesskey create local/ --access-key "$MINIO_ACCESS_KEY" --secret-key "$MINIO_SECRET_KEY" --name testkey
#mc admin info local

# Configure Minio
# Create service account
# Create buckets

# Install sbps
sudo zypper -n --no-gpg-checks in /vagrant/artifacts/sbps-marshal-0.0.11-1.noarch.rpm
kubectl label node k3d-csm-server-0 iscsi=sbps

# Configure PowerDNS as the DNS server
# Wait for powerdns-helm deployment to be ready
timeout=30 # Total timeout in seconds
interval=2 # Interval between checks in seconds
elapsed=0

echo "Waiting for powerdns-helm chart to finish deploying..."

while true; do
  # Check if the deployment is ready
  if kubectl get pods -l app=powerdns-helm -A -o json | jq -e '.items[] | select(.status.phase == "Running")' >/dev/null 2>&1; then
    echo "powerdns-helm chart successfully deployed!"
    break
  fi

  # Exit if timeout is reached
  if [ "$elapsed" -ge "$timeout" ]; then
    echo "Timeout reached: powerdns-helm chart did not finish deploying within $timeout seconds."
    exit 1
  fi

  # Wait for the interval and increment elapsed time
  sleep "$interval"
  elapsed=$((elapsed + interval))
done

POWERDNS_ENDPOINT=$(kubectl get svc -l app=powerdns-helm -A -o json | jq -r ".items[0].spec.clusterIP")
echo "export POWERDNS_ENDPOINT=${POWERDNS_ENDPOINT}" | sudo tee -a /etc/environment >/dev/null
echo "NETCONFIG_DNS_STATIC_SERVERS=${POWERDNS_ENDPOINT}" | sudo tee -a /etc/sysconfig/network/config >/dev/null
sudo netconfig update -f

# Mimic CPS
mkdir -p /var/lib/cps-local/boot-images

# Install IMS
git clone https://github.com/Cray-HPE/ims
cd ./ims

# Probably unnecessary
# python3.9 -m venv .env
# source .env/bin/activate
# python3.9 -m pip install -r requirements.txt
# remove the artifactory prefix from the Dockerfile, pulls from dockerhub
sudo sed -i 's|artifactory.algol60.net/csm-docker/stable/docker.io/library/||g' Dockerfile
sudo sed -i 's|artifactory.algol60.net/csm-docker/stable/docker.io/||g' Dockerfile
echo "testing" >.version
echo "dev" >.docker_version

# Configure IMS
sudo mkdir -p ~/tmp/datastore/
ims_config_files=(v2_public_keys.json v3_deleted_public_keys.json v2.2_recipes.json v3.2_deleted_recipes.json v2.1_images.json v3.1_deleted_images.json v2.2_jobs.json v2.0_remote_build_nodes.json)
for file in ${ims_config_files[@]}; do
  echo "[]" | sudo tee -a ~/tmp/datastore/"$file" >/dev/null
done

# Make the IMS s3 bbuckets
mc mb local/boot-images
mc mb local/recipes
mc mb local/ims
docker build -t cray-ims-service:dev -f Dockerfile .
cd "$OLDPWD"
source /etc/environment
echo "Starting IMS..."
nohup /vagrant/start_ims.sh &

# Install Spire
curl -s -N -L https://github.com/spiffe/spire/releases/download/v1.10.4/spire-1.10.4-linux-amd64-musl.tar.gz | tar xz
cd $(find . -name spire*)
nohup bin/spire-server run -config conf/server/server.conf &
bin/spire-server healthcheck
TOKEN=$(bin/spire-server token generate -spiffeID spiffe://example.org/host | cut -d " " -d 2)
nohup bin/spire-agent run -config conf/agent/agent.conf -joinToken "$TOKEN" &
mkdir -p /opt/cray/cray-spire
ln -s /root/spire-1.10.4/bin/spire-agent /opt/cray/cray-spire/spire-agent
ln -s /root/spire-1.10.4/bin/spire-agent /opt/cray/cray-spire/sbps-marshall-spire-agent

# Run spbs ansible
cd /vagrant
ansible-playbook ansible/config_sbps_iscsi_targets.yml -i ansible/inventory.yml
