#!/bin/bash
# SPDX-License-Identifier: MIT
# No real Wine/Steam, app activation, HOME replacement or account data is used.
set -eu
set -o pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
fixture=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/cs2mac-launch-tests.XXXXXX")
fixture=$(cd "$fixture" && pwd -P)
trap '/bin/rm -rf "$fixture"' EXIT
CS2MAC_HOME="$fixture/Support space ' quote \$(literal)"
export CS2MAC_HOME
app="$CS2MAC_HOME/runtime/CS2Runtime.app"
prefix="$app/Contents/SharedSupport/prefix"
engine="$app/Contents/SharedSupport/wine"
library="$fixture/Game library ; \$(literal)"
state_app="$app"
state_cap=144
mode=other
pause_action=none
open_log="$fixture/open.log"
prepare_log="$fixture/prepare.log"
messages="$fixture/messages.log"
/bin/mkdir -p "$prefix/drive_c/Program Files (x86)/Steam" "$engine/bin" \
    "$app/Contents/MacOS" "$app/Contents/Frameworks/renderer/dxmt/wine/x86_64-windows" \
    "$app/Contents/Frameworks/renderer/dxmt/wine/x86_64-unix" "$library"
printf 'steam fixture\n' >"$prefix/drive_c/Program Files (x86)/Steam/Steam.exe"
printf 'renderer fixture\n' >"$app/Contents/Frameworks/renderer/dxmt/wine/x86_64-windows/d3d11.dll"
for item in dxgi.dll winemetal.dll; do printf 'renderer fixture\n' >"$app/Contents/Frameworks/renderer/dxmt/wine/x86_64-windows/$item"; done
printf 'renderer fixture\n' >"$app/Contents/Frameworks/renderer/dxmt/wine/x86_64-unix/winemetal.so"
printf '#!/bin/bash\nexit 0\n' >"$app/Contents/MacOS/launcher"
/bin/chmod +x "$app/Contents/MacOS/launcher"
/bin/cat >"$engine/bin/wine" <<'FAKEWINE'
#!/bin/bash
file="$WINEPREFIX/wine-call.$$.txt"
{
    printf 'prefix=%s\nmarker=%s\nmsync=%s\nesync=%s\nconfig=%s\ndllpath=%s\n' \
        "$WINEPREFIX" "$SikarugirAppWine11" "$WINEMSYNC" "$WINEESYNC" "$DXMT_CONFIG" "$WINEDLLPATH_PREPEND"
    printf 'override=%s\n' "${WINEDLLOVERRIDES-unset}"
    printf 'executable=%s\n' "$0"
    for arg in "$@"; do printf 'arg=%s\n' "$arg"; done
} >"$file"
FAKEWINE
/bin/cp "$engine/bin/wine" "$engine/bin/wineserver"
/bin/chmod +x "$engine/bin/wine" "$engine/bin/wineserver"

cs2mac_support_dir() { printf '%s\n' "$CS2MAC_HOME"; }
cs2mac_state_get() {
    case "$1" in
        app_path) printf '%s\n' "$state_app" ;;
        library_path) printf '%s\n' "$library" ;;
        profile) printf '%s\n' quality1440 ;;
        render_cap) printf '%s\n' "$state_cap" ;;
        *) return 1 ;;
    esac
}
cs2mac_note() { printf '%s\n' "$*" >>"$messages"; }
cs2mac_error() { printf '%s\n' "$*" >>"$messages"; }
cs2mac_prepare_game() { printf '%s\n' "$@" >>"$prepare_log"; }
cs2mac_launch_options() { printf '%s\n' '-windowed -noborder -w 2560 -h 1440 +exec cs2mac.cfg'; }
. "$repo/lib/launch.sh"

_cs2mac_launch_process_rows() {
    printf '101 /Applications/Steam.app/Contents/MacOS/steam_osx\n'
    printf '202 /unrelated/Wine.app/Contents/bin/wineserver\n'
    case "$mode" in
        steam|game) printf '303 C:\\Program Files (x86)\\Steam\\Steam.exe\n' ;;
    esac
    [ "$mode" != game ] || printf '404 V:\\SteamLibrary\\game\\bin\\win64\\cs2.exe\n'
    return 0
}
_cs2mac_launch_text_paths() {
    case "$1" in
        101) printf 'n/Applications/Steam.app/Contents/MacOS/steam_osx\n' ;;
        202) printf 'n/unrelated/Wine.app/Contents/bin/wineserver\n' ;;
        303|404) printf 'n%s/bin/wine\n' "$engine" ;;
        *) return 1 ;;
    esac
}
_cs2mac_launch_open() { printf '%s\n' "$1" >>"$open_log"; }
_cs2mac_launch_pause() { [ "$pause_action" != close ] || mode=other; return 0; }

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_file() { [ -f "$1" ] || fail "missing file: $1"; }
assert_contains() { /usr/bin/grep -F -- "$2" "$1" >/dev/null || fail "missing expected text: $2"; }
assert_absent() { [ ! -e "$1" ] || fail "unexpected path: $1"; }
clear_calls() { /bin/rm -f "$prefix"/wine-call.*.txt "$open_log" "$prepare_log"; }
wine_calls() { /usr/bin/find "$prefix" -maxdepth 1 -name 'wine-call.*.txt' -type f -print; }
expect_failure() { if "$@"; then fail 'command unexpectedly succeeded'; fi; }

