#!/usr/bin/env bash
set -exuo pipefail
source /etc/environment

echo "${MINIO_ACCESS_KEY}:${MINIO_SECRET_KEY}" >/root/.ims.s3fs

# Install sbps
sudo zypper -n --no-gpg-checks in /vagrant/artifacts/sbps-marshal-0.0.11-1.noarch.rpm
kubectl label node "$(hostname -s)" iscsi=sbps

# Run spbs ansible
cd /vagrant
ansible-playbook ansible/config_sbps_iscsi_targets.yml -i ansible/inventory.yml
