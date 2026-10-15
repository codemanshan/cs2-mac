#!/bin/bash
# Original installer for a new, isolated runtime. Compatible with macOS Bash 3.2.

# Public entry points below run in subshells, so a failed guard cannot continue
# even when the caller is testing the function inside an if statement.
cs2mac_install_abort() { cs2mac_error "$*"; exit 1; }

CS2MAC_TEMPLATE_URL='https://github.com/Sikarugir-App/Template/releases/download/v1.0/Template-1.0.22.tar.xz'
CS2MAC_TEMPLATE_SHA256='02a8e9e1140121128188bce5380b5adf187fd6084fd2cb266e22cc8ab50e5155'
CS2MAC_WINE_URL='https://github.com/Sikarugir-App/Engines/releases/download/v1.0/WS12WineSikarugir11.0_1.tar.xz'
CS2MAC_WINE_SHA256='67e29fb3d74f363af39c69ba11f9b13a79812c5db07cf4748672658e4a200a0e'
CS2MAC_STEAM_URL='https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe'
# Valve's URL is mutable. A changed download fails closed until this pin is reviewed.
CS2MAC_STEAM_SHA256='7d3654531c32d941b8cae81c4137fc542172bfa9635f169cb392f245a0a12bcb'

cs2mac_install_verify() {
    local expected="$1" file="$2" actual
    [ -f "$file" ] && [ ! -L "$file" ] || return 1
    actual=$(/usr/bin/shasum -a 256 "$file") || return 1
    actual=${actual%% *}
    [ "$actual" = "$expected" ]
}

cs2mac_install_download() {
    local url="$1" expected="$2" target="$3" partial
    if [ -e "$target" ] || [ -L "$target" ]; then
        cs2mac_install_verify "$expected" "$target" ||
            cs2mac_install_abort "Cached download failed SHA-256 verification: $target. Existing file was preserved."
        return
    fi
    partial=$(/usr/bin/mktemp "${target}.part.XXXXXX") || return 1
    if ! /usr/bin/curl --disable --fail --location --proto '=https' --proto-redir '=https' \
        --tlsv1.2 --retry 3 --connect-timeout 20 --max-time 1800 --output "$partial" "$url"; then
        /bin/rm -f "$partial"
        cs2mac_install_abort "Download failed: $url"
    fi
    if ! cs2mac_install_verify "$expected" "$partial"; then
        /bin/rm -f "$partial"
        cs2mac_install_abort "SHA-256 mismatch for $url. Nothing from this download was executed."
    fi
    # A concurrent setup must never replace another setup's cached file.
    if ! /bin/ln "$partial" "$target"; then
        /bin/rm -f "$partial"
        cs2mac_install_abort "Download destination appeared during setup: $target"
    fi
    /bin/rm -f "$partial"
}