# A foreign Wine server and native Steam must not make this a warm launch.
clear_calls
mode=other
cs2mac_play
assert_file "$open_log"
[ "$(cat "$open_log")" = "$app" ] || fail 'cold launch opened another app'
[ -z "$(wine_calls)" ] || fail 'cold launch bypassed the official wrapper'
assert_contains "$prepare_log" "$library"

# Existing managed Windows Steam gets normal AppID730, with pinned env and
# literal quoted paths. Inherited Wine overrides are deliberately excluded.
clear_calls
mode=steam
WINEDLLOVERRIDES='malicious-global-override'
export WINEDLLOVERRIDES
cs2mac_play
wait
unset WINEDLLOVERRIDES
assert_absent "$open_log"
call=$(wine_calls)
assert_file "$call"
assert_contains "$call" "prefix=$prefix"
assert_contains "$call" 'marker=1'
assert_contains "$call" 'msync=1'
assert_contains "$call" 'esync=0'
assert_contains "$call" 'config=[cs2.exe];d3d11.preferredMaxFrameRate=144;'
assert_contains "$call" "dllpath=$app/Contents/Frameworks/renderer/dxmt/wine"
assert_contains "$call" 'override=unset'
assert_contains "$call" "arg=$prefix/drive_c/Program Files (x86)/Steam/Steam.exe"
assert_contains "$call" 'arg=-applaunch'
assert_contains "$call" 'arg=730'

# Never rewrite video/profile files or issue another launch when the managed
# game is running; unrelated processes did not trip the earlier guard.
clear_calls
mode=game
cs2mac_play
assert_absent "$prepare_log"
assert_absent "$open_log"
[ -z "$(wine_calls)" ] || fail 'already-running game received another launch'

# Tampered state and executable/prefix redirection must fail before execution.
clear_calls
mode=steam
/bin/mkdir -p "$fixture/Foreign.app"
state_app="$fixture/Foreign.app"
expect_failure cs2mac_play
state_app="$app"
/bin/mv "$engine/bin/wine" "$fixture/saved-wine"
/bin/ln -s "$fixture/saved-wine" "$engine/bin/wine"
expect_failure cs2mac_play
/bin/rm "$engine/bin/wine"
/bin/mv "$fixture/saved-wine" "$engine/bin/wine"
/bin/mv "$prefix" "$fixture/saved-prefix"
/bin/ln -s "$fixture/saved-prefix" "$prefix"
expect_failure cs2mac_play
/bin/rm "$prefix"
/bin/mv "$fixture/saved-prefix" "$prefix"
state_cap='144; touch injected'
expect_failure cs2mac_play
state_cap=144
assert_absent "$prepare_log"
assert_absent "$open_log"
[ -z "$(wine_calls)" ] || fail 'invalid state executed Wine'

# An injection-looking library value is one literal prepare argument. Nothing
# is evaluated and no account/process environment data is read.
clear_calls
library="$fixture/\$(touch injected) ; ' library"
/bin/mkdir -p "$library"
mode=other
cs2mac_play
assert_contains "$prepare_log" "$library"
assert_absent "$repo/injected"
library="$fixture/Game library ; \$(literal)"

# Explicit stop ignores foreign runtimes. A managed stop requests ordinary
# closure, then a bounded prefix-specific server stop only if still present.
clear_calls
mode=other
cs2mac_stop
[ -z "$(wine_calls)" ] || fail 'stop touched an unrelated process'
mode=game
pause_action=close
cs2mac_stop
wait
combined="$fixture/combined.txt"
cat "$prefix"/wine-call.*.txt >"$combined"
assert_contains "$combined" 'arg=taskkill'
assert_contains "$combined" 'arg=/IM'
assert_contains "$combined" 'arg=cs2.exe'
assert_contains "$combined" 'arg=-shutdown'
if /usr/bin/grep -F 'arg=-k' "$combined" >/dev/null; then fail 'graceful stop killed the server'; fi
clear_calls
mode=steam
pause_action=none
cs2mac_stop
wait
cat "$prefix"/wine-call.*.txt >"$combined"
assert_contains "$combined" 'arg=-k'
assert_contains "$combined" "executable=$engine/bin/wineserver"
assert_contains "$combined" "prefix=$prefix"
if /usr/bin/grep -F 'arg=/F' "$combined" >/dev/null; then fail 'forced taskkill used'; fi

