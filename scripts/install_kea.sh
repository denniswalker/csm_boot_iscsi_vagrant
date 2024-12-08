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
helm install kea-dhcp mglants/kea-dhcp -f /tmp/kea-dhcp-config.yaml

# create_systemd_service kea-dhcp-forwarder kubectl port-forward --address=0.0.0.0 service/kea-dhcp 67:67
#
# cat <<EOF | kubectl apply -f -
# apiVersion: networking.istio.io/v1beta1
# kind: Gateway
# metadata:
#   name: dhcp-ingressgateway
#   namespace: default
# spec:
#   selector:
#     istio: istio-system/ingressgateway # Use the default ingress gateway
#   servers:
#     - port:
#         number: 67
#         name: udp-dhcp-server
#         protocol: UDP
#       hosts:
#         - "*"
#     - port:
#         number: 68
#         name: udp-dhcp-client
#         protocol: UDP
#       hosts:
#         - "*"
#     - port:
#         number: 547
#         name: udp-dhcpv6-server
#         protocol: UDP
#       hosts:
#         - "*"
#     - port:
#         number: 546
#         name: udp-dhcpv6-client
#         protocol: UDP
#       hosts:
#         - "*"
# EOF
#
# cat <<EOF | kubectl apply -f -
# apiVersion: networking.istio.io/v1beta1
# kind: VirtualService
# metadata:
#   name: kea-dhcp-virtualservice
#   namespace: default
# spec:
#   hosts:
#     - "*"
#   gateways:
#     - default/dhcp-ingressgateway
#   tcp:
#     - match:
#         - port: 67 # DHCPv4 server port
#       route:
#         - destination:
#             host: kea-dhcp.default.svc.cluster.local
#             port:
#               number: 67
#     - match:
#         - port: 68 # DHCPv4 client port
#       route:
#         - destination:
#             host: kea-dhcp.default.svc.cluster.local
#             port:
#               number: 68
#     - match:
#         - port: 547 # DHCPv6 server port
#       route:
#         - destination:
#             host: kea-dhcp.default.svc.cluster.local
#             port:
#               number: 547
#     - match:
#         - port: 546 # DHCPv6 client port
#       route:
#         - destination:
#             host: kea-dhcp.default.svc.cluster.local
#             port:
#               number: 546
# EOF
