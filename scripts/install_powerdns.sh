#!/usr/bin/env bash
set -exuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "$SCRIPT_DIR"/lib/lib

# Install PowerDNS
if [[ -d /root/powerdns-helm ]]; then
  rm -rf /root/powerdns-helm
fi
cd /root

# Download and install powerdns
git clone https://github.com/cdwv/powerdns-helm
cd powerdns-helm
helm install powerdns . --set service.type=LoadBalancer

# Wait for powerdns-helm deployment to be ready
timeout=180 # Total timeout in seconds
interval=5  # Interval between checks in seconds
elapsed=0

set +x
echo "Waiting for powerdns-helm chart to finish deploying..."
while true; do
  # Check if the deployment is ready
  if [[ $(kubectl get pods -l app=powerdns-helm -A -o jsonpath='{.items[0].status.containerStatuses[0].ready}') == 'true' ]]; then
    echo "powerdns-helm chart successfully deployed!"
    break
  fi

  # Exit if timeout is reached
  if [ "$elapsed" -ge "$timeout" ]; then
    echo "Timeout reached: powerdns-helm chart did not finish deploying within $timeout seconds."
    exit 1
  fi

  # Wait for the interval and increment elapsed time
  echo -n "."
  sleep "$interval"
  elapsed=$((elapsed + interval))
done
set -x

# Set up environment variables
POWERDNS_ENDPOINT=$(kubectl get svc -l app=powerdns-helm -A -o json | jq -r ".items[0].spec.clusterIP")
echo "export POWERDNS_ENDPOINT=${POWERDNS_ENDPOINT}" |
  sudo tee -a /etc/environment >/dev/null
POWERDNS_API="$(kubectl get secret powerdns-api-key -o json | jq -r '.data.POWERDNS_API_KEY' | base64 -d)"
echo "export POWERDNS_API_KEY=${POWERDNS_API}" |
  sudo tee -a /etc/environment >/dev/null
POWERDNS_SVC="$(kubectl get svc -l app=powerdns-helm -A -o json | jq -r ".items[0].metadata.name")"
echo "export POWERDNS_SVC=${POWERDNS_SVC}" |
  sudo tee -a /etc/environment >/dev/null

# Create a port-forward for PowerDNS
# create_systemd_service powerdns-forwarder \
#   kubectl port-forward --address=0.0.0.0 service/"$POWERDNS_SVC" 53:53
# create_systemd_service powerdns-api-forwarder \
#   kubectl port-forward --address=0.0.0.0 service/"$POWERDNS_SVC" 8088:8081

# Create zone and records
source /etc/environment
HOSTNAME_NMN="$(hostname).nmn"

function do_pdns() {
  local action=$1
  local zone=$2
  local args=("${@:3}")
  kubectl exec -it svc/powerdns-powerdns-helm -- pdnsutil "$action" "$zone" "${args[@]}"
}

do_pdns create-zone "$HOSTNAME_NMN" "ns1.${HOSTNAME_NMN}"
do_pdns add-record "$HOSTNAME_NMN" ns1 A 10.252.0.10
do_pdns add-record "$HOSTNAME_NMN" . A 10.252.0.10

# cat <<EOF | kubectl apply -f -
# apiVersion: networking.istio.io/v1beta1
# kind: Gateway
# metadata:
#   name: powerdns-gateway
#   namespace: default
# spec:
#   selector:
#     istio: ingressgateway # Use Istio's ingress gateway
#   servers:
#     - port:
#         number: 53
#         name: tcp-dns
#         protocol: TCP
#       hosts:
#         - "*"
#     - port:
#         number: 53
#         name: udp-dns
#         protocol: UDP
#       hosts:
#         - "*"
# EOF
#
# cat <<EOF | kubectl apply -f -
# apiVersion: networking.istio.io/v1beta1
# kind: VirtualService
# metadata:
#   name: powerdns-virtualservice
#   namespace: default
# spec:
#   hosts:
#     - "*"
#   gateways:
#     - powerdns-gateway
#   tcp:
#     - match:
#         - port: 53
#       route:
#         - destination:
#             host: powerdns-powerdns-helm.default.svc.cluster.local
#             port:
#               number: 53
#
# EOF

# Update the DNS settings
PDNS_SVC_IP="$(kubectl get svc powerdns-powerdns-helm -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
echo "export PDNS_SVC_IP=${PDNS_SVC_IP}" |
  sudo tee -a /etc/environment >/dev/null
echo "NETCONFIG_DNS_STATIC_SERVERS=\"${PDNS_SVC_IP} 192.168.121.1\"" |
  sudo tee -a /etc/sysconfig/network/config >/dev/null
sudo netconfig update -f
