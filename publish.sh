#!/bin/bash
# Publish Dharma to Roblox via Open Cloud, so it can be played in Sober (no Studio).
# Reads credentials from .env (which is gitignored). See .env.example.
set -e

cd "$(dirname "$0")"

if [ -f .env ]; then
	# shellcheck disable=SC1091
	source .env
fi

: "${DHARMA_API_KEY:?Set DHARMA_API_KEY in .env (from create.roblox.com/credentials)}"
: "${DHARMA_UNIVERSE_ID:?Set DHARMA_UNIVERSE_ID in .env}"
: "${DHARMA_PLACE_ID:?Set DHARMA_PLACE_ID in .env}"

echo "[Dharma] Running headless logic tests before publish..."
~/.local/bin/lune run tests/combat.spec >/dev/null && echo "  logic tests OK"

echo "[Dharma] Building + uploading to place $DHARMA_PLACE_ID ..."
~/.local/bin/rojo upload \
	--api_key "$DHARMA_API_KEY" \
	--universe_id "$DHARMA_UNIVERSE_ID" \
	--asset_id "$DHARMA_PLACE_ID"

echo "[Dharma] Published. Reload the experience in Sober to play the new build."
