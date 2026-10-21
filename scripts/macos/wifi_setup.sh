#!/bin/bash
# One-command setup for the TP-Link Archer T3U USB Wi-Fi driver (chris1111 OC V17).
# Run in macOS Terminal:  bash /Volumes/*/wifi/setup.sh
set -e
WORK="$HOME/Desktop/WiFi-Setup"
SRC="$(cd "$(dirname "$0")" && pwd)"

# The driver installer unmounts any volume named EFI (this USB), so run from the Desktop.
if [ "$SRC" != "$WORK" ]; then
  mkdir -p "$WORK"
  cp "$SRC/setup.sh" "$SRC"/*.zip "$WORK/"
  exec bash "$WORK/setup.sh"
fi
cd "$WORK"

echo "== 1/4 Checking SIP"
csrutil status
if csrutil status | grep -q "status: enabled"; then
  echo "SIP is still enabled. Run ssd_update.bat in Windows, reboot, and try again."
  exit 1
fi

echo "== 2/4 Turning off Gatekeeper (enter your Mac password if asked)"
sudo spctl --global-disable || true

echo "== 3/4 Unpacking the driver"
rm -rf app && mkdir app
ditto -xk ./*.zip app
xattr -dr com.apple.quarantine app 2>/dev/null || true
PKG="$(find app -name '*.pkg' -path '*/.Files/*' | head -n 1)"
if [ -z "$PKG" ]; then echo "Installer package not found in the zip."; exit 1; fi

echo "== 4/4 Installing (this also adds the kexts to the SSD's EFI)"
sudo installer -pkg "$PKG" -target /

echo
echo "Installed. Two things left:"
echo " 1. In the window that opens, set 'Allow applications from' to Anywhere."
echo " 2. Restart. A new Wi-Fi icon appears in the menu bar."
open "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension" 2>/dev/null || true

echo
read -r -p "Also remove the leftover macOS installer (frees about 15 GB)? [y/N] " ans
if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
  sudo rm -rf "/Applications/Install macOS Sequoia.app"
  sudo rm -f /System/Volumes/Data/InstallAssistant.pkg
  echo "Removed."
fi
