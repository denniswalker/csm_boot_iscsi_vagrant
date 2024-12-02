#!/usr/bin/env bash
set -exuo pipefail

# Mimic CPS
mkdir -p /var/lib/cps-local/boot-images

# Install IMS
git clone https://github.com/Cray-HPE/ims
cd ./ims

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

# Build the IMS Docker image
docker build -t cray-ims-service:dev -f Dockerfile .
cd "$OLDPWD"
source /etc/environment
echo "Starting IMS..."
nohup /vagrant/start_ims.sh &
