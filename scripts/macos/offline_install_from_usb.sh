#!/bin/sh
# Offline macOS Sequoia install from the split InstallAssistant.pkg on this USB.
# Run from Recovery Terminal:  sh /Volumes/*/macos/go.sh
set -e
DEST=/Volumes/MACOS
EXPECTED=15664523626
APP="$DEST/Applications/Install macOS Sequoia.app"

SRC=$(ls -d /Volumes/*/macos 2>/dev/null | head -n 1)
if [ -z "$SRC" ]; then
  echo "ERROR: could not find the macos folder on any volume."
  exit 1
fi
if [ ! -d "$DEST" ]; then
  echo "ERROR: $DEST not found. Open Disk Utility and mount MACOS."
  exit 1
fi
echo "Found installer pieces in: $SRC"

if [ ! -d "$APP" ]; then
  echo "Step 1/3: joining the pieces onto MACOS (about 10 minutes, no progress shown)..."
  cat "$SRC"/InstallAssistant.pkg.part* > "$DEST/InstallAssistant.pkg"
  SIZE=$(stat -f %z "$DEST/InstallAssistant.pkg")
  if [ "$SIZE" != "$EXPECTED" ]; then
    echo "ERROR: joined file is $SIZE bytes, expected $EXPECTED."
    exit 1
  fi
  echo "Joined OK ($SIZE bytes)."
  echo "Step 2/3: unpacking the installer (5-15 minutes)..."
  installer -pkg "$DEST/InstallAssistant.pkg" -target "$DEST"
  rm -f "$DEST/InstallAssistant.pkg"
else
  echo "Installer already unpacked, skipping steps 1-2."
fi

echo "Step 3/3: opening the installer. Choose MACOS as the destination."
"$APP/Contents/MacOS/InstallAssistant_springboard"
