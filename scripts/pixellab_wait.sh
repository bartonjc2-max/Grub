#!/usr/bin/env bash
# pixellab_wait.sh — block until a PixelLab object/character finishes, then exit.
#
# Run with the Bash tool's run_in_background:true. When the generation reaches a
# terminal state (review / completed / failed) this script exits, and the harness
# fires a <task-notification> — i.e. you get pinged when the image is ready instead
# of manually polling.
#
# Usage:  pixellab_wait.sh <object|character> <id> [max_minutes]
#   e.g.  pixellab_wait.sh object   f5526174-5229-4349-be81-6354eebb3f00 12
#         pixellab_wait.sh character 1e12a98f-9002-43a3-a02d-069c6843df47
#
# Writes the final status line to /tmp/pixellab_wait_<id>.status

set -uo pipefail
KIND="${1:?need 'object' or 'character'}"
ID="${2:?need id}"
MAX_MIN="${3:-12}"
KEY="ed992fa9-5a3a-4e97-9d10-e25c92f59fb1"
TOOL="get_${KIND}"          # get_object / get_character
ARG_KEY="${KIND}_id"        # object_id / character_id
OUT="/tmp/pixellab_wait_${ID}.status"
ENDPOINT="https://api.pixellab.ai/mcp"

deadline=$(( $(date +%s) + MAX_MIN * 60 ))
i=0
while :; do
  i=$((i+1))
  resp=$(curl -sS -X POST "$ENDPOINT" \
    -H "Authorization: Bearer $KEY" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    --max-time 25 \
    -d "{\"jsonrpc\":\"2.0\",\"id\":$i,\"method\":\"tools/call\",\"params\":{\"name\":\"$TOOL\",\"arguments\":{\"${ARG_KEY}\":\"$ID\",\"include_preview\":false}}}" 2>&1)

  # Terminal states the MCP reports in its text payload.
  if echo "$resp" | grep -qE 'status: (review|completed)'; then
    state=$(echo "$resp" | grep -oE 'status: (review|completed)[^"\\]*' | head -1)
    echo "READY ${ID} -> ${state}" | tee "$OUT"
    exit 0
  fi
  if echo "$resp" | grep -q 'status: failed'; then
    echo "FAILED ${ID}" | tee "$OUT"
    exit 1
  fi

  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "TIMEOUT ${ID} after ${MAX_MIN}m" | tee "$OUT"
    exit 2
  fi
  sleep 30
done
