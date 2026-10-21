#!/bin/sh
# Installs Apple's "Mobile Device" support update offline (needed for iPhone USB tethering).
# Run in macOS Terminal:  sh /Volumes/*/iphone/install.sh
cd "$(dirname "$0")" || exit 1
for p in MobileDeviceOnDemandPackage.pkg CoreTypes.pkg AppleKIS.pkg; do
  echo "Installing $p ..."
  sudo installer -pkg "$p" -target / || { echo "FAILED on $p"; exit 1; }
done
echo "Done. Unplug the iPhone, plug it back in, and turn on Personal Hotspot."
