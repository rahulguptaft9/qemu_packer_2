name: Build Ubuntu Desktop Raw Image

on:
  workflow_dispatch:

jobs:
  build-image:
    runs-on: ubuntu-latest
    timeout-minutes: 240

    steps:
      - name: Checkout repo
        uses: actions/checkout@v4

      - name: Install build dependencies
        shell: bash
        run: |
          set -euxo pipefail

          sudo apt-get update
          sudo apt-get install -y \
            qemu-kvm \
            qemu-utils \
            ovmf \
            xz-utils \
            curl \
            ca-certificates

          echo "Checking KVM..."
          ls -lah /dev/kvm

          echo "Checking OVMF firmware..."
          ls -lah /usr/share/OVMF
          test -f /usr/share/OVMF/OVMF_CODE_4M.fd
          test -f /usr/share/OVMF/OVMF_VARS_4M.fd

      - name: Enable KVM permissions
        shell: bash
        run: |
          set -euxo pipefail

          sudo usermod -aG kvm "$USER" || true
          sudo chmod 666 /dev/kvm

      - name: Install Packer
        uses: hashicorp/setup-packer@main
        with:
          version: latest

      - name: Download Ubuntu Desktop ISO and verify checksum
        shell: bash
        run: |
          set -euxo pipefail

          ISO_VERSION="24.04.4"
          ISO_NAME="ubuntu-${ISO_VERSION}-desktop-amd64.iso"
          ISO_SHA256="3a4c9877b483ab46d7c3fbe165a0db275e1ae3cfe56a5657e5a47c2f99a99d1e"
          RELEASE_BASE_URL="https://releases.ubuntu.com/releases/${ISO_VERSION}"

          mkdir -p iso

          curl -L --fail --retry 5 --retry-delay 5 \
            -o "iso/${ISO_NAME}" \
            "${RELEASE_BASE_URL}/${ISO_NAME}"

          echo "${ISO_SHA256} *iso/${ISO_NAME}" | sha256sum -c -

          echo "ISO_PATH=${PWD}/iso/${ISO_NAME}" >> "$GITHUB_ENV"
          echo "ISO_CHECKSUM=sha256:${ISO_SHA256}" >> "$GITHUB_ENV"

      - name: Initialize Packer
        shell: bash
        run: |
          set -euxo pipefail

          packer init packer/ubuntu-24.04.pkr.hcl

      - name: Build QCOW2 image with Packer
        shell: bash
        run: |
          set -euxo pipefail

          echo "Using ISO: ${ISO_PATH}"
          echo "Using checksum: ${ISO_CHECKSUM}"

          packer build \
            -var "iso_url=file://${ISO_PATH}" \
            -var "iso_checksum=${ISO_CHECKSUM}" \
            packer/ubuntu-24.04.pkr.hcl

      - name: Convert QCOW2 to raw
        shell: bash
        run: |
          set -euxo pipefail

          IMAGE_NAME="applied-timeclock-ubuntu-24.04-desktop"

          QCOW2_PATH="output/${IMAGE_NAME}/${IMAGE_NAME}.qcow2"
          RAW_PATH="${IMAGE_NAME}.raw"

          test -f "${QCOW2_PATH}"

          qemu-img info "${QCOW2_PATH}"

          qemu-img convert \
            -p \
            -O raw \
            "${QCOW2_PATH}" \
            "${RAW_PATH}"

          qemu-img info "${RAW_PATH}"

      - name: Compress raw image
        shell: bash
        run: |
          set -euxo pipefail

          IMAGE_NAME="applied-timeclock-ubuntu-24.04-desktop"
          RAW_PATH="${IMAGE_NAME}.raw"
          COMPRESSED_PATH="${IMAGE_NAME}.raw.xz"

          test -f "${RAW_PATH}"

          xz -T0 -9 -v "${RAW_PATH}"

          test -f "${COMPRESSED_PATH}"

          sha256sum "${COMPRESSED_PATH}" > "${COMPRESSED_PATH}.sha256"

          ls -lh "${COMPRESSED_PATH}" "${COMPRESSED_PATH}.sha256"

      - name: Upload compressed raw image artifact
        uses: actions/upload-artifact@v4
        with:
          name: applied-timeclock-ubuntu-24.04-desktop-raw-xz
          path: |
            applied-timeclock-ubuntu-24.04-desktop.raw.xz
            applied-timeclock-ubuntu-24.04-desktop.raw.xz.sha256
          retention-days: 7
          compression-level: 0
