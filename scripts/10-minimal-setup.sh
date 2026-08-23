#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y \
  openssh-server \
  ca-certificates \
  curl \
  wget \
  vim \
  qemu-guest-agent \
  cloud-init

sudo systemctl enable ssh
sudo systemctl enable qemu-guest-agent

# Marker file so you can confirm the provisioner ran.
sudo mkdir -p /opt/applied/timeclock
printf 'base-image-build: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" | sudo tee /opt/applied/timeclock/image-build.txt >/dev/null
