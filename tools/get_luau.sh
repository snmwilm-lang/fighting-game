#!/usr/bin/env bash
# Installs the Luau command-line tools (luau, luau-analyze, luau-compile) the tests need, from
# the official releases (github.com/luau-lang/luau). Nothing to do if luau is already there.
#   bash tools/get_luau.sh [folder]        (default: ~/.local/bin)
set -euo pipefail
DEST="${1:-$HOME/.local/bin}"
if command -v luau >/dev/null 2>&1; then
	echo "luau is already on the PATH: $(command -v luau)"
	exit 0
fi
mkdir -p "$DEST"
TMP="$(mktemp -d)"
curl -sSL -o "$TMP/luau.zip" https://github.com/luau-lang/luau/releases/latest/download/luau-ubuntu.zip
python3 -I -c "import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$TMP/luau.zip" "$DEST"
chmod +x "$DEST"/luau*
rm -rf "$TMP"
echo "luau installed in $DEST: run  export PATH=\"$DEST:\$PATH\""
