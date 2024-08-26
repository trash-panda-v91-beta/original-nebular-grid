#!/bin/sh

set -o errexit
set -o nounset

GID=${1}
NUM_OF_FILES=${2}
FILE=${3}
MEDIA_TYPE="$(basename "$(dirname "$FILE")")"

if [ "${NUM_OF_FILES}" -gt 1 ]; then
  echo "Got ${NUM_OF_FILES} files. Expected to receive only 1 file!"
  exit 1
fi

case "$MEDIA_TYPE" in
"movie")
  API_KEY="${RADARR_API_KEY}"
  COMMAND_NAME="DownloadedMoviesScan"
  URL="${RADARR_URL}"
  ;;
"episode")
  API_KEY="${SONARR_API_KEY}"
  COMMAND_NAME="DownloadedEpisodesScan"
  URL="${SONARR_URL}"
  ;;
*)
  echo "Unsupported media type ${MEDIA_TYPE}!"
  exit 0
  ;;
esac

if ! wget \
  --header="Content-Type: application/json" \
  --header="X-Api-Key: $API_KEY" \
  --post-data="{\"name\": \"${COMMAND_NAME}\", \"path\": \"$FILE\"}" \
  "${URL}/api/v3/command" \
  --output-document=/dev/null --q --tries=1; then
  echo "Failed to send command to ${URL}/api/v3/command"
  exit 1
else
  echo "Successfully sent command to ${URL}/api/v3/command"
fi

if ! wget \
  --post-data="{\"jsonrcp\":\"2.0\",\"id\":\"qwer\",\"method\":\"aria2.removeDownloadResult\",\"params\":[\"token:${RPC_SECRET}\",\"${GID}\"]}" \
  "http://localhost:6800/jsonrpc" \
  --output-document=/dev/null -q --tries=1; then
  echo "Failed to send command to http://localhost:6800/jsonrpc"
  exit 1
else
  echo "Successfully sent command to http://localhost:6800/jsonrpc"
fi
