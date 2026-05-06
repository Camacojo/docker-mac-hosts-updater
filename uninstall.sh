#!/bin/bash
set -e

DAEMON_PLIST="/Library/LaunchDaemons/dev.camacojo.docker-mac-hosts-updater.plist"
LEGACY_PLISTS=(
    /Library/LaunchDaemons/com.dsens.docker-hosts-updater.plist
)

echo "Uninstalling docker-hosts-updater..."

# Stop and unload current + any legacy labels
for plist in "$DAEMON_PLIST" "${LEGACY_PLISTS[@]}"; do
    [ -f "$plist" ] || continue
    launchctl bootout system "$plist" 2>/dev/null || true
    rm -f "$plist"
done

rm -f /usr/local/bin/docker-hosts-updater

echo "Uninstalled. Managed /etc/hosts entries have been cleaned up."
