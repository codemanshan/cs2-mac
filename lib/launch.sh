#!/bin/bash
# Original CS2Mac launcher code. SPDX-License-Identifier: MIT
# Sourced by bin/cs2-mac; compatible with the macOS Bash 3.2.

_cs2mac_launch_fail() { cs2mac_error "$*"; return 1; }

_cs2mac_launch_realpath() {
    local path="$1" parent target count=0
    case "$path" in /*) ;; *) return 1 ;; esac
    case "$path" in *$'\n'*|*$'\r'*) return 1 ;; esac
    while :; do
        parent=$(cd -P -- "$(dirname -- "$path")" 2>/dev/null && pwd -P) || return 1
        path="$parent/$(basename -- "$path")"
        [ -L "$path" ] || break
        count=$((count + 1)); [ "$count" -le 40 ] || return 1
        target=$(/usr/bin/readlink "$path") || return 1
        case "$target" in /*) path="$target" ;; *) path="$parent/$target" ;; esac
    done
    printf '%s\n' "$path"
}

_cs2mac_launch_inside() {
    case "$1" in "$2"/*) return 0 ;; *) return 1 ;; esac
}

_cs2mac_launch_load() {
    local configured app_expected candidate
    _cs2mac_support=$(cs2mac_support_dir) || return 1
    [ -d "$_cs2mac_support" ] || { _cs2mac_launch_fail 'CS2Mac is not set up. Run cs2-mac setup first.'; return 1; }
    _cs2mac_support=$(_cs2mac_launch_realpath "$_cs2mac_support") || return 1
    configured=$(cs2mac_state_get app_path 2>/dev/null) || configured=
    [ -n "$configured" ] || { _cs2mac_launch_fail 'No managed runtime is recorded. Run cs2-mac setup first.'; return 1; }
    [ -d "$configured" ] || { _cs2mac_launch_fail 'The managed runtime is missing. Run cs2-mac doctor or setup.'; return 1; }
    _cs2mac_app=$(_cs2mac_launch_realpath "$configured") || return 1
    app_expected="$_cs2mac_support/runtime/CS2Runtime.app"
    [ "$_cs2mac_app" = "$app_expected" ] || { _cs2mac_launch_fail 'Refusing a runtime outside the managed CS2Mac location.'; return 1; }
    _cs2mac_contents="$_cs2mac_app/Contents"
    _cs2mac_prefix=$(_cs2mac_launch_realpath "$_cs2mac_contents/SharedSupport/prefix") || return 1
    [ -d "$_cs2mac_prefix/drive_c" ] && _cs2mac_launch_inside "$_cs2mac_prefix" "$_cs2mac_app" || {
        _cs2mac_launch_fail 'The managed Wine prefix is missing or redirected outside its app.'; return 1;
    }
    _cs2mac_engine=$(_cs2mac_launch_realpath "$_cs2mac_contents/SharedSupport/wine") || return 1
    _cs2mac_launch_inside "$_cs2mac_engine" "$_cs2mac_app" || { _cs2mac_launch_fail 'The Wine engine is redirected outside its app.'; return 1; }
    _cs2mac_wine=$(_cs2mac_launch_realpath "$_cs2mac_engine/bin/wine") || return 1
    _cs2mac_server=$(_cs2mac_launch_realpath "$_cs2mac_engine/bin/wineserver") || return 1
    for candidate in "$_cs2mac_wine" "$_cs2mac_server"; do
        [ -x "$candidate" ] && _cs2mac_launch_inside "$candidate" "$_cs2mac_app" || {
            _cs2mac_launch_fail 'The bundled Wine executable is missing or redirected.'; return 1;
        }
    done
    _cs2mac_steam="$_cs2mac_prefix/drive_c/Program Files (x86)/Steam/Steam.exe"
    if [ -e "$_cs2mac_steam" ]; then
        candidate=$(_cs2mac_launch_realpath "$_cs2mac_steam") || return 1
        _cs2mac_launch_inside "$candidate" "$_cs2mac_prefix" || { _cs2mac_launch_fail 'The Windows Steam executable is redirected outside the managed prefix.'; return 1; }
        _cs2mac_steam="$candidate"
    fi
    _cs2mac_library=$(cs2mac_state_get library_path 2>/dev/null) || return 1
    case "$_cs2mac_library" in /*) ;; *) _cs2mac_launch_fail 'The recorded game library must be an absolute path.'; return 1 ;; esac
    case "$_cs2mac_library" in *$'\n'*|*$'\r'*) _cs2mac_launch_fail 'Invalid game library path.'; return 1 ;; esac
    _cs2mac_profile=$(cs2mac_state_get profile 2>/dev/null) || return 1
    case "$_cs2mac_profile" in balanced1080|quality1440) ;; *) _cs2mac_launch_fail 'The recorded graphics profile is invalid.'; return 1 ;; esac
    _cs2mac_cap=$(cs2mac_state_get render_cap 2>/dev/null) || return 1
    case "$_cs2mac_cap" in ''|*[!0-9]*) _cs2mac_launch_fail 'The recorded renderer cap must be an integer.'; return 1 ;; esac
    [ "${#_cs2mac_cap}" -le 3 ] && [ "$_cs2mac_cap" -le 360 ] || { _cs2mac_launch_fail 'The recorded renderer cap is out of range.'; return 1; }
    [ -x "$_cs2mac_contents/MacOS/launcher" ] || { _cs2mac_launch_fail 'The official wrapper launcher is missing.'; return 1; }
    candidate=$(_cs2mac_launch_realpath "$_cs2mac_contents/MacOS/launcher") || return 1
    _cs2mac_launch_inside "$candidate" "$_cs2mac_app" || { _cs2mac_launch_fail 'The wrapper launcher is redirected outside its app.'; return 1; }
    for candidate in \
        "$_cs2mac_contents/Frameworks/renderer/dxmt/wine/x86_64-windows/d3d11.dll" \
        "$_cs2mac_contents/Frameworks/renderer/dxmt/wine/x86_64-windows/dxgi.dll" \
        "$_cs2mac_contents/Frameworks/renderer/dxmt/wine/x86_64-windows/winemetal.dll" \
        "$_cs2mac_contents/Frameworks/renderer/dxmt/wine/x86_64-unix/winemetal.so"; do
        [ -f "$candidate" ] || { _cs2mac_launch_fail 'The bundled DXMT renderer is incomplete.'; return 1; }
        candidate=$(_cs2mac_launch_realpath "$candidate") || return 1
        _cs2mac_launch_inside "$candidate" "$_cs2mac_app" || { _cs2mac_launch_fail 'A renderer executable is redirected outside its app.'; return 1; }
    done
}

# Process ownership uses executable mappings only, never arguments, environment,
# open user files or credentials. These small boundaries are overridden in tests.
_cs2mac_launch_process_rows() { /bin/ps -axww -o pid=,comm=; }
_cs2mac_launch_text_paths() { /usr/sbin/lsof -a -p "$1" -d txt -Fn 2>/dev/null; }
_cs2mac_launch_pause() { /bin/sleep 1; }
_cs2mac_launch_open() { /usr/bin/open -n "$1"; }

_cs2mac_launch_processes() {
    local pid executable line owned kind
    while read -r pid executable; do
        case "$pid" in ''|*[!0-9]*) continue ;; esac
        case "$executable" in *wine*|*Steam.exe|*steam.exe|*cs2.exe|*steamwebhelper.exe) ;; *) continue ;; esac
        owned=0
        while IFS= read -r line; do
            case "$line" in
                "n$_cs2mac_app/Contents/SharedSupport/wine/"*|"n$_cs2mac_app/Contents/Frameworks/"*) owned=1 ;;
            esac
        done < <(_cs2mac_launch_text_paths "$pid")
        [ "$owned" -eq 1 ] || continue
        case "$executable" in *cs2.exe) kind=game ;; *Steam.exe|*steam.exe) kind=steam ;; *) kind=runtime ;; esac
        printf '%s %s\n' "$pid" "$kind"
    done < <(_cs2mac_launch_process_rows)
}

_cs2mac_launch_wine() {
    # Environment facts match the pinned official Wine11/DXMT wrapper. In
    # particular Wine11 uses bin/wine and needs its Sikarugir marker.
    local binary="$1"; shift
    /usr/bin/env -i HOME="$HOME" USER="${USER:-}" LOGNAME="${LOGNAME:-}" \
        TMPDIR="${TMPDIR:-/tmp}" LANG="${LANG:-en_US.UTF-8}" \
        PATH="$_cs2mac_engine/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
        WINEPREFIX="$_cs2mac_prefix" CX_ROOT="$_cs2mac_engine" \
        SikarugirAppWine11=1 WINEMSYNC=1 WINEESYNC=0 WINEDEBUG=-all \
        WINEDLLPATH_DXMT="$_cs2mac_contents/Frameworks/renderer/dxmt/wine" \
        WINEDLLPATH_PREPEND="$_cs2mac_contents/Frameworks/renderer/dxmt/wine" \
        WINEDLLPATH_D9VK="$_cs2mac_contents/Frameworks/renderer/d9vk/wine" \
        WINEDLLPATH_D3DMETAL="$_cs2mac_contents/Frameworks/renderer/d3dmetal/wine" \
        CX_D3DMETALPATH="$_cs2mac_contents/Frameworks/renderer/d3dmetal" \
        CX_APPLEGPT_LIBD3DSHARED_PATH="$_cs2mac_contents/Frameworks/renderer/d3dmetal/external/libd3dshared.dylib" \
        CX_APPLEGPTK_LIBD3DSHARED_PATH="$_cs2mac_contents/Frameworks/renderer/d3dmetal/external/libd3dshared.dylib" \
        GST_PLUGIN_PATH="$_cs2mac_contents/Frameworks/GStreamer.framework/Libraries/gstreamer-1.0" \
        DYLD_FALLBACK_LIBRARY_PATH="$_cs2mac_engine/lib:$_cs2mac_engine/lib64:$_cs2mac_contents/Frameworks:$_cs2mac_contents/Frameworks/GStreamer.framework/Libraries:/opt/wine/lib:/usr/lib:/usr/libexec:/usr/lib/system" \
        DXMT_CONFIG="[cs2.exe];d3d11.preferredMaxFrameRate=$_cs2mac_cap;" \
        "$binary" "$@"
}

cs2mac_play() {
    local processes
    _cs2mac_launch_load || return 1
    processes=$(_cs2mac_launch_processes)
    if [[ "$processes" == *' game'* ]]; then
        cs2mac_note 'CS2 is already running in the managed runtime.'
        return 0
    fi
    [ -d "$_cs2mac_library" ] || { _cs2mac_launch_fail 'The selected game library is unavailable. Connect its drive before playing.'; return 1; }
    [ -f "$_cs2mac_steam" ] || { _cs2mac_launch_fail 'Windows Steam is not installed yet. Finish its installer, or run cs2-mac steam-install.'; return 1; }
    # Only our profile files are prepared, and only after the running-game guard.
    cs2mac_prepare_game "$_cs2mac_app" "$_cs2mac_library" "$_cs2mac_profile" "$_cs2mac_cap" || return 1
    if [ -n "$processes" ] && [ -f "$_cs2mac_steam" ]; then
        cs2mac_note 'Asking the managed Windows Steam to start CS2.'
        _cs2mac_launch_wine "$_cs2mac_wine" "$_cs2mac_steam" -applaunch 730 >/dev/null 2>&1 &
    else
        cs2mac_note 'Opening the managed Windows Steam runtime.'
        _cs2mac_launch_open "$_cs2mac_app"
    fi
}

cs2mac_stop() {
    local processes attempt
    _cs2mac_launch_load || return 1
    processes=$(_cs2mac_launch_processes)
    if [ -z "$processes" ]; then cs2mac_note 'The managed runtime is already stopped.'; return 0; fi
    cs2mac_note 'Closing CS2 and its managed Windows Steam.'
    # taskkill without /F requests normal window closure. All commands use this
    # exact prefix; no host PID is ever signalled and no global kill is used.
    if [[ "$processes" == *' game'* ]]; then
        _cs2mac_launch_wine "$_cs2mac_wine" taskkill /IM cs2.exe >/dev/null 2>&1 &
    fi
    if [ -f "$_cs2mac_steam" ]; then
        _cs2mac_launch_wine "$_cs2mac_wine" "$_cs2mac_steam" -shutdown >/dev/null 2>&1 &
    fi
    attempt=0
    while [ "$attempt" -lt 15 ]; do
        [ -n "$(_cs2mac_launch_processes)" ] || return 0
        _cs2mac_launch_pause
        attempt=$((attempt + 1))
    done
    cs2mac_note 'Graceful closure timed out; stopping only the managed Wine prefix.'
    _cs2mac_launch_wine "$_cs2mac_server" -k
}

cs2mac_doctor() {
    local cap_label
    _cs2mac_launch_load || return 1
    cs2mac_note 'Managed runtime, Wine prefix and DXMT files are present.'
    cap_label="$_cs2mac_cap FPS"
    [ "$_cs2mac_cap" != 0 ] || cap_label=uncapped
    cs2mac_note "Profile: $_cs2mac_profile; renderer cap: $cap_label; MSync-only."
    if [ ! -f "$_cs2mac_steam" ]; then
        cs2mac_note 'Windows Steam is not installed yet. Finish setup in the managed Steam installer.'
    elif [ ! -d "$_cs2mac_library" ]; then
        cs2mac_note 'The game library is unavailable. Connect its drive before playing.'
    elif [ ! -f "$_cs2mac_library/steamapps/common/Counter-Strike Global Offensive/game/bin/win64/cs2.exe" ]; then
        cs2mac_note 'CS2 is not installed in the selected library yet. Install it using managed Windows Steam.'
    else
        cs2mac_note 'CS2 game files are present. Steam may still need to finish an update.'
    fi
    cs2mac_note 'Set Windows Steam CS2 Launch Options once to the options below:'
    cs2mac_launch_options "$_cs2mac_profile"
    cs2mac_note 'If the game is already open, enter exec cs2mac.cfg in its console to apply the managed console settings.'
    cs2mac_note 'Doctor checks installation files only; it does not benchmark, inspect accounts or change security settings.'
}

cs2mac_build_launcher() {
    local source="${CS2MAC_SOURCE_DIR:-}" support target parent toolkit_stage app_stage item old
    support=$(cs2mac_support_dir) || return 1
    [ -n "$source" ] && [ -d "$source" ] || { _cs2mac_launch_fail 'The toolkit source directory is missing.'; return 1; }
    source=$(_cs2mac_launch_realpath "$source") || return 1
    target="${1:-$HOME/Applications/CS2.app}"
    case "$target" in /*/CS2.app) ;; *) _cs2mac_launch_fail 'Launcher destination must be an absolute CS2.app path.'; return 1 ;; esac
    case "$target" in *$'\n'*|*$'\r'*) return 1 ;; esac
    /bin/mkdir -p "$support" "$(dirname -- "$target")" || return 1
    support=$(_cs2mac_launch_realpath "$support") || return 1
    parent=$(_cs2mac_launch_realpath "$(dirname -- "$target")") || return 1
    target="$parent/CS2.app"
    if [ -e "$target" ] || [ -L "$target" ]; then
        [ ! -L "$target" ] && [ -f "$target/Contents/Info.plist" ] &&
            [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$target/Contents/Info.plist" 2>/dev/null)" = 'dev.cs2mac.launcher' ] || {
                _cs2mac_launch_fail 'An unrelated CS2.app already exists; move it before installing this launcher.'; return 1;
            }
    fi
    for item in bin lib runtime-artifacts.json VERSION LICENSE; do
        [ -e "$source/$item" ] && [ ! -L "$source/$item" ] || { _cs2mac_launch_fail "Toolkit source is missing $item or redirects it."; return 1; }
        if [ -d "$source/$item" ] && [ -n "$(/usr/bin/find "$source/$item" -type l -print -quit)" ]; then
            _cs2mac_launch_fail 'Toolkit source contains redirected files.'; return 1
        fi
    done
    [ -x "$source/bin/cs2-mac" ] || { _cs2mac_launch_fail 'The toolkit CLI is not executable.'; return 1; }
    [ ! -L "$support/toolkit" ] || { _cs2mac_launch_fail 'The installed toolkit is redirected.'; return 1; }
    toolkit_stage=$(/usr/bin/mktemp -d "$support/.toolkit.XXXXXX") || return 1
    for item in bin lib runtime-artifacts.json VERSION LICENSE; do
        /bin/cp -R "$source/$item" "$toolkit_stage/" || { /bin/rm -rf "$toolkit_stage"; return 1; }
    done
    app_stage=$(/usr/bin/mktemp -d "$parent/.cs2mac-launcher.XXXXXX") || { /bin/rm -rf "$toolkit_stage"; return 1; }
    /bin/mkdir -p "$app_stage/Contents/MacOS" || return 1
    /bin/cat >"$app_stage/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>dev.cs2mac.launcher</string>
