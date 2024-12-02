#!/usr/bin/env bash
set -exuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "$SCRIPT_DIR"/lib/lib

# Install PowerDNS
git clone https://github.com/cdwv/powerdns-helm
cd powerdns-helm
helm install . --generate-name
echo "127.0.0.1 api-gw-service-nmn.local" >>/etc/hosts
cd "$OLDPWD"

# Configure PowerDNS as the DNS server
# Wait for powerdns-helm deployment to be ready
timeout=30 # Total timeout in seconds
interval=2 # Interval between checks in seconds
elapsed=0

echo "Waiting for powerdns-helm chart to finish deploying..."

while true; do
  # Check if the deployment is ready
  if kubectl get pods -l app=powerdns-helm -A -o json | jq -e '.items[] | select(.status.phase == "Running")' >/dev/null 2>&1; then
    echo "powerdns-helm chart successfully deployed!"
    break
  fi

  # Exit if timeout is reached
  if [ "$elapsed" -ge "$timeout" ]; then
    echo "Timeout reached: powerdns-helm chart did not finish deploying within $timeout seconds."
    exit 1
  fi

  # Wait for the interval and increment elapsed time
  sleep "$interval"
  elapsed=$((elapsed + interval))
done

POWERDNS_ENDPOINT=$(kubectl get svc -l app=powerdns-helm -A -o json | jq -r ".items[0].spec.clusterIP")
echo "export POWERDNS_ENDPOINT=${POWERDNS_ENDPOINT}" | sudo tee -a /etc/environment >/dev/null
POWERDNS_API="$(kubectl get secret powerdns-api-key -o json | jq -r '.data.POWERDNS_API_KEY' | base64 -d)"
echo "export POWERDNS_API_KEY=${POWERDNS_API}" | sudo tee -a /etc/environment >/dev/null
POWERDNS_SVC="$(kubectl get svc -l app=powerdns-helm -A -o json | jq -r ".items[0].metadata.name")"
echo "export POWERDNS_SVC=${POWERDNS_SVC}" | sudo tee -a /etc/environment >/dev/null
create_systemd_service powerdns-forwarder kubectl port-forward --address=0.0.0.0 service/"$POWERDNS_SVC" 53:53
echo "NETCONFIG_DNS_STATIC_SERVERS=127.0.0.1" | sudo tee -a /etc/sysconfig/network/config >/dev/null
sudo netconfig update -f
