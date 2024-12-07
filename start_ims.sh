#!/usr/bin/env bash
set -euo pipefail

source /etc/environment
# docker run --rm --name cray-ims-service \
#   -p 9100:9000 \
#   -e "S3_ACCESS_KEY=${MINIO_ACCESS_KEY}" \
#   -e "S3_SECRET_KEY=${MINIO_SECRET_KEY}" \
#   -e "S3_CONNECT_TIMEOUT=30" \
#   -e "S3_READ_TIMEOUT=30" \
#   -e "S3_ENDPOINT=http://localhost:9000" \
#   -e "S3_IMS_BUCKET=recipes" \
#   -e "S3_BOOT_IMAGES_BUCKET=boot-images" \
#   -e "FLASK_ENV=staging" \
#   -v ~/tmp/datastore:/var/ims/data \
#   cray-ims-service:dev

ctr run --rm --net-host \
  --env S3_ACCESS_KEY=${MINIO_ACCESS_KEY} \
  --env S3_SECRET_KEY=${MINIO_SECRET_KEY} \
  --env S3_CONNECT_TIMEOUT=30 \
  --env S3_READ_TIMEOUT=30 \
  --env S3_ENDPOINT=http://localhost:9000 \
  --env S3_IMS_BUCKET=recipes \
  --env S3_BOOT_IMAGES_BUCKET=boot-images \
  --env FLASK_ENV=staging \
  --mount type=bind,src=$HOME/tmp/datastore,dst=/var/ims/data,options=rbind:rw \
  cray-ims-service:dev cray-ims-service
