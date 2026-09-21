#!/usr/bin/env bash
# Headless play-test. Requires the standalone Luau CLI on PATH:
#   https://github.com/luau-lang/luau/releases  (luau, luau-compile, luau-analyze)
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== syntax =="
for file in $(find src tests -name '*.luau' ! -name '.bundle.luau'); do
	luau-compile --binary "$file" > /dev/null
done
echo "all files compile"

echo
echo "== lint =="
luau-analyze $(find src -name '*.luau') 2>&1 \
	| grep -viE "unknown global|unknown require|unknown type|cannot be resolved|TypeError: Type" \
	|| true

echo
echo "== place file =="
python3 tools/build_place.py

echo
echo "== simulation =="
python3 tests/bundle.py > /dev/null
luau tests/.bundle.luau
