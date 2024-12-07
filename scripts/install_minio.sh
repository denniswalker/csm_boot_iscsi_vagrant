#!/usr/bin/env bash
set -exuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "$SCRIPT_DIR"/lib/lib

# Install Minio
mkdir -p ~/minio/data

MINIO_ACCESS_KEY="minioaccess"
MINIO_SECRET_KEY="miniosecret"

echo "export MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY}" |
  sudo tee -a /etc/environment >/dev/null
echo "export MINIO_SECRET_KEY=${MINIO_SECRET_KEY}" |
  sudo tee -a /etc/environment >/dev/null

create_systemd_service minio podman run \
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

echo "Waiting for Minio at localhost:9000 to become active..."
while ! curl -s http://localhost:9000 >/dev/null; do
  sleep 2
  echo -n "."
done
echo "localhost:9000 is now active!"

mc alias set local http://127.0.0.1:9000 minioroot miniopass
mc admin accesskey create \
  local/ --access-key "$MINIO_ACCESS_KEY" --secret-key "$MINIO_SECRET_KEY" --name testkey
