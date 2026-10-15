#!/bin/bash
# Synthetic fixtures only. Never invokes Wine, Steam, codesign, or a real app.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/cs2mac-install-test.XXXXXX")
trap '/bin/rm -rf "$TMP"' EXIT
export CS2MAC_HOME="$TMP/support" CS2MAC_SOURCE_DIR="$ROOT"
. "$ROOT/lib/common.sh"
. "$ROOT/lib/install.sh"

passed=0
ok() { passed=$((passed + 1)); printf 'ok %s - %s\n' "$passed" "$1"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

printf fixture > "$TMP/hash"
hash=$(/usr/bin/shasum -a 256 "$TMP/hash"); hash=${hash%% *}
cs2mac_install_verify "$hash" "$TMP/hash" || fail checksum
if cs2mac_install_verify aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa "$TMP/hash"; then fail 'wrong hash accepted'; fi
ln -s "$TMP/hash" "$TMP/hash-link"
if cs2mac_install_verify "$hash" "$TMP/hash-link"; then fail 'symlink cache accepted'; fi
ok 'checksum succeeds only for matching regular file'

cs2mac_install_relative_safe 'Contents/Frameworks/../SharedSupport' || fail 'safe relative link rejected'
if cs2mac_install_relative_safe 'Contents/../../outside'; then fail 'escaping link accepted'; fi
if cs2mac_install_relative_safe '/outside'; then fail 'absolute link accepted'; fi
ok 'symlink targets stay inside archive root'

mkdir -p "$TMP/archive/fixture/Contents" "$TMP/extract"
printf original > "$TMP/archive/fixture/Contents/data"
ln -s data "$TMP/archive/fixture/Contents/link"
/usr/bin/tar -cf "$TMP/safe.tar" -C "$TMP/archive" fixture
cs2mac_install_extract "$TMP/safe.tar" "$TMP/extract" fixture
[ "$(cat "$TMP/extract/fixture/Contents/link")" = original ] || fail extraction
ok 'valid archive and relative symlink extract'

mkdir "$TMP/wrong-root"
if (cs2mac_install_extract "$TMP/safe.tar" "$TMP/wrong-root" wrong) >/dev/null 2>&1; then fail 'wrong archive root accepted'; fi
ok 'unexpected archive root fails closed'

mkdir -p "$TMP/evil/fixture" "$TMP/evil-extract"
ln -s ../outside "$TMP/evil/fixture/escape"
/usr/bin/tar -cf "$TMP/evil.tar" -C "$TMP/evil" fixture
if (cs2mac_install_extract "$TMP/evil.tar" "$TMP/evil-extract" fixture) >/dev/null 2>&1; then fail 'root symlink escape accepted'; fi
ok 'root-level escaping symlink is rejected'

cs2mac_setup --library "$TMP/library" --profile quality1440 --refresh-hz 144 --dry-run >/dev/null
[ ! -e "$CS2MAC_HOME" ] && [ ! -e "$TMP/library" ] || fail 'dry-run wrote files'
ok 'dry-run creates no support, library, or runtime'

mkdir -p "$CS2MAC_HOME/runtime/CS2Runtime.app"
printf preserve > "$CS2MAC_HOME/runtime/CS2Runtime.app/existing"
if (cs2mac_setup --library "$TMP/library" --profile quality1440 --refresh-hz 144 --dry-run) >/dev/null 2>&1; then fail 'existing runtime accepted'; fi
[ "$(cat "$CS2MAC_HOME/runtime/CS2Runtime.app/existing")" = preserve ] || fail 'existing runtime changed'
rm -rf "$CS2MAC_HOME"
ok 'existing runtime is refused and preserved'

# Tiny upstream-shaped archives. The only executed launcher is this fixture.
mkdir -p "$TMP/template/Template-1.0.22.app/Contents/MacOS" "$TMP/wine/wswine.bundle/bin"
/usr/bin/plutil -create xml1 "$TMP/template/Template-1.0.22.app/Contents/Info.plist"
/usr/bin/plutil -insert 'Skip Gecko' -integer 0 "$TMP/template/Template-1.0.22.app/Contents/Info.plist"
/usr/bin/plutil -insert 'Skip Mono' -integer 0 "$TMP/template/Template-1.0.22.app/Contents/Info.plist"
cat > "$TMP/template/Template-1.0.22.app/Contents/MacOS/launcher" <<'FIXTURE'
#!/bin/bash
set -eu
[ "$1" = WSS-wineprefixcreate ] || exit 99
[ ! -f "${CS2MAC_FIXTURE_FAIL:-/nonexistent}" ] || exit 23
contents=$(cd "$(dirname "$0")/.." && pwd)
[ "$(/usr/libexec/PlistBuddy -c 'Print :WINEMSYNC' "$contents/Info.plist")" = 1 ] || exit 91
[ "$(/usr/libexec/PlistBuddy -c 'Print :WINEESYNC' "$contents/Info.plist")" = 0 ] || exit 92
mkdir -p "$contents/SharedSupport/prefix/dosdevices" "$contents/SharedSupport/prefix/drive_c"
printf '%s\n' synthetic-prefix > "$contents/SharedSupport/prefix/fixture-marker"
[ -z "${CS2MAC_FIXTURE_BOOT_LOG:-}" ] || printf 'bootstrap\n' >> "$CS2MAC_FIXTURE_BOOT_LOG"
FIXTURE
chmod +x "$TMP/template/Template-1.0.22.app/Contents/MacOS/launcher"
printf '#!/bin/bash\nexit 99\n' > "$TMP/wine/wswine.bundle/bin/wine"
chmod +x "$TMP/wine/wswine.bundle/bin/wine"
/usr/bin/tar -cf "$TMP/template.tar" -C "$TMP/template" Template-1.0.22.app
/usr/bin/tar -cf "$TMP/wine.tar" -C "$TMP/wine" wswine.bundle
cs2mac_install_require_host() { :; }
cs2mac_install_verify_runtime() { [ -x "$1/Contents/MacOS/launcher" ]; }
cs2mac_install_download() {
    case "$1" in
        "$CS2MAC_TEMPLATE_URL") cp "$TMP/template.tar" "$3" ;;
        "$CS2MAC_WINE_URL") cp "$TMP/wine.tar" "$3" ;;
        *) fail 'fixture setup attempted a Steam or unknown download' ;;
    esac
}
cs2mac_build_launcher() {
    [ ! -f "${CS2MAC_FIXTURE_LAUNCHER_FAIL:-/nonexistent}" ] || return 1
    printf fixture > "$CS2MAC_HOME/launcher-fixture"
}
cs2mac_setup --library "$TMP/library with spaces" --profile quality1440 --refresh-hz 144 --no-steam-install >/dev/null
app="$CS2MAC_HOME/runtime/CS2Runtime.app"
[ "$(cat "$app/Contents/SharedSupport/prefix/fixture-marker")" = synthetic-prefix ] || fail bootstrap
[ "$(/usr/bin/readlink "$app/Contents/SharedSupport/prefix/dosdevices/v:")" = "$TMP/library with spaces" ] || fail 'library mapping'
[ "$(cs2mac_state_get render_cap)" = 144 ] || fail state
[ "$(/usr/libexec/PlistBuddy -c 'Print :WINEMSYNC' "$app/Contents/Info.plist")" = 1 ] || fail msync
[ "$(/usr/libexec/PlistBuddy -c 'Print :WINEESYNC' "$app/Contents/Info.plist")" = 0 ] || fail esync
ok 'fixture setup bootstraps only new prefix, stores state, maps chosen library, and applies MSync'

