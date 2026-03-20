# docker-hosts-updater

A macOS launchd daemon that automatically keeps `/etc/hosts` in sync with
Docker container hostname aliases on the `docker_hoster` network.

This replaces the `syventnl/docker-hoster` Docker image, which is incompatible
with Docker Engine 28+ and no longer works on macOS with OrbStack or modern
Docker Desktop.

## How it works

The daemon watches Docker events. When a container on the `docker_hoster`
network starts, it reads the container's hostname aliases and IP address and
adds them to `/etc/hosts`. When a container stops, the entries are removed.

Example: a container with alias `gs-api.local` on IP `192.168.97.5` results in:

```
192.168.97.5    gs-api.local    # docker-hosts-updater
```

## Requirements

- macOS
- [OrbStack](https://orbstack.dev) (recommended) or Docker Desktop
- Python 3 (pre-installed on macOS)
- `docker` CLI available in PATH

## Installation

```bash
git clone <repo-url>
cd docker-hosts-updater
sudo bash install.sh
```

That's it. The daemon starts immediately and restarts automatically on login.

## Usage

After installation, any container with a hostname alias on the `docker_hoster`
network is automatically accessible by that hostname from your browser.

**Configure your projects** by connecting services to the `docker_hoster`
network in `compose.yaml`:

```yaml
networks:
  default:
    name: docker_hoster
    external: true

services:
  nginx:
    networks:
      default:
        aliases:
          - myapp.local
```

**Create the shared network once** (if it doesn't exist yet):

```bash
docker network create docker_hoster
```

## Status and logs

```bash
# Check if the daemon is running
sudo launchctl list | grep docker-hosts

# View logs
tail -f /var/log/docker-hosts-updater.log
```

## Uninstall

```bash
sudo bash uninstall.sh
```

This stops the daemon, removes it from launchd and cleans up any managed
entries from `/etc/hosts`.
