#!/usr/bin/env bash
set -euo pipefail

source /etc/environment
docker run --rm --name cray-ims-service \
  -p 9100:9000 \
  -e "S3_ACCESS_KEY=${MINIO_ACCESS_KEY}" \
  -e "S3_SECRET_KEY=${MINIO_SECRETY_KEY}" \
  -e "S3_CONNECT_TIMEOUT=30" \
  -e "S3_READ_TIMEOUT=30" \
  -e "S3_ENDPOINT=http://localhost:9000" \
  -e "S3_IMS_BUCKET=recipes" \
  -e "S3_BOOT_IMAGES_BUCKET=boot-images" \
  -e "FLASK_ENV=staging" \
  -v ~/tmp/datastore:/var/ims/data \
  cray-ims-service:dev