if (cs2mac_setup --library "$TMP/other-library" --profile balanced1080 --refresh-hz 60 --no-steam-install) >/dev/null 2>&1; then fail 'second setup overwrote runtime'; fi
[ ! -e "$TMP/other-library" ] || fail 'refused setup created library'
ok 'repeat setup refuses overwrite before creating another library'

# Failure after publishing a new runtime preserves it for inspection, deletes
# temporary extraction work, and never records a completed installation state.
export CS2MAC_HOME="$TMP/failed-support"
export CS2MAC_FIXTURE_FAIL="$TMP/fixture-bootstrap-failure"
touch "$CS2MAC_FIXTURE_FAIL"
if (cs2mac_setup --library "$TMP/failed-library" --profile balanced1080 --refresh-hz 0 --no-steam-install) >/dev/null 2>&1; then fail 'failed bootstrap succeeded'; fi
[ -d "$CS2MAC_HOME/runtime/CS2Runtime.app" ] || fail 'failed runtime deleted'
[ ! -e "$CS2MAC_HOME/state.plist" ] || fail 'failed bootstrap wrote completed state'
if /usr/bin/find "$CS2MAC_HOME/runtime" -name '.setup.*' | /usr/bin/grep -q .; then fail 'temporary extraction leaked'; fi
ok 'bootstrap failure preserves only its fresh runtime and diagnostics, clears temporary work'

