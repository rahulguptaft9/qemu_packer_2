#!/usr/bin/env bash
set -euo pipefail

# Minimal first-boot service.
# This gives you a place to later add device-unique setup:
# - regenerate identity
# - set hostname from serial number
# - enroll device
# - pull customer-specific config

sudo tee /usr/local/sbin/applied-firstboot.sh >/dev/null <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

MARKER="/var/lib/applied-firstboot.done"

if [[ -f "${MARKER}" ]]; then
  exit 0
fi

mkdir -p /var/lib
printf 'firstboot completed: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${MARKER}"
SCRIPT

sudo chmod 0755 /usr/local/sbin/applied-firstboot.sh

sudo tee /etc/systemd/system/applied-firstboot.service >/dev/null <<'UNIT'
[Unit]
Description=Applied Timeclock First Boot Setup
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/var/lib/applied-firstboot.done

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/applied-firstboot.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable applied-firstboot.service
