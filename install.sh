#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLIST="dev.camacojo.docker-mac-hosts-updater.plist"
DAEMON_PLIST="/Library/LaunchDaemons/$PLIST"

echo "Installing docker-hosts-updater..."

# Copy the Python script
cp "$SCRIPT_DIR/docker-hosts-updater.py" /usr/local/bin/docker-hosts-updater
chmod +x /usr/local/bin/docker-hosts-updater

# Unload existing daemon if present
if launchctl list | grep -q "dev.camacojo.docker-mac-hosts-updater" 2>/dev/null; then
    echo "Stopping existing daemon..."
    launchctl bootout system "$DAEMON_PLIST" 2>/dev/null || true
fi

# Install plist
cp "$SCRIPT_DIR/$PLIST" "$DAEMON_PLIST"
chmod 644 "$DAEMON_PLIST"

# Load daemon
launchctl bootstrap system "$DAEMON_PLIST"

echo ""
echo "Installed successfully!"
echo "  Status : sudo launchctl list | grep docker-hosts"
echo "  Logs   : tail -f /var/log/docker-hosts-updater.log"