cs2mac_install_relative_safe() (
    local relative="$1" component depth=0 old_ifs="$IFS"
    case "$relative" in /*) return 1 ;; esac
    IFS=/
    # Word splitting is intentional; pathname expansion must remain disabled.
    set -f
    for component in $relative; do
        case "$component" in
            ''|.) ;;
            ..) [ "$depth" -gt 0 ] || { IFS="$old_ifs"; set +f; return 1; }; depth=$((depth - 1)) ;;
            *) depth=$((depth + 1)) ;;
        esac
    done
    IFS="$old_ifs"
    set +f
)

cs2mac_install_extract() {
    local archive="$1" destination="$2" top="$3" member link target relative
    [ -d "$destination" ] && [ ! -L "$destination" ] || return 1
    /usr/bin/tar -tf "$archive" > "$destination/.members"
    while IFS= read -r member; do
        case "$member" in "$top"|"$top/"|"$top/"*) ;; *) cs2mac_install_abort "Unexpected archive root: $member" ;; esac
        case "/$member/" in *'/../'*|*'/./'*) cs2mac_install_abort "Unsafe archive member: $member" ;; esac
        case "$member" in /*) cs2mac_install_abort "Absolute archive member rejected" ;; esac
    done < "$destination/.members"
    # No devices, pipes, sockets, or hard links are needed by these pinned archives.
    /usr/bin/tar -tvf "$archive" > "$destination/.member-types"
    /usr/bin/awk 'substr($0,1,1) !~ /^[-dl]$/ { bad=1 } END { exit bad }' \
        "$destination/.member-types" || cs2mac_install_abort "Unsupported archive member type"
    # macOS bsdtar's default traversal/symlink protections remain enabled (no -P).
    /usr/bin/tar -xf "$archive" -C "$destination"
    while IFS= read -r link; do
        target=$(/usr/bin/readlink "$link") || return 1
        relative=${link#"$destination/$top/"}
        case "$relative" in */*) relative=${relative%/*} ;; *) relative=. ;; esac
        relative="$relative/$target"
        cs2mac_install_relative_safe "$relative" || cs2mac_install_abort "Archive symlink escapes its root: $link"
    done < <(/usr/bin/find "$destination/$top" -type l -print)
    /bin/rm -f "$destination/.members" "$destination/.member-types"
}

cs2mac_install_require_host() {
    [ "$(/usr/bin/uname -s)" = Darwin ] || cs2mac_install_abort 'Setup requires macOS.'
    local version major minor
    version=$(/usr/bin/sw_vers -productVersion)
    major=${version%%.*}; minor=${version#*.}; minor=${minor%%.*}
    [ "$major" -gt 14 ] || { [ "$major" -eq 14 ] && [ "$minor" -ge 6 ]; } ||
        cs2mac_install_abort 'The pinned runtime requires macOS 14.6 or newer.'
    # Hardware capability remains 1 when Terminal itself runs under Rosetta.
    [ "$(/usr/sbin/sysctl -n hw.optional.arm64 2>/dev/null)" = 1 ] ||
        cs2mac_install_abort 'This toolkit supports Apple silicon Macs only.'
    /usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null ||
        cs2mac_install_abort 'Rosetta 2 is required on Apple silicon. Install it through macOS, then run setup again.'
}

cs2mac_install_assert_paths() {
    local app="$1" part resolved app_resolved
    [ -d "$app" ] && [ ! -L "$app" ] || cs2mac_install_abort 'Managed app is missing or redirected.'
    app_resolved=$(cd -P "$app" && pwd) || exit 1
    for part in Contents Contents/MacOS Contents/SharedSupport Contents/SharedSupport/wine Contents/SharedSupport/wine/bin; do
        [ -d "$app/$part" ] && [ ! -L "$app/$part" ] || cs2mac_install_abort "Runtime ancestor is missing or redirected: $part"
        resolved=$(cd -P "$app/$part" && pwd) || exit 1
        case "$resolved/" in "$app_resolved/"*) ;; *) cs2mac_install_abort 'Runtime ancestor escapes its app.' ;; esac
    done
    for part in Contents/SharedSupport/prefix Contents/SharedSupport/prefix/drive_c Contents/SharedSupport/prefix/dosdevices \
        Contents/SharedSupport/prefix/drive_c/windows Contents/SharedSupport/prefix/drive_c/windows/system32 \
        'Contents/SharedSupport/prefix/drive_c/Program Files (x86)' 'Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam' \
        Contents/SharedSupport/wine/lib Contents/SharedSupport/wine/lib/wine Contents/SharedSupport/wine/lib/wine/x86_64-unix; do
        if [ -e "$app/$part" ] || [ -L "$app/$part" ]; then
            [ -d "$app/$part" ] && [ ! -L "$app/$part" ] || cs2mac_install_abort "Prefix ancestor is redirected: $part"
            resolved=$(cd -P "$app/$part" && pwd) || exit 1
            case "$resolved/" in "$app_resolved/"*) ;; *) cs2mac_install_abort 'Prefix ancestor escapes its app.' ;; esac
        fi
    done
    for part in Contents/Info.plist Contents/SharedSupport/wine/version Contents/Frameworks/renderer/dxmt/version; do
        [ ! -L "$app/$part" ] || cs2mac_install_abort "Runtime metadata is redirected: $part"
    done
    for part in Contents/MacOS/launcher Contents/MacOS/Sikarugir Contents/SharedSupport/wine/bin/wine Contents/SharedSupport/wine/bin/wineserver; do
        if [ -L "$app/$part" ]; then
            # Official launcher is a local symlink to Sikarugir. Other executable
            # redirects are unnecessary in these pinned artifacts.
            [ "$part" = Contents/MacOS/launcher ] &&
                [ "$(/usr/bin/readlink "$app/$part")" = Sikarugir ] ||
                cs2mac_install_abort "Unexpected executable redirect: $part"
        fi
    done
    if [ -e "$app/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/Steam.exe" ] ||
        [ -L "$app/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/Steam.exe" ]; then
        cs2mac_install_abort 'Steam is already present in this prefix; resume will not reinitialize it.'
    fi
}

cs2mac_install_assert_stopped() {
    local app="$1" path pids status=0
    local paths=()
    for path in "$app/Contents/MacOS/Sikarugir" "$app/Contents/MacOS/launcher" \
        "$app/Contents/SharedSupport/wine/bin/wine" "$app/Contents/SharedSupport/wine/bin/wineserver" \
        "$app/Contents/SharedSupport/wine/lib/wine/x86_64-unix/ntdll.so"; do
        [ ! -f "$path" ] || paths[${#paths[@]}]="$path"
    done
    [ "${#paths[@]}" -gt 0 ] || cs2mac_install_abort 'No runtime executables are available for the process guard.'
    pids=$(/usr/sbin/lsof -n -t "${paths[@]}" 2>/dev/null) || status=$?
    [ -z "$pids" ] || cs2mac_install_abort 'This runtime is active. Close its game and Windows Steam before resuming setup.'
    [ "$status" -le 1 ] || cs2mac_install_abort 'Could not verify that this runtime is stopped.'
}

cs2mac_install_mark_pending() {
    local app="$1" library="$2" cap="$3" profile="$4" support marker owner token temporary value
    support=$(cs2mac_support_dir); marker="$support/pending-install.plist"
    owner="$app/Contents/SharedSupport/cs2mac-install-owner"
    [ ! -e "$marker" ] && [ ! -L "$marker" ] && [ ! -e "$owner" ] && [ ! -L "$owner" ] ||
        cs2mac_install_abort 'An unexpected pending-install marker already exists.'
    token=$(/usr/bin/uuidgen)
    printf '%s\n' "$token" > "$owner"
    temporary=$(/usr/bin/mktemp "$support/.pending.XXXXXX")
    /bin/rm -f "$temporary"
    /usr/bin/plutil -create xml1 "$temporary"
    /usr/bin/plutil -insert marker_schema -integer 1 "$temporary"
    /usr/bin/plutil -insert app_path -string "$app" "$temporary"
    /usr/bin/plutil -insert library_path -string "$library" "$temporary"
    /usr/bin/plutil -insert profile -string "$profile" "$temporary"
    /usr/bin/plutil -insert render_cap -integer "$cap" "$temporary"
    /usr/bin/plutil -insert owner_token -string "$token" "$temporary"
    /usr/bin/plutil -insert template_sha256 -string "$CS2MAC_TEMPLATE_SHA256" "$temporary"
    /usr/bin/plutil -insert wine_archive_sha256 -string "$CS2MAC_WINE_SHA256" "$temporary"
    value=$(/usr/bin/shasum -a 256 "$app/Contents/MacOS/launcher"); value=${value%% *}
    /usr/bin/plutil -insert launcher_sha256 -string "$value" "$temporary"
    value=$(/usr/bin/shasum -a 256 "$app/Contents/SharedSupport/wine/bin/wine"); value=${value%% *}
    /usr/bin/plutil -insert wine_binary_sha256 -string "$value" "$temporary"
    /usr/bin/plutil -insert prefix_initialized -integer 0 "$temporary"
    /bin/mv -n "$temporary" "$marker"
    [ ! -e "$temporary" ] || cs2mac_install_abort 'Another setup created a pending marker.'
}

cs2mac_install_pending_get() {
    /usr/libexec/PlistBuddy -c "Print :$1" "$(cs2mac_support_dir)/pending-install.plist" 2>/dev/null
}

cs2mac_install_validate_pending() {
    local app="$1" support marker owner token expected path value
    support=$(cs2mac_support_dir); marker="$support/pending-install.plist"
    owner="$app/Contents/SharedSupport/cs2mac-install-owner"
    [ -f "$marker" ] && [ ! -L "$marker" ] && [ -f "$owner" ] && [ ! -L "$owner" ] ||
        cs2mac_install_abort 'Resume requires matching toolkit-owned pending markers.'
    [ "$(cs2mac_install_pending_get marker_schema)" = 1 ] &&
        [ "$(cs2mac_install_pending_get app_path)" = "$app" ] &&
        [ "$(cs2mac_install_pending_get template_sha256)" = "$CS2MAC_TEMPLATE_SHA256" ] &&
        [ "$(cs2mac_install_pending_get wine_archive_sha256)" = "$CS2MAC_WINE_SHA256" ] ||
        cs2mac_install_abort 'Pending marker does not identify this pinned managed runtime.'
    token=$(cs2mac_install_pending_get owner_token)
    [ -n "$token" ] && [ "$(/bin/cat "$owner")" = "$token" ] || cs2mac_install_abort 'Pending owner tokens do not match.'
    for path in launcher wine; do
        case "$path" in launcher) expected=$(cs2mac_install_pending_get launcher_sha256); value="$app/Contents/MacOS/launcher" ;;
            wine) expected=$(cs2mac_install_pending_get wine_binary_sha256); value="$app/Contents/SharedSupport/wine/bin/wine" ;; esac
        # The official launcher is a symlink, so verify its resolved bytes here.
        value=$(/usr/bin/shasum -a 256 "$value"); value=${value%% *}
        [ "$value" = "$expected" ] || cs2mac_install_abort 'Pending runtime executable changed; refusing resume.'
    done
    case "$(cs2mac_install_pending_get prefix_initialized)" in 0|1) ;; *) cs2mac_install_abort 'Invalid pending bootstrap state.' ;; esac
}

cs2mac_install_verify_runtime() {
    local app="$1" contents="$1/Contents" version
    [ -x "$contents/MacOS/launcher" ] || cs2mac_install_abort 'Downloaded template has no launcher.'
    [ -x "$contents/SharedSupport/wine/bin/wine" ] || cs2mac_install_abort 'Downloaded engine has no Wine executable.'
    version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$contents/Info.plist")
    [ "$version" = 1.0.22 ] || cs2mac_install_abort 'Unexpected template version.'
    /usr/bin/grep -q '^wine sikarugir 11.0 (revision 1)' "$contents/SharedSupport/wine/version" ||
        cs2mac_install_abort 'Unexpected Wine engine version.'
    /usr/bin/grep -q '^v0.80-244-g7c8dee1' "$contents/Frameworks/renderer/dxmt/version" ||
        cs2mac_install_abort 'Unexpected bundled DXMT version.'
    /usr/bin/codesign --verify "$contents/MacOS/Sikarugir" || cs2mac_install_abort 'Upstream launcher signature verification failed.'
    /usr/bin/codesign --verify "$contents/SharedSupport/wine/bin/wine" || cs2mac_install_abort 'Upstream Wine signature verification failed.'
    # The upstream executable has an unbound Info.plist and no sealed resources.
    # Preserve its existing signature; do not re-sign or remove quarantine.
}

cs2mac_install_guard_storage() {
    local support="$1" part
    [ ! -L "$support" ] || cs2mac_install_abort 'Managed support directory is redirected.'
    for part in runtime downloads installers logs; do
        [ ! -L "$support/$part" ] || cs2mac_install_abort "Managed $part directory is redirected."
        if [ -e "$support/$part" ]; then
            [ -d "$support/$part" ] || cs2mac_install_abort "Managed $part path is not a directory."
        fi
    done
}

cs2mac_install_steam() (
    set -e
    local support app installer log
    support=$(cs2mac_support_dir)
    app=$(cs2mac_state_get app_path)
    [ "$app" = "$support/runtime/CS2Runtime.app" ] || cs2mac_install_abort 'Managed runtime path does not match state.'
    [ -d "$app" ] && [ ! -L "$app" ] || cs2mac_install_abort 'Run setup first.'
    cs2mac_install_guard_storage "$support"
    cs2mac_install_assert_paths "$app"
    if type _cs2mac_launch_load >/dev/null 2>&1; then
        _cs2mac_launch_load || cs2mac_install_abort 'Managed runtime containment verification failed.'
    fi
    if [ -e "$app/Contents/SharedSupport/prefix/drive_c/Program Files (x86)/Steam/Steam.exe" ]; then
        cs2mac_install_abort 'Windows Steam is already installed. Use the steam or play command.'
    fi
    installer="$support/installers/SteamSetup.exe"
    /bin/mkdir -p "$support/installers" "$support/logs"
    cs2mac_install_download "$CS2MAC_STEAM_URL" "$CS2MAC_STEAM_SHA256" "$installer"
    log="$support/logs/steam-installer-$(/bin/date -u +%Y%m%dT%H%M%SZ).log"
    # Explicit setup action: normal upstream installer, in this fresh runtime only.
    /usr/bin/nohup "$app/Contents/MacOS/launcher" WSS-installer "$installer" > "$log" 2>&1 < /dev/null &
    cs2mac_note 'Windows Steam setup is opening. Complete its installer, license review, and sign-in yourself.'
    cs2mac_note 'In Windows Steam Settings > Storage, add V:\\ as the game library, then install Counter-Strike 2.'
    cs2mac_note "Installer log: $log"
)

cs2mac_setup() (
    set -e
    umask 077
    local library='' profile='' refresh=auto dry_run=0 steam_install=1 resume=0 support app state work=''
    local cap template_archive wine_archive marker saved_library saved_profile saved_cap initialized=0 drive
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --library) [ "$#" -ge 2 ] || cs2mac_install_abort '--library needs an absolute path'; library="$2"; shift 2 ;;
            --profile) [ "$#" -ge 2 ] || cs2mac_install_abort '--profile needs a name'; profile="$2"; shift 2 ;;
            --refresh-hz|--cap) [ "$#" -ge 2 ] || cs2mac_install_abort '--refresh-hz needs auto or 0..360'; refresh="$2"; shift 2 ;;
            --resume) resume=1; shift ;;
            --dry-run) dry_run=1; shift ;;
            --no-steam-install) steam_install=0; shift ;;
            *) cs2mac_install_abort "Unknown setup option: $1" ;;
        esac
    done
    support=$(cs2mac_support_dir); app="$support/runtime/CS2Runtime.app"; state=$(cs2mac_state_path)
    marker="$support/pending-install.plist"
    case "$support" in /*) ;; *) cs2mac_install_abort 'Managed support directory must be absolute.' ;; esac
    [ ! -e "$state" ] && [ ! -L "$state" ] || cs2mac_install_abort "Setup state already exists; it was preserved: $state"
    cs2mac_install_guard_storage "$support"
    if [ "$resume" -eq 1 ]; then
        cs2mac_install_assert_paths "$app"
        cs2mac_install_validate_pending "$app"
        cs2mac_install_verify_runtime "$app"
        cs2mac_install_assert_stopped "$app"
        saved_library=$(cs2mac_install_pending_get library_path)
        saved_profile=$(cs2mac_install_pending_get profile)
        saved_cap=$(cs2mac_install_pending_get render_cap)
        [ -z "$library" ] || [ "$library" = "$saved_library" ] || cs2mac_install_abort 'Resume must keep the original library.'
        [ -z "$profile" ] || [ "$profile" = "$saved_profile" ] || cs2mac_install_abort 'Resume must keep the original profile.'
        [ "$refresh" = auto ] || [ "$refresh" = "$saved_cap" ] || cs2mac_install_abort 'Resume must keep the original renderer cap.'
        library="$saved_library"; profile="$saved_profile"; refresh="$saved_cap"
        initialized=$(cs2mac_install_pending_get prefix_initialized)
    else
        [ ! -e "$app" ] && [ ! -L "$app" ] || cs2mac_install_abort "Runtime already exists; it was preserved: $app"
        [ ! -e "$marker" ] && [ ! -L "$marker" ] || cs2mac_install_abort 'A pending marker already exists. Use --resume only for an owned incomplete setup.'
    fi
    case "$library" in /*) ;; *) cs2mac_install_abort 'Choose a game library with --library /absolute/path.' ;; esac
    case "$library" in *$'\n'*|*$'\r'*) cs2mac_install_abort 'Library path must not contain line breaks.' ;; esac
    profile=$(cs2mac_choose_profile "$profile") || exit 1
    cap=$(cs2mac_choose_refresh "$refresh") || exit 1
    cs2mac_note "Managed runtime: $app"
    cs2mac_note "Selected game library: $library"
    cs2mac_note "Profile: $profile; renderer cap: $cap (0 means uncapped)."
    if [ "$dry_run" -eq 1 ]; then
        cs2mac_note 'Dry run: no downloads, writes, Wine processes, or installers were started.'
        return
    fi
    cs2mac_install_require_host
    /bin/mkdir -p "$support/downloads" "$support/runtime" "$support/installers" "$support/logs" "$library"
    [ -d "$library" ] && [ -w "$library" ] || cs2mac_install_abort 'Selected game library is not writable.'
    if [ "$resume" -eq 0 ]; then
        work=$(/usr/bin/mktemp -d "$support/runtime/.setup.XXXXXX")
        trap '[ -z "$work" ] || /bin/rm -rf "$work"' EXIT
        template_archive="$support/downloads/Template-1.0.22.tar.xz"
        wine_archive="$support/downloads/WS12WineSikarugir11.0_1.tar.xz"
        cs2mac_note 'Downloading verified official Template 1.0.22 and Wine 11.0_1.'
        cs2mac_install_download "$CS2MAC_TEMPLATE_URL" "$CS2MAC_TEMPLATE_SHA256" "$template_archive"
        cs2mac_install_download "$CS2MAC_WINE_URL" "$CS2MAC_WINE_SHA256" "$wine_archive"
        /bin/mkdir "$work/template" "$work/wine"
        cs2mac_install_extract "$template_archive" "$work/template" 'Template-1.0.22.app'
        cs2mac_install_extract "$wine_archive" "$work/wine" 'wswine.bundle'
        /usr/bin/ditto "$work/wine/wswine.bundle" "$work/template/Template-1.0.22.app/Contents/SharedSupport/wine"
        cs2mac_install_verify_runtime "$work/template/Template-1.0.22.app"
        [ ! -e "$app" ] && [ ! -L "$app" ] || cs2mac_install_abort 'Runtime destination appeared during setup.'
        /bin/mv "$work/template/Template-1.0.22.app" "$work/CS2Runtime.app"
        # Same basename prevents nesting the source inside an app created in a race.
        /bin/mv -n "$work/CS2Runtime.app" "$support/runtime/"
        [ ! -e "$work/CS2Runtime.app" ] || cs2mac_install_abort 'Runtime destination appeared; existing app was preserved.'
        cs2mac_install_mark_pending "$app" "$library" "$cap" "$profile"
        cs2mac_install_assert_paths "$app"
        cs2mac_install_assert_stopped "$app"
    fi
    # Wineboot may leave a server alive. Select MSync-only before its first
    # invocation, rather than changing synchronization after server startup.
    cs2mac_apply_profile "$app" "$library" "$cap" "$profile" || cs2mac_install_abort 'Could not apply wrapper profile; pending setup was preserved.'
    if [ "$initialized" -eq 0 ]; then
        /usr/libexec/PlistBuddy -c "Set ':Skip Gecko' 1" "$app/Contents/Info.plist"
        /usr/libexec/PlistBuddy -c "Set ':Skip Mono' 1" "$app/Contents/Info.plist"
        cs2mac_note 'Initializing the fresh Wine prefix. macOS may require approval to open the upstream app.'
        if ! "$app/Contents/MacOS/launcher" WSS-wineprefixcreate > "$support/logs/prefix-bootstrap.log" 2>&1; then
            cs2mac_install_abort "Prefix initialization failed. Runtime and log were preserved. After resolving macOS approval and closing this runtime, run: bin/cs2-mac setup --resume. Log: $support/logs/prefix-bootstrap.log"
        fi
        drive="$app/Contents/SharedSupport/prefix/dosdevices/v:"
        [ -d "$app/Contents/SharedSupport/prefix/dosdevices" ] || cs2mac_install_abort 'Fresh prefix has no dosdevices directory.'
        if [ -e "$drive" ] || [ -L "$drive" ]; then
            [ -L "$drive" ] && [ "$(/usr/bin/readlink "$drive")" = "$library" ] ||
                cs2mac_install_abort 'Fresh prefix already has a different V: mapping; refusing to replace it.'
        else
            /bin/ln -s "$library" "$drive"
        fi
        /usr/bin/plutil -replace prefix_initialized -integer 1 "$marker"
    else
        drive="$app/Contents/SharedSupport/prefix/dosdevices/v:"
        [ -L "$drive" ] && [ "$(/usr/bin/readlink "$drive")" = "$library" ] ||
            cs2mac_install_abort 'Owned pending prefix no longer has its original library mapping.'
    fi
    # Building can fail when an unrelated CS2.app exists. Never record completion first.
    cs2mac_build_launcher || cs2mac_install_abort 'Could not create CS2.app. Resolve the launcher conflict, then run setup --resume.'
    cs2mac_write_state "$app" "$library" "$profile" "$cap" || cs2mac_install_abort 'Could not record completion; pending setup was preserved.'
    /bin/rm -f "$app/Contents/SharedSupport/cs2mac-install-owner" "$marker"
    cs2mac_note 'Runtime ready. Native Mac Steam and existing Wine installations were not changed.'
    if [ "$steam_install" -eq 1 ]; then cs2mac_install_steam; fi
    cs2mac_note 'After CS2 is installed, open CS2.app to apply the game profile. Print the one-time Windows Steam launch options with: bin/cs2-mac options'
)
