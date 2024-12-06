#!/usr/bin/env bash
set -exuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "$SCRIPT_DIR"/lib/lib

# Install PowerDNS
if [[ -d /root/powerdns-helm ]]; then
  rm -rf /root/powerdns-helm
fi
cd /root
git clone https://github.com/cdwv/powerdns-helm
cd powerdns-helm
helm install powerdns .

# Configure PowerDNS as the DNS server
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
POWERDNS_ENDPOINT=$(kubectl get svc -l app=powerdns-helm -A -o json | jq -r ".items[0].spec.clusterIP")
echo "export POWERDNS_ENDPOINT=${POWERDNS_ENDPOINT}" | sudo tee -a /etc/environment >/dev/null
POWERDNS_API="$(kubectl get secret powerdns-api-key -o json | jq -r '.data.POWERDNS_API_KEY' | base64 -d)"
echo "export POWERDNS_API_KEY=${POWERDNS_API}" | sudo tee -a /etc/environment >/dev/null
POWERDNS_SVC="$(kubectl get svc -l app=powerdns-helm -A -o json | jq -r ".items[0].metadata.name")"
echo "export POWERDNS_SVC=${POWERDNS_SVC}" | sudo tee -a /etc/environment >/dev/null
create_systemd_service powerdns-forwarder kubectl port-forward --address=0.0.0.0 service/"$POWERDNS_SVC" 53:53
create_systemd_service powerdns-api-forwarder kubectl port-forward --address=0.0.0.0 service/"$POWERDNS_SVC" 8088:8081

echo "NETCONFIG_DNS_STATIC_SERVERS='10.252.0.10 172.18.0.2 192.168.121.1'" | sudo tee -a /etc/sysconfig/network/config >/dev/null
sudo netconfig update -f
source /etc/environment

HOSTNAME_NMN="$(hostname).nmn"

kubectl exec -it svc/powerdns-powerdns-helm -- pdnsutil create-zone "$HOSTNAME_NMN" "ns1.${HOSTNAME_NMN}"
kubectl exec -it svc/powerdns-powerdns-helm -- pdnsutil add-record "$HOSTNAME_NMN" ns1 A 10.252.0.10
kubectl exec -it svc/powerdns-powerdns-helm -- pdnsutil add-record "$HOSTNAME_NMN" . A 10.252.0.10

# Istio forwarder
# cat <<EOF | kubectl apply -f -
# apiVersion: networking.istio.io/v1beta1
# kind: ServiceEntry
# metadata:
#   name: powerdns-tcp-entry
#   namespace: default
# spec:
#   hosts:
#     - powerdns-powerdns-helm.default.svc.cluster.local
#   addresses:
#     - 0.0.0.0/0
#   ports:
#     - number: 53
#       name: tcp-dns
#       protocol: TCP
#   location: MESH_INTERNAL
# EOF

cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: dns-ingressgateway
  namespace: default
spec:
  selector:
    istio: istio-system/ingressgateway
  servers:
    - port:
        number: 53
        name: tcp-dns
        protocol: TCP
      hosts:
        - "*"
    - port:
        number: 53
        name: udp-dns
        protocol: UDP
      hosts:
        - "*"
EOF

cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: powerdns-tcp-virtualservice
  namespace: default
spec:
  hosts:
    - "*"
  gateways:
    - default/dns-ingressgateway
  tcp:
    - match:
        - port: 53
      route:
        - destination:
            host: powerdns-powerdns-helm.default.svc.cluster.local
            port:
              number: 53
EOF
