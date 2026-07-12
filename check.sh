#!/bin/bash
# One-command verification: type-check every script (incl. Roblox API usage)
# and run all headless logic tests. Run before every publish.
set -e
cd "$(dirname "$0")"

BIN="$HOME/.local/bin"

echo "== regenerating sourcemap =="
"$BIN/rojo" sourcemap default.project.json --output sourcemap.json >/dev/null

echo "== type-checking (luau-lsp + Roblox defs) =="
"$BIN/luau-lsp" analyze \
	--sourcemap sourcemap.json \
	--defs globalTypes.d.luau \
	--ignore 'tests/**' \
	src

echo "== headless logic tests (lune) =="
fail=0
for spec in tests/*.spec.luau; do
	name="${spec%.luau}"
	if ! "$BIN/lune" run "$name" | tail -1; then
		fail=1
	fi
done

if [ "$fail" -ne 0 ]; then
	echo "SOME TESTS FAILED"
	exit 1
fi
echo "ALL CHECKS PASSED"
