#!/usr/bin/env python3
"""
docker-hosts-updater

Watches Docker events and keeps /etc/hosts in sync with container
hostname aliases on the docker_hoster network.

Runs as a launchd daemon (root). Install with install.sh.
"""

import json
import logging
import signal
import subprocess
import sys
import time
from pathlib import Path

HOSTS_FILE = Path("/etc/hosts")
NETWORK_NAME = "docker_hoster"
MARKER = "# docker-hosts-updater"
RETRY_INTERVAL = 5

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[logging.StreamHandler(sys.stderr)],
)
log = logging.getLogger(__name__)


def docker(*args, timeout=5):
    return subprocess.run(
        ["docker"] + list(args),
        capture_output=True,
        text=True,
        timeout=timeout,
    )


def get_entries(container_id):
    """Return list of (ip, hostname) for a container on the docker_hoster network."""
    r = docker("inspect", container_id)
    if r.returncode != 0:
        return []
    try:
        info = json.loads(r.stdout)[0]
    except (json.JSONDecodeError, IndexError):
        return []

    entries = []
    for net_name, net in (info.get("NetworkSettings", {}).get("Networks", {}) or {}).items():
        if NETWORK_NAME not in net_name:
            continue
        ip = net.get("IPAddress", "")
        if not ip:
            continue
        for alias in (net.get("Aliases") or []):
            # Only proper hostnames (contain a dot), skip bare container IDs/names
            if "." in alias and not alias.startswith(container_id[:12]):
                entries.append((ip, alias))
    return entries


def remove_managed_entries():
    lines = HOSTS_FILE.read_text().splitlines(keepends=True)
    HOSTS_FILE.write_text("".join(l for l in lines if MARKER not in l))


def add_entries(entries):
    if not entries:
        return
    current = HOSTS_FILE.read_text()
    new_lines = []
    for ip, hostname in entries:
        if hostname not in current:
            new_lines.append(f"{ip}\t{hostname}\t{MARKER}\n")
            log.info("Adding: %s -> %s", hostname, ip)
    if new_lines:
        with HOSTS_FILE.open("a") as f:
            f.writelines(new_lines)


def refresh():
    """Rewrite all managed entries from currently running containers."""
    remove_managed_entries()
    r = docker("ps", "-q")
    if r.returncode != 0:
        return
    for cid in r.stdout.strip().splitlines():
        if cid:
            add_entries(get_entries(cid))


def handle_signal(signum, frame):
    log.info("Shutting down, cleaning /etc/hosts")
    remove_managed_entries()
    sys.exit(0)


def run():
    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    log.info("docker-hosts-updater started, watching network: %s", NETWORK_NAME)
    refresh()

    proc = subprocess.Popen(
        [
            "docker", "events",
            "--filter", "type=container",
            "--filter", "event=start",
            "--filter", "event=die",
            "--filter", "event=destroy",
            "--format", "{{.ID}} {{.Action}}",
        ],
        stdout=subprocess.PIPE,
        text=True,
    )

    try:
        for line in proc.stdout:
            parts = line.strip().split(" ", 1)
            if len(parts) != 2:
                continue
            cid, action = parts
            log.info("Event: %s %s", action, cid[:12])
            if action == "start":
                add_entries(get_entries(cid))
            else:
                refresh()
    finally:
        proc.terminate()


def main():
    while True:
        try:
            r = docker("info", timeout=3)
            if r.returncode != 0:
                raise RuntimeError("Docker not available")
            run()
        except Exception as e:
            log.warning("Error: %s, retrying in %ds", e, RETRY_INTERVAL)
            time.sleep(RETRY_INTERVAL)


if __name__ == "__main__":
    main()