app="$CS2MAC_HOME/runtime/CS2Runtime.app"
[ -f "$CS2MAC_HOME/pending-install.plist" ] && [ -f "$app/Contents/SharedSupport/cs2mac-install-owner" ] || fail 'pending ownership not recorded'
owner=$(cat "$app/Contents/SharedSupport/cs2mac-install-owner")
printf unowned > "$app/Contents/SharedSupport/cs2mac-install-owner"
if (cs2mac_setup --resume --dry-run) >/dev/null 2>&1; then fail 'unowned marker accepted'; fi
printf '%s\n' "$owner" > "$app/Contents/SharedSupport/cs2mac-install-owner"
ok 'resume refuses mismatched or unowned marker'

mkdir -p "$app/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam"
printf preserve > "$app/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/Steam.exe"
if (cs2mac_setup --resume --dry-run) >/dev/null 2>&1; then fail 'resume accepted installed Steam'; fi
[ "$(cat "$app/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/Steam.exe")" = preserve ] || fail 'Steam changed'
rm -rf "$app/Contents/SharedSupport/prefix"
ok 'resume refuses an existing Steam installation without touching it'

if (cs2mac_install_assert_stopped() { cs2mac_install_abort 'synthetic active runtime'; }; cs2mac_setup --resume --dry-run) >/dev/null 2>&1; then fail 'active runtime accepted'; fi
ok 'resume requires the exact runtime to be stopped'

mkdir -p "$TMP/external-prefix"
ln -s "$TMP/external-prefix" "$app/Contents/SharedSupport/prefix"
if (cs2mac_setup --resume --dry-run) >/dev/null 2>&1; then fail 'redirected prefix accepted'; fi
[ -L "$app/Contents/SharedSupport/prefix" ] || fail 'redirected prefix changed'
rm "$app/Contents/SharedSupport/prefix"
ok 'resume rejects an external prefix ancestor'

rm "$CS2MAC_FIXTURE_FAIL"
cs2mac_setup --resume --no-steam-install >/dev/null
[ -f "$CS2MAC_HOME/state.plist" ] || fail 'resume did not complete state'
[ ! -e "$CS2MAC_HOME/pending-install.plist" ] && [ ! -e "$app/Contents/SharedSupport/cs2mac-install-owner" ] || fail 'completed markers retained'
ok 'owned pending bootstrap resumes and removes markers only after completion'

export CS2MAC_HOME="$TMP/launcher-conflict-support"
export CS2MAC_FIXTURE_LAUNCHER_FAIL="$TMP/fixture-launcher-conflict" CS2MAC_FIXTURE_BOOT_LOG="$TMP/bootstrap-calls"
touch "$CS2MAC_FIXTURE_LAUNCHER_FAIL"
if (cs2mac_setup --library "$TMP/conflict-library" --profile balanced1080 --refresh-hz 0 --no-steam-install) >/dev/null 2>&1; then fail 'launcher conflict accepted'; fi
[ ! -e "$CS2MAC_HOME/state.plist" ] || fail 'launcher failure left completed state'
[ "$(cs2mac_install_pending_get prefix_initialized)" = 1 ] || fail 'initialized prefix was not recorded'
rm "$CS2MAC_FIXTURE_LAUNCHER_FAIL"
cs2mac_setup --resume --no-steam-install >/dev/null
[ "$(wc -l < "$CS2MAC_FIXTURE_BOOT_LOG" | tr -d ' ')" = 1 ] || fail 'resume reran completed bootstrap'
ok 'launcher conflict stays pending; resume finishes without repeating prefix bootstrap'

app="$CS2MAC_HOME/runtime/CS2Runtime.app"
mv "$app/Contents/SharedSupport/prefix" "$TMP/outside-installer-prefix"
ln -s "$TMP/outside-installer-prefix" "$app/Contents/SharedSupport/prefix"
if (
    cs2mac_install_download() { touch "$TMP/installer-download-attempted"; return 1; }
    cs2mac_install_steam
) >/dev/null 2>&1; then fail 'Steam installer accepted an external prefix'; fi
[ ! -e "$TMP/installer-download-attempted" ] || fail 'installer downloaded before checking prefix containment'
[ -L "$app/Contents/SharedSupport/prefix" ] || fail 'installer guard changed prefix symlink'
ok 'Steam installer rejects an outside-prefix symlink before download or execution'

printf '%s tests passed (synthetic fixtures only).\n' "$passed"
