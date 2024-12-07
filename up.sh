#!/usr/bin/env bash
set -exuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "$SCRIPT_DIR"/scripts/lib/lib # Provides STAGES array

# Accepts an optional argument to start at a specific stage
START_STAGE=${1:-packages}

for i in "${!STAGES[@]}"; do
  if [[ "${STAGES[$i]}" == "$START_STAGE" ]]; then
    echo "Index of '$START_STAGE' is: $i"
    START_STAGE_INDEX=$i
    break
  fi
done

if ! vagrant snapshot list ncn | grep base; then
  vagrant up ncn --no-provision
  vagrant snapshot save ncn base
fi

for stage in ${STAGES[@]:$START_STAGE_INDEX}; do
  vagrant ssh ncn -c "sudo /vagrant/scripts/install_${stage}.sh"
  vagrant snapshot save ncn "$stage" --force
done
