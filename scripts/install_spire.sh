#!/usr/bin/env bash
set -exuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "$SCRIPT_DIR"/lib/lib

# Install Spire
cd /root
curl -s -N -L https://github.com/spiffe/spire/releases/download/v1.10.4/spire-1.10.4-linux-amd64-musl.tar.gz | tar xz
spire_dir=$(find /root -name spire*)
create_systemd_service spire-server "$spire_dir"/bin/spire-server run -config "$spire_dir"/conf/server/server.conf
wait_until_service_active spire-server
#bin/spire-server healthcheck
TOKEN=$("$spire_dir"/bin/spire-server token generate -spiffeID spiffe://example.org/host | cut -d " " -f 2)
create_systemd_service spire-agent "$spire_dir"/bin/spire-agent run -config "$spire_dir"/conf/agent/agent.conf -joinToken "$TOKEN"
mkdir -p /opt/cray/cray-spire
ln -s "$spire_dir"/bin/spire-agent /opt/cray/cray-spire/spire-agent
ln -s "$spire_dir"/bin/spire-agent /opt/cray/cray-spire/sbps-marshall-spire-agent
