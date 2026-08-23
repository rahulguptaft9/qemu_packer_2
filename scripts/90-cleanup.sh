#!/usr/bin/env bash
set -euo pipefail

# Keep the ubuntu user for this baseline image so Packer can complete cleanly.
# For a production/factory image, replace this with your real device access model.

sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*

# Reset machine-id so clones do not share the same identity.
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id

# Remove SSH host keys so each cloned device regenerates keys on first boot.
sudo rm -f /etc/ssh/ssh_host_*

# Clean logs.
sudo journalctl --rotate || true
sudo journalctl --vacuum-time=1s || true
sudo rm -f /var/log/*.log /var/log/*/*.log || true

# Sync filesystem before shutdown.
sync
