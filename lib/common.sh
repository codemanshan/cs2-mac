#!/bin/bash
# Original toolkit helpers. Compatible with macOS's Bash 3.2.

cs2mac_note() { printf '%s\n' "$*"; }
cs2mac_error() { printf 'CS2 Mac: %s\n' "$*" >&2; }
cs2mac_die() { cs2mac_error "$*"; return 1; }
cs2mac_support_dir() { printf '%s\n' "${CS2MAC_HOME:-$HOME/Library/Application Support/CS2Mac}"; }
cs2mac_state_path() { printf '%s/state.plist\n' "$(cs2mac_support_dir)"; }

cs2mac_state_get() {
  case "${1:-}" in
    app_path|library_path|profile|render_cap|launcher_path|toolkit_version|state_version) ;;
    *) cs2mac_error 'Unknown state key'; return 1 ;;
  esac
  /usr/libexec/PlistBuddy -c "Print :$1" "$(cs2mac_state_path)" 2>/dev/null
}

cs2mac_validate_cap() {
  case "${1:-}" in ''|*[!0-9]*) return 1 ;; esac
  [ "${#1}" -le 3 ] && [ "$1" -le 360 ]
}

cs2mac_choose_profile() {
  case "${1:-auto}" in
    balanced1080|quality1440) printf '%s\n' "$1" ;;
    auto)
      local brand memory
      brand=$(/usr/sbin/sysctl -n machdep.cpu.brand_string 2>/dev/null || true)
      memory=$(/usr/sbin/sysctl -n hw.memsize 2>/dev/null || printf '0')
      case "$brand" in
        *Max*|*Ultra*)
          if [ "$memory" -ge 25769803776 ] 2>/dev/null; then
            printf 'quality1440\n'; return 0
          fi ;;
      esac
      printf 'balanced1080\n'
      ;;
    *) cs2mac_error 'Choose balanced1080 or quality1440'; return 1 ;;
  esac
}

cs2mac_choose_refresh() {
  local value=${1:-auto}
  if [ "$value" = auto ]; then
    # CoreGraphics reads the current main display, not its advertised maximum.
    # Unknown / variable rates leave the renderer uncapped; no display mode changes.
    value=$(/usr/bin/osascript -l JavaScript -e '
      ObjC.import("CoreGraphics");
      var mode = $.CGDisplayCopyDisplayMode($.CGMainDisplayID());
      var hz = Number($.CGDisplayModeGetRefreshRate(mode));
      (isFinite(hz) && hz >= 20 && hz <= 360) ? Math.round(hz) : 0;
    ' 2>/dev/null || printf '0')
  fi
  cs2mac_validate_cap "$value" || { cs2mac_error 'Refresh rate must be an integer from 0 to 360'; return 1; }
  printf '%s\n' "$value"
}

cs2mac_launch_options() {
  local width height
  case "${1:-balanced1080}" in
    balanced1080) width=1920; height=1080 ;;
    quality1440) width=2560; height=1440 ;;
    *) cs2mac_error 'Unknown graphics profile'; return 1 ;;
  esac
  printf '%s\n' "-windowed -noborder -w $width -h $height +exec cs2mac.cfg"
}

cs2mac_write_state() {
  local app=$1 library=$2 profile=$3 cap=$4 support state temporary
  support=$(cs2mac_support_dir); state=$(cs2mac_state_path)
  cs2mac_validate_cap "$cap" || return 1
  cs2mac_choose_profile "$profile" >/dev/null || return 1
  [ -d "$support" ] && [ ! -L "$support" ] || { cs2mac_error 'Managed support directory is missing or redirected'; return 1; }
  [ ! -e "$state" ] && [ ! -L "$state" ] || { cs2mac_error 'An installation state already exists; refusing to overwrite it'; return 1; }
  temporary=$(mktemp "$support/.state.XXXXXX") || return 1
  rm -f "$temporary"
  /usr/bin/plutil -create xml1 "$temporary"
  /usr/bin/plutil -insert state_version -integer 1 "$temporary"
  /usr/bin/plutil -insert toolkit_version -string "$(cat "$CS2MAC_SOURCE_DIR/VERSION")" "$temporary"
  /usr/bin/plutil -insert app_path -string "$app" "$temporary"
  /usr/bin/plutil -insert library_path -string "$library" "$temporary"
  /usr/bin/plutil -insert profile -string "$profile" "$temporary"
  /usr/bin/plutil -insert render_cap -integer "$cap" "$temporary"
  /usr/bin/plutil -insert launcher_path -string "$HOME/Applications/CS2.app" "$temporary"
  chmod 600 "$temporary"
  mv -n "$temporary" "$state"
  [ ! -e "$temporary" ] || { rm -f "$temporary"; cs2mac_error 'Another setup created the state file'; return 1; }
}

cs2mac_apply_profile() {
  local app=$1 library=$2 cap=$3 profile=$4 info
  cs2mac_validate_cap "$cap" || return 1
  cs2mac_choose_profile "$profile" >/dev/null || return 1
  info="$app/Contents/Info.plist"
  [ -f "$info" ] && [ ! -L "$info" ] || { cs2mac_error 'Runtime Info.plist is missing or redirected'; return 1; }
  /usr/bin/plutil -replace D3DMETAL -integer 0 "$info"
  /usr/bin/plutil -replace DXVK -integer 0 "$info"
  /usr/bin/plutil -replace WINEMSYNC -integer 1 "$info"
  /usr/bin/plutil -replace WINEESYNC -integer 0 "$info"
  /usr/bin/plutil -replace METAL_HUD -integer 0 "$info"
  /usr/bin/plutil -replace 'Debug Mode' -integer 0 "$info"
  /usr/bin/plutil -replace WINEDEBUG -string '-all' "$info"
  /usr/bin/plutil -replace 'CLI Custom Commands' -string "export DXMT_CONFIG='[cs2.exe];d3d11.preferredMaxFrameRate=$cap;'" "$info"
  /usr/bin/plutil -replace 'Program Name and Path' -string '/Program Files (x86)/Steam/Steam.exe' "$info"
  /usr/bin/plutil -replace 'Program Flags' -string '-silent -applaunch 730' "$info"
}