# Doctor is static: no process inventory, Wine execution or window opening.
clear_calls
mode=other
/bin/mv "$prefix/drive_c/Program Files (x86)/Steam/Steam.exe" "$fixture/steam-executable"
expect_failure cs2mac_play
assert_absent "$open_log"
_cs2mac_launch_process_rows() { fail 'doctor inspected processes'; }
cs2mac_doctor
assert_contains "$messages" 'Windows Steam is not installed yet'
/bin/mv "$fixture/steam-executable" "$prefix/drive_c/Program Files (x86)/Steam/Steam.exe"
cs2mac_doctor
assert_contains "$messages" 'CS2 is not installed'
assert_absent "$open_log"
[ -z "$(wine_calls)" ] || fail 'doctor ran Wine'
/bin/mv "$app/Contents/Frameworks/renderer/dxmt/wine/x86_64-windows/d3d11.dll" "$fixture/renderer"
expect_failure cs2mac_doctor
/bin/mv "$fixture/renderer" "$app/Contents/Frameworks/renderer/dxmt/wine/x86_64-windows/d3d11.dll"

# Launcher includes only the fixed toolkit allowlist, survives spaces/quotes,
# and invokes the installed CLI, independent of the original checkout path.
CS2MAC_SOURCE_DIR="$fixture/Source checkout ' \$(literal)"
/bin/mkdir -p "$CS2MAC_SOURCE_DIR/bin" "$CS2MAC_SOURCE_DIR/lib"
/bin/cat >"$CS2MAC_SOURCE_DIR/bin/cs2-mac" <<'FAKECLI'
#!/bin/bash
printf '%s\n' "$@" >"$CS2MAC_HOME/launcher-invoked.txt"
FAKECLI
/bin/chmod +x "$CS2MAC_SOURCE_DIR/bin/cs2-mac"
printf 'fixture\n' >"$CS2MAC_SOURCE_DIR/lib/common.sh"
for item in runtime-artifacts.json VERSION LICENSE; do printf 'fixture\n' >"$CS2MAC_SOURCE_DIR/$item"; done
printf 'not copied\n' >"$CS2MAC_SOURCE_DIR/private-fixture.txt"
launcher="$fixture/Applications space ' quote/CS2.app"
cs2mac_build_launcher "$launcher"
assert_file "$CS2MAC_HOME/toolkit/bin/cs2-mac"
assert_absent "$CS2MAC_HOME/toolkit/private-fixture.txt"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$launcher/Contents/Info.plist")" = dev.cs2mac.launcher ] || fail 'invalid launcher plist'
/bin/bash "$launcher/Contents/MacOS/launch"
assert_contains "$CS2MAC_HOME/launcher-invoked.txt" 'play'

# Source only the generated functions, replacing the osascript boundary before
# calling main. This exercises success/error handling without any host UI.
. "$launcher/Contents/MacOS/launch"
alert_args="$fixture/alert-arguments.txt"
alert_source="$fixture/alert-source.applescript"
_cs2mac_launcher_osascript() {
    printf '%s\n' "$@" >"$alert_args"
    /bin/cat >"$alert_source"
}
_cs2mac_launcher_main
assert_absent "$alert_args"
failure_text=$(/bin/cat <<'FAILURETEXT'
External SSD missing: "drive's name"; $(touch injected)
" & (do shell script "touch injected") & "
Connect the selected game drive before playing.
FAILURETEXT
)
export CS2MAC_TEST_FAILURE_TEXT="$failure_text"
/bin/cat >"$CS2MAC_HOME/toolkit/bin/cs2-mac" <<'FAILCLI'
#!/bin/bash
printf '%s\n' "$CS2MAC_TEST_FAILURE_TEXT" >&2
exit 7
FAILCLI
if _cs2mac_launcher_main; then fail 'failed CLI became success'; else status=$?; fi
[ "$status" -eq 7 ] || fail 'launcher lost CLI exit status'
printf '%s\n' - "$failure_text" >"$fixture/expected-alert-arguments.txt"
/usr/bin/cmp "$fixture/expected-alert-arguments.txt" "$alert_args" || fail 'alert changed or interpolated error argv'
assert_contains "$alert_source" 'message (item 1 of argv)'
if /usr/bin/grep -F 'do shell script' "$alert_source" >/dev/null; then fail 'error text entered AppleScript source'; fi
assert_absent "$repo/injected"
unset CS2MAC_TEST_FAILURE_TEXT
/bin/mv "$CS2MAC_HOME/toolkit/bin/cs2-mac" "$fixture/saved-cli"
expect_failure _cs2mac_launcher_main
assert_contains "$alert_args" 'The installed toolkit is missing. Run cs2-mac setup again.'
/bin/mv "$fixture/saved-cli" "$CS2MAC_HOME/toolkit/bin/cs2-mac"

/bin/mkdir -p "$fixture/Other/CS2.app/Contents"
printf 'unrelated\n' >"$fixture/Other/CS2.app/Contents/Info.plist"
expect_failure cs2mac_build_launcher "$fixture/Other/CS2.app"
/bin/ln -s "$fixture/private-fixture" "$CS2MAC_SOURCE_DIR/lib/redirect"
expect_failure cs2mac_build_launcher "$launcher"
assert_absent "$repo/injected"
printf 'Launch tests passed (fixtures only).\n'
