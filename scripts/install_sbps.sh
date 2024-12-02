#!/usr/bin/env bash
set -exuo pipefail

# Install sbps
sudo zypper -n --no-gpg-checks in /vagrant/artifacts/sbps-marshal-0.0.11-1.noarch.rpm
kubectl label node k3d-csm-server-0 iscsi=sbps

# Run spbs ansible
cd /vagrant
ansible-playbook ansible/config_sbps_iscsi_targets.yml -i ansible/inventory.yml
