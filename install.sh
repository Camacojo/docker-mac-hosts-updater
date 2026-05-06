#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLIST="dev.camacojo.docker-mac-hosts-updater.plist"
DAEMON_PLIST="/Library/LaunchDaemons/$PLIST"

# launchd starts the daemon as root, which has no Docker CLI context. Without an
# explicit DOCKER_HOST, root falls back to /var/run/docker.sock — which only works
# when the active engine has a socket bound there. Detect the invoking user's
# engine and pin the daemon to its socket.
detect_docker_host() {
    local user user_home sock
    user="${SUDO_USER:-$USER}"
    user_home=$(dscl . -read "/Users/$user" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
    [ -z "$user_home" ] && user_home="$HOME"

    # 1. Live socket wins
    for sock in \
        "$user_home/.orbstack/run/docker.sock" \
        "$user_home/.docker/run/docker.sock" \
        "/var/run/docker.sock"; do
        if [ -S "$sock" ]; then
            echo "unix://$sock"
            return
        fi
    done

    # 2. Fall back to whichever engine is installed
    if [ -d /Applications/OrbStack.app ]; then
        echo "unix://$user_home/.orbstack/run/docker.sock"
        return
    fi
    if [ -d /Applications/Docker.app ]; then
        echo "unix://$user_home/.docker/run/docker.sock"
        return
    fi

    echo "unix:///var/run/docker.sock"
}

DOCKER_HOST_VALUE=$(detect_docker_host)
echo "Installing docker-hosts-updater..."
echo "  DOCKER_HOST: $DOCKER_HOST_VALUE"

# Copy the Python script
cp "$SCRIPT_DIR/docker-hosts-updater.py" /usr/local/bin/docker-hosts-updater
chmod +x /usr/local/bin/docker-hosts-updater

# Unload existing daemon (current label and legacy labels from before the rename)
for legacy_plist in \
    "$DAEMON_PLIST" \
    /Library/LaunchDaemons/com.dsens.docker-hosts-updater.plist; do
    if [ -f "$legacy_plist" ]; then
        echo "Stopping daemon: $(basename "$legacy_plist")..."
        launchctl bootout system "$legacy_plist" 2>/dev/null || true
        # Only delete legacy plists; the current one is overwritten below
        if [ "$legacy_plist" != "$DAEMON_PLIST" ]; then
            rm -f "$legacy_plist"
        fi
    fi
done

# Install plist and pin DOCKER_HOST for the daemon's environment
cp "$SCRIPT_DIR/$PLIST" "$DAEMON_PLIST"
chmod 644 "$DAEMON_PLIST"
/usr/libexec/PlistBuddy \
    -c "Add :EnvironmentVariables:DOCKER_HOST string $DOCKER_HOST_VALUE" \
    "$DAEMON_PLIST" 2>/dev/null \
  || /usr/libexec/PlistBuddy \
    -c "Set :EnvironmentVariables:DOCKER_HOST $DOCKER_HOST_VALUE" \
    "$DAEMON_PLIST"

# Load daemon
launchctl bootstrap system "$DAEMON_PLIST"

echo ""
echo "Installed successfully!"
echo "  Status : sudo launchctl list | grep docker-hosts"
echo "  Logs   : tail -f /var/log/docker-hosts-updater.log"
