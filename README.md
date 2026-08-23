# Timeclock Packer QEMU Ubuntu Desktop Image

This repository builds an Ubuntu 24.04 Desktop golden-image baseline with OpenSSH enabled.

It is intentionally simple: Ubuntu Desktop install, SSH enabled, QEMU guest agent, and a first-boot placeholder.
Add PostgreSQL, RabbitMQ, drivers, kiosk mode, and hardening after this pipeline is proven.

## What it produces

GitHub Actions builds:

```text
applied-timeclock-ubuntu-24.04-desktop.raw.xz
applied-timeclock-ubuntu-24.04-desktop.raw.xz.sha256
```

The raw image is compressed with `xz` so it is smaller for GitHub artifact upload.

## Repo layout

```text
.github/workflows/build-raw-image.yml
packer/ubuntu-24.04.pkr.hcl
packer/http/meta-data
packer/http/user-data
scripts/10-minimal-setup.sh
scripts/20-install-firstboot.sh
scripts/90-cleanup.sh
```

## Run in GitHub Actions

Push this repository to GitHub, then run:

```text
Actions -> Build Ubuntu Desktop Raw Image -> Run workflow
```

The artifact will contain the compressed raw image.

## Run locally

Install dependencies:

```bash
sudo apt-get update
sudo apt-get install -y qemu-kvm qemu-utils ovmf xz-utils curl ca-certificates
```

Download ISO:

```bash
mkdir -p iso
curl -L -o iso/ubuntu-24.04.4-desktop-amd64.iso \
  https://releases.ubuntu.com/24.04.4/ubuntu-24.04.4-desktop-amd64.iso
curl -L -o iso/SHA256SUMS https://releases.ubuntu.com/24.04.4/SHA256SUMS
grep ' ubuntu-24.04.4-desktop-amd64.iso$' iso/SHA256SUMS > iso/SHA256SUMS.selected
(cd iso && sha256sum -c SHA256SUMS.selected)
```

Build:

```bash
ISO_SHA256="$(awk '{print $1}' iso/SHA256SUMS.selected)"

packer init packer/ubuntu-24.04.pkr.hcl
packer validate \
  -var "iso_url=file://${PWD}/iso/ubuntu-24.04.4-desktop-amd64.iso" \
  -var "iso_checksum=sha256:${ISO_SHA256}" \
  packer/ubuntu-24.04.pkr.hcl

packer build \
  -var "iso_url=file://${PWD}/iso/ubuntu-24.04.4-desktop-amd64.iso" \
  -var "iso_checksum=sha256:${ISO_SHA256}" \
  packer/ubuntu-24.04.pkr.hcl
```

Convert and compress:

```bash
mkdir -p dist
qemu-img convert -p -O raw \
  output/applied-timeclock-ubuntu-24.04-desktop/applied-timeclock-ubuntu-24.04-desktop.qcow2 \
  dist/applied-timeclock-ubuntu-24.04-desktop.raw
xz -T0 -9 -v dist/applied-timeclock-ubuntu-24.04-desktop.raw
sha256sum dist/applied-timeclock-ubuntu-24.04-desktop.raw.xz > dist/applied-timeclock-ubuntu-24.04-desktop.raw.xz.sha256
```

## Flash image

After downloading the artifact:

```bash
xz -dk applied-timeclock-ubuntu-24.04-desktop.raw.xz
sudo dd if=applied-timeclock-ubuntu-24.04-desktop.raw of=/dev/sdX bs=16M status=progress conv=fsync
```

Replace `/dev/sdX` carefully.

## Current login

Temporary baseline user:

```text
username: ubuntu
password: ubuntu
```

Do not use this credential model for production. Replace it before factory shipment.

## Important notes

- This uses the Ubuntu Desktop ISO: `ubuntu-24.04.4-desktop-amd64.iso`.
- The Desktop ISO is larger than the Server ISO, so the workflow timeout and disk size are increased.
- Desktop ISO installs may need Ubuntu archive access to install `openssh-server`, so the GitHub Actions runner must have internet access during installation.
- The Packer file uses UEFI with the Ubuntu 24.04 OVMF `_4M` firmware paths:
  - `/usr/share/OVMF/OVMF_CODE_4M.fd`
  - `/usr/share/OVMF/OVMF_VARS_4M.fd`
- `http_directory` is set to `${path.root}/http`, so `packer/http/user-data` and `packer/http/meta-data` are found correctly.
- Provisioner scripts use `${path.root}/../scripts/...`, so the template can be run from the repo root.
- The cleanup script clears machine identity and SSH host keys so cloned images regenerate unique values on first boot.
