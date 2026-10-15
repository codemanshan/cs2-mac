#!/bin/bash
set -euo pipefail
ROOT=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export CS2MAC_SOURCE_DIR="$ROOT"
. "$ROOT/lib/common.sh"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/cs2mac-common.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
export CS2MAC_HOME="$WORK/support"
mkdir -p "$CS2MAC_HOME"
count=0
ok() { count=$((count + 1)); printf 'ok %s - %s\n' "$count" "$1"; }

for cap in 0 60 120 144 240 360; do cs2mac_validate_cap "$cap"; done
for cap in '' -1 361 '144; touch bad' '$HOME' 1.5 9999; do
  if cs2mac_validate_cap "$cap"; then printf 'Invalid cap accepted\n' >&2; exit 1; fi
done
ok 'cap values cannot contain shell syntax or exceed supported range'
[ "$(cs2mac_choose_profile balanced1080)" = balanced1080 ]
[ "$(cs2mac_launch_options quality1440)" = '-windowed -noborder -w 2560 -h 1440 +exec cs2mac.cfg' ]
ok 'profile options preserve a single renderer limiter'

app="$CS2MAC_HOME/runtime/CS2Runtime.app"
library="$WORK/library with spaces and 'quotes'"
mkdir -p "$app/Contents" "$library"
/usr/bin/plutil -create xml1 "$app/Contents/Info.plist"
cs2mac_apply_profile "$app" "$library" 144 quality1440
[ "$(/usr/bin/plutil -extract 'CLI Custom Commands' raw -o - "$app/Contents/Info.plist")" = "export DXMT_CONFIG='[cs2.exe];d3d11.preferredMaxFrameRate=144;'" ]
[ "$(/usr/bin/plutil -extract 'Program Flags' raw -o - "$app/Contents/Info.plist")" = '-silent -applaunch 730' ]
ok 'wrapper gets explicit CS2-scoped renderer cap with no account or library text evaluated'
cs2mac_write_state "$app" "$library" quality1440 144
[ "$(cs2mac_state_get library_path)" = "$library" ]
if cs2mac_write_state "$app" /other balanced1080 60 >/dev/null 2>&1; then exit 1; fi
[ "$(cs2mac_state_get render_cap)" = 144 ]
ok 'state paths round-trip and completed state is preserved'

game="$library/steamapps/common/Counter-Strike Global Offensive"
mkdir -p "$game/game/csgo/cfg"
printf unrelated > "$game/game/csgo/cfg/cs2mac.cfg"
if cs2mac_prepare_game "$app" "$library" quality1440 144 >/dev/null 2>&1; then exit 1; fi
[ "$(cat "$game/game/csgo/cfg/cs2mac.cfg")" = unrelated ]
rm "$game/game/csgo/cfg/cs2mac.cfg"
cs2mac_prepare_game "$app" "$library" quality1440 144
/usr/bin/grep -qx 'fps_max 0' "$game/game/csgo/cfg/cs2mac.cfg"
if /usr/bin/grep -q 'map de_' "$game/game/csgo/cfg/cs2mac.cfg"; then exit 1; fi
ok 'game config is scoped, does not overwrite unrelated files, and never auto-loads practice'

video="$app/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/userdata/123/730/local/cfg/cs2_video.txt"
mkdir -p "$(dirname "$video")"
printf '"video.cfg"\n{\n\t"Version" "16"\n\t"unknown" "preserve"\n}\n' > "$video"
original=$(/usr/bin/shasum -a 256 "$video")
cs2mac_prepare_game "$app" "$library" quality1440 144 >/dev/null 2>&1
[ "$(/usr/bin/shasum -a 256 "$video")" = "$original" ]
[ -f "$video.cs2mac-original" ]
ok 'unknown video format is preserved and original backup retained'

rm "$video" "$video.cs2mac-original"
cp "$ROOT/tests/fixtures/cs2_video.txt" "$video"
cs2mac_prepare_game "$app" "$library" quality1440 144
/usr/bin/grep -Eq '"setting.defaultres"[[:space:]]+"2560"' "$video"
/usr/bin/grep -Eq '"setting.msaa_samples"[[:space:]]+"2"' "$video"
/usr/bin/grep -q 'keep this value' "$video"
cmp "$ROOT/tests/fixtures/cs2_video.txt" "$video.cs2mac-original"
[ -f "$video.cs2mac-profile" ]
printf '\n// A later user change\n' >> "$video"
changed=$(/usr/bin/shasum -a 256 "$video")
cs2mac_prepare_game "$app" "$library" quality1440 144
[ "$(/usr/bin/shasum -a 256 "$video")" = "$changed" ]
ok 'preset applies once, preserves unknown fields, backs up the original, and retains later user edits'

printf '%s common-helper tests passed.\n' "$count"
