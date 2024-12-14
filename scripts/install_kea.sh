#!/usr/bin/env bash
set -exuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "$SCRIPT_DIR"/lib/lib

cat <<EOF >/tmp/kea-dhcp-config.yaml
service:
     dhcp:
       type: LoadBalancer
kea:
  dhcp4:
    options:
      subnet4:
        - subnet: "10.252.0.0/24"
          pools:
            - pool: "10.252.0.100-10.252.0.200"
          option-data:
            - name: "routers"
              data: "10.252.0.10"
            - name: "domain-name-servers"
              data: "10.252.0.2,192.168.121.1"
            - name: "domain-name"
              data: "ncn-w001.nmn"
            - name: "tftp-server-name"
              data: "10.252.0.10"
            - name: "boot-file-name"
              data: "pxelinux.0"
EOF
helm repo add mglants http://charts.glants.xyz
helm repo update
helm -n services install kea-dhcp mglants/kea-dhcp -f /tmp/kea-dhcp-config.yaml
