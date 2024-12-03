#!/usr/bin/env bash
set -exuo pipefail

if ! vagrant snapshot list ncn 2>/dev/null | grep base; then
  vagrant up ncn --no-provision
  vagrant snapshot save ncn base
fi
#          0       1     2     3        4    5    6    7    8    9
STAGES=(packages python3 k3s powerdns minio ims spire sbps)

for stage in ${STAGES[@]:4}; do
  vagrant ssh ncn -c "sudo /vagrant/scripts/install_${stage}.sh"
  vagrant snapshot save ncn "$stage" --force
done
