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

curl "${URL}/api/v3/command" -X POST \
  --fail \
  --header "Content-Type: Application/JSON" \
  --header "X-Api-Key: $API_KEY" \
  --data "{\"name\": \"${COMMAND_NAME}\", \"path\": \"$FILE\"}"

curl "http://localhost:6800/jsonrpc" \
  --fail \
  --data "{\"jsonrcp\":\"2.0\",\"id\":\"qwer\",\"method\":\"aria2.removeDownloadResult\",\"params\":[\"token:${RPC_SECRET}\",\"${GID}\"]}"
