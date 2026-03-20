#!/bin/bash
set -e

DAEMON_PLIST="/Library/LaunchDaemons/dev.camacojo.docker-mac-hosts-updater.plist"

echo "Uninstalling docker-hosts-updater..."

# Stop and unload
launchctl bootout system "$DAEMON_PLIST" 2>/dev/null || true

# Remove files
rm -f "$DAEMON_PLIST"
rm -f /usr/local/bin/docker-hosts-updater

echo "Uninstalled. Managed /etc/hosts entries have been cleaned up."
