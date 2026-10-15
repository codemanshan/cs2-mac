#!/bin/bash
set -euo pipefail
ROOT=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$ROOT/lib/common.sh"
export CS2MAC_SOURCE_DIR="$ROOT"

if [ "$(uname -s)" != Darwin ]; then
  printf 'This installer runs on macOS.\n' >&2; exit 1
fi
printf '\nCS2 for Apple Silicon Macs\n\n'
if ! /usr/bin/osascript <<'APPLESCRIPT'
display dialog "Set up the Windows version of Counter-Strike 2 in its own Mac runtime.\n\nThe installer downloads verified files from Sikarugir and Valve. You sign in to your own Steam account and install CS2 yourself. Existing Steam apps are kept separate.\n\nCS2 needs about 100 GB free. Performance depends on your Mac; competitive consistency is not guaranteed." with title "CS2 for Mac" buttons {"Cancel", "Continue"} default button "Continue"
APPLESCRIPT
then exit 0; fi

parent=$(/usr/bin/osascript <<'APPLESCRIPT'
POSIX path of (choose folder with prompt "Choose where to store CS2. An external SSD is fine. A CS2-Mac Library folder will be created here.")
APPLESCRIPT
) || exit 0
library="${parent%/}/CS2-Mac Library"
profile=$(cs2mac_choose_profile auto)
choice=$(/usr/bin/osascript - "$profile" <<'APPLESCRIPT'
on run argv
  set selectedName to "Balanced — 1080p"
  if item 1 of argv is "quality1440" then set selectedName to "Quality — 1440p"
  set selected to choose from list {"Balanced — 1080p", "Quality — 1440p"} with title "CS2 for Mac" with prompt "Choose a starting graphics profile. Balanced is recommended for most Macs. These are starting points, not FPS promises." default items {selectedName}
  if selected is false then error number -128
  return item 1 of selected
end run
APPLESCRIPT
) || exit 0
case "$choice" in "Quality"*) profile=quality1440 ;; *) profile=balanced1080 ;; esac
cap=$(cs2mac_choose_refresh auto)
printf 'Game library: %s\nProfile: %s\nCurrent main-display pacing: %s (0 means automatic detection was unavailable)\n\n' "$library" "$profile" "$cap"

if "$ROOT/bin/cs2-mac" setup --library "$library" --profile "$profile" --refresh-hz "$cap"; then
  options=$(cs2mac_launch_options "$profile")
  printf '\nAfter Steam installs:\n1. Sign in to your own account.\n2. Install Counter-Strike 2 into V:\\ (the folder you selected).\n3. In Windows Steam, open CS2 > Properties > General and paste these Launch Options:\n\n%s\n\nThen open CS2 in your Applications folder.\n' "$options"
  answer=$(/usr/bin/osascript <<'APPLESCRIPT'
display dialog "The Steam installer is opening. Finish it, sign in, and install Counter-Strike 2.\n\nOne time: in Windows Steam, open CS2 → Properties → General and paste this toolkit’s Launch Options.\n\nYour CS2 launcher is in Applications. Read START HERE for the short walkthrough." with title "CS2 for Mac" buttons {"Done", "Copy Launch Options"} default button "Copy Launch Options"
return button returned of result
APPLESCRIPT
  ) || exit 0
  if [ "$answer" = 'Copy Launch Options' ]; then printf '%s' "$options" | /usr/bin/pbcopy; fi
else
  printf '\nSetup stopped. Read the message above; your existing Steam installations were not replaced.\nPress Return to close this window.\n' >&2
  read -r unused || true
  exit 1
fi
