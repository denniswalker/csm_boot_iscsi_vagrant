#!/usr/bin/env bash
set -exuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "$SCRIPT_DIR"/scripts/lib/lib # Provides STAGES array

FROM_STAGE="$1"

if [[ -z "$FROM_STAGE" ]]; then
  echo "Please provide one of the following args: ${STAGES[@]}"
  echo "No stage provided, exiting."
  exit 1
fi

for i in "${!STAGES[@]}"; do
  if [[ "${STAGES[$i]}" == "$FROM_STAGE" ]]; then
    echo "Index of '$FROM_STAGE' is: $i"
    START_STAGE_INDEX=$i
    break
  fi
done

PREVIOUS_STAGE_INDEX=$((START_STAGE_INDEX - 1))

vagrant snapshot restore ncn "${STAGES[$PREVIOUS_STAGE_INDEX]}"
vagrant ssh ncn -c "ls /vagrant" # Reconnects the nfs mount
"$SCRIPT_DIR"/up.sh "$FROM_STAGE"