cs2mac_prepare_game() {
  # Called only after the launcher's owned-game-not-running guard. Steam account
  # configuration is never read: only this game's video settings are considered.
  local app=$1 library=$2 profile=$3 cap=$4 game cfg tmp prefix video backup marker width height texture msaa
  cs2mac_validate_cap "$cap" || return 1
  game="$library/steamapps/common/Counter-Strike Global Offensive"
  [ -d "$game/game/csgo/cfg" ] || return 0
  [ ! -L "$game/game/csgo/cfg" ] || { cs2mac_error 'Game cfg directory is redirected'; return 1; }
  cfg="$game/game/csgo/cfg/cs2mac.cfg"
  [ ! -L "$cfg" ] || { cs2mac_error 'cs2mac.cfg is redirected'; return 1; }
  if [ -f "$cfg" ] && ! /usr/bin/head -n 1 "$cfg" | /usr/bin/grep -qx '// Managed by cs2-mac'; then
    cs2mac_error 'An unrelated cs2mac.cfg already exists; preserving it'; return 1
  fi
  tmp=$(mktemp "$game/game/csgo/cfg/.cs2mac.XXXXXX") || return 1
  printf '// Managed by cs2-mac\nfps_max 0\nfps_max_ui 64\ncon_enable 1\ncl_showfps 0\n' > "$tmp"
  chmod 644 "$tmp"; mv -f "$tmp" "$cfg"
  case "$profile" in
    balanced1080) width=1920; height=1080; texture=1; msaa=0 ;;
    quality1440) width=2560; height=1440; texture=2; msaa=2 ;;
    *) cs2mac_error 'Unknown graphics profile'; return 1 ;;
  esac
  prefix="$app/Contents/SharedSupport/prefix"
  # Nullglob is confined to a subshell. Existing video files only: the game creates
  # its account-specific file on first launch. Subsequent starts apply the preset.
  (
    shopt -s nullglob
    for video in "$prefix"/drive_c/'Program Files (x86)'/Steam/userdata/*/730/local/cfg/cs2_video.txt; do
      [ -f "$video" ] && [ ! -L "$video" ] || continue
      # Reject redirected ancestors before writing inside the managed prefix.
      local resolved root
      root=$(cd -P "$prefix" && pwd) || exit 1
      resolved=$(cd -P "$(dirname "$video")" && pwd) || exit 1
      case "$resolved/" in "$root/"*) ;; *) cs2mac_error 'Video config is outside this prefix'; exit 1 ;; esac
      backup="$video.cs2mac-original"
      marker="$video.cs2mac-profile"
      # Presets are starting points. Once applied, leave later in-game edits alone.
      [ ! -e "$marker" ] && [ ! -L "$marker" ] || continue
      [ ! -L "$backup" ] || { cs2mac_error 'Video backup is redirected; preserving settings'; continue; }
      if [ ! -e "$backup" ] && [ ! -L "$backup" ]; then
        (umask 077; cp -p "$video" "$backup") || exit 1
      fi
      tmp=$(mktemp "$(dirname "$video")/.cs2mac-video.XXXXXX") || exit 1
      # Change known keys in the existing format; no guessed console variables.
      /usr/bin/awk -v w="$width" -v h="$height" -v tx="$texture" -v aa="$msaa" '
        BEGIN {
          v["VendorID"]="4203"; v["DeviceID"]="0"; v["AutoConfig"]="2";
          v["setting.defaultres"]=w; v["setting.defaultresheight"]=h;
          v["setting.fullscreen"]="0"; v["setting.coop_fullscreen"]="0";
          v["setting.nowindowborder"]="1"; v["setting.mat_vsync"]="0";
          v["setting.refreshrate_numerator"]="0"; v["setting.refreshrate_denominator"]="0";
          v["setting.shaderquality"]="0"; v["setting.r_texturefilteringquality"]="5";
          v["setting.msaa_samples"]=aa; v["setting.r_csgo_cmaa_enable"]="0";
          v["setting.videocfg_shadow_quality"]="1"; v["setting.videocfg_dynamic_shadows"]="1";
          v["setting.videocfg_texture_detail"]=tx; v["setting.videocfg_particle_detail"]="0";
          v["setting.videocfg_ao_detail"]="0"; v["setting.videocfg_hdr_detail"]="-1";
          v["setting.videocfg_fsr_detail"]="2"; v["setting.r_low_latency"]="0";
        }
        {
          line=$0; key=$0; sub(/^[^\"]*\"/,"",key); sub(/\".*/,"",key);
          if (key in v) {
            prefix=line; sub(/\"[^\"]*\"[ \t]*\"[^\"]*\".*/,"",prefix);
            print prefix "\"" key "\"\t\t\"" v[key] "\""; seen[key]=1;
          } else print line;
        }
        END { for (key in v) if (!(key in seen)) missing=1; if (missing) exit 3; }
      ' "$video" > "$tmp" || { rm -f "$tmp"; cs2mac_error 'Video format differs; preset was not written. Set Video options in CS2.'; continue; }
      chmod 600 "$tmp"; mv -f "$tmp" "$video"
      (umask 077; set -C; printf 'cs2-mac:v1:%s\n' "$profile" > "$marker") || exit 1
    done
  )
}
