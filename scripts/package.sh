#!/bin/bash
set -euo pipefail
ROOT=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
mkdir -p "$ROOT/build" "$ROOT/dist"
STAGE=$(mktemp -d "$ROOT/build/package.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
PACKAGE="$STAGE/CS2-Mac"
mkdir "$PACKAGE"
for entry in bin lib docs runtime-artifacts.json VERSION LICENSE README.md 'START HERE.txt' 'Install CS2.command'; do
  [ -e "$ROOT/$entry" ] || { printf 'Missing release input: %s\n' "$entry" >&2; exit 1; }
  /usr/bin/ditto --norsrc "$ROOT/$entry" "$PACKAGE/$entry"
done
chmod +x "$PACKAGE/Install CS2.command" "$PACKAGE/bin/cs2-mac"
/usr/bin/ditto -c -k --norsrc --keepParent "$PACKAGE" "$ROOT/dist/CS2-Mac.zip"
(cd "$ROOT/dist" && /usr/bin/shasum -a 256 CS2-Mac.zip > SHA256SUMS)
printf 'Built %s\n' "$ROOT/dist/CS2-Mac.zip"
