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
create_systemd_service powerdns-api-forwarder kubectl port-forward --address=127.0.0.1 service/"$POWERDNS_SVC" 8081:8081
echo "NETCONFIG_DNS_STATIC_SERVERS=127.0.0.1" | sudo tee -a /etc/sysconfig/network/config >/dev/null
source /etc/environment

HOSTNAME_NMN="$(hostname).nmn"
cat <<EOF | sudo tee /tmp/powerdns_records.json >/dev/null
{
  "rrsets": [
    {
      "name": "${HOSTNAME_NMN}.",
      "type": "A",
      "ttl": 3600,
      "changetype": "REPLACE",
      "records": [
        {
          "content": "10.252.0.10",
          "disabled": false
        }
      ]
    }
  ]
}
EOF

kubectl exec -it powerdns-powerdns-helm-889745496-td8kz -- pdnsutil create-zone "$HOSTNAME_NMN"
curl -X PATCH \
  -H "X-API-Key: ${POWERDNS_API_KEY}" \
  -H 'Content-Type: application/json' \
  -d @/tmp/powerdns_records.json \
  http://127.0.0.1:8081/api/v1/servers/localhost/zones/"$HOSTNAME_NMN"

sudo netconfig update -f
