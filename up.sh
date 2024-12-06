#!/usr/bin/env bash
set -exuo pipefail

#          0       1     2     3        4    5    6    7    8    9    10
STAGES=(packages python3 k3s istio powerdns kea minio ims spire tftp sbps)

# Accepts an optional argument to start at a specific stage
START_STAGE=${1:-packages}

for i in "${!STAGES[@]}"; do
  if [[ "${STAGES[$i]}" == "$START_STAGE" ]]; then
    echo "Index of '$START_STAGE' is: $i"
    START_STAGE_INDEX=$i
    break
  fi
done

if ! vagrant snapshot list ncn 2>/dev/null | grep base; then
  vagrant up ncn --no-provision
  vagrant snapshot save ncn base
fi

for stage in ${STAGES[@]:$START_STAGE_INDEX}; do
  vagrant ssh ncn -c "sudo /vagrant/scripts/install_${stage}.sh"
  vagrant snapshot save ncn "$stage" --force
done