<key>CFBundleName</key><string>CS2</string>
<key>CFBundleDisplayName</key><string>CS2</string>
<key>CFBundleExecutable</key><string>launch</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
    /bin/cat >"$app_stage/Contents/MacOS/launch" <<'LAUNCH'
#!/bin/bash
# SPDX-License-Identifier: MIT
_cs2mac_launcher_osascript() { /usr/bin/osascript "$@"; }
_cs2mac_launcher_alert() {
    # The error is an argv value, never AppleScript source. This also preserves
    # quotes, newlines and shell-looking text from an unavailable drive's name.
    _cs2mac_launcher_osascript - "$1" <<'APPLESCRIPT'
on run argv
    display alert "CS2 could not start" message (item 1 of argv) as critical buttons {"OK"} default button "OK"
end run
APPLESCRIPT
}
_cs2mac_launcher_main() {
    local support cli output status
    support="${CS2MAC_HOME:-$HOME/Library/Application Support/CS2Mac}"
    cli="$support/toolkit/bin/cs2-mac"
    if [ ! -x "$cli" ]; then
        _cs2mac_launcher_alert 'The installed toolkit is missing. Run cs2-mac setup again.' || :
        return 1
    fi
    if output=$("$cli" play 2>&1); then
        return 0
    else
        status=$?
    fi
    [ -n "$output" ] || output='CS2 could not start. Run cs2-mac doctor to check the installation.'
    _cs2mac_launcher_alert "$output" || :
    return "$status"
}
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    _cs2mac_launcher_main "$@"
    exit $?
fi
LAUNCH
    /bin/chmod 755 "$app_stage/Contents/MacOS/launch" || return 1
    if [ -e "$support/toolkit" ]; then
        old=$(/usr/bin/mktemp -d "$support/.toolkit-previous.XXXXXX") || return 1
        /bin/rmdir "$old" && /bin/mv "$support/toolkit" "$old" || return 1
    fi
    /bin/mv "$toolkit_stage" "$support/toolkit" || return 1
    if [ -e "$target" ]; then
        old=$(/usr/bin/mktemp -d "$parent/.cs2mac-launcher-previous.XXXXXX") || return 1
        /bin/rmdir "$old" && /bin/mv "$target" "$old" || return 1
    fi
    /bin/mv "$app_stage" "$target" || return 1
    cs2mac_note "Launcher ready: $target"
}
