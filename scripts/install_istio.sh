#!/usr/bin/env bash
set -exuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "$SCRIPT_DIR"/lib/lib

helm -n kube-system uninstall traefik
helm -n kube-system uninstall traefik-crd

curl -L https://istio.io/downloadIstio | sh -
mv $(find . -name istio*)/bin/istioctl /usr/local/bin/
istioctl install --set profile=demo -y
