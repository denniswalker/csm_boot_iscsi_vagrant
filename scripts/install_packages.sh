#!/usr/bin/env bash
set -exuo pipefail
sudo zypper refresh
sudo zypper -n in \
  wget \
  curl \
  tmux \
  vim \
  htop \
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
  ansible \
  containerd \
  cri-tools \
  buildah \
  ethtool \
  conntrack-tools \
  apparmor-parser \
  netcat-openbsd

echo "10.252.0.10 api-gw-service-nmn.local" >>/etc/hosts
echo "10.252.0.10 ncn-w001.nmn" >>/etc/hosts
