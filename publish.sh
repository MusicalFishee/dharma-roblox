#!/bin/bash
# Publish Dharma to Roblox so it can be played in Sober (no Studio).
# Prefers the cookie method (full-account auth); falls back to the Open Cloud API key.
# Credentials come from .env (gitignored). See .env.example.
set -e

cd "$(dirname "$0")"

if [ -f .env ]; then
	# shellcheck disable=SC1091
	source .env
fi

: "${DHARMA_PLACE_ID:?Set DHARMA_PLACE_ID in .env}"

echo "[Dharma] Running headless logic tests before publish..."
~/.local/bin/lune run tests/combat.spec >/dev/null && echo "  logic tests OK"

if [ -n "${DHARMA_COOKIE:-}" ]; then
	echo "[Dharma] Building + uploading to place $DHARMA_PLACE_ID (cookie auth)..."
	~/.local/bin/rojo upload \
		--cookie "$DHARMA_COOKIE" \
		--asset_id "$DHARMA_PLACE_ID"
else
	: "${DHARMA_API_KEY:?Set DHARMA_COOKIE (preferred) or DHARMA_API_KEY in .env}"
	: "${DHARMA_UNIVERSE_ID:?Set DHARMA_UNIVERSE_ID in .env}"
	echo "[Dharma] Building + uploading to place $DHARMA_PLACE_ID (API key)..."
	~/.local/bin/rojo upload \
		--api_key "$DHARMA_API_KEY" \
		--universe_id "$DHARMA_UNIVERSE_ID" \
		--asset_id "$DHARMA_PLACE_ID"
fi

echo "[Dharma] Published. Reload the experience in Sober to play the new build."
