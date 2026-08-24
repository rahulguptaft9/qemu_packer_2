packer {
  required_plugins {
    qemu = {
      version = ">= 1.1.6"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "image_name" {
  type        = string
  description = "Base name for the generated image."
  default     = "applied-timeclock-ubuntu-24.04-desktop"
}

variable "iso_url" {
  type        = string
  description = "Ubuntu 24.04 Desktop ISO URL or local file path."
}

variable "iso_checksum" {
  type        = string
  description = "Ubuntu Desktop ISO checksum in sha256:<checksum> format."
}

variable "disk_size" {
  type        = string
  description = "Disk size for the image. Keep this smaller than the smallest physical disk/eMMC."
  default     = "30000M"
}

variable "ssh_username" {
  type        = string
  description = "Temporary SSH username used by Packer."
  default     = "ubuntu"
}

variable "ssh_password" {
  type        = string
  description = "Temporary SSH password used by Packer. Must match packer/http/user-data."
  default     = "ubuntu"
}

variable "efi_firmware_code" {
  type        = string
  description = "Path to OVMF UEFI CODE firmware."
  default     = "/usr/share/OVMF/OVMF_CODE_4M.fd"
}

variable "efi_firmware_vars" {
  type        = string
  description = "Path to OVMF UEFI VARS firmware."
  default     = "/usr/share/OVMF/OVMF_VARS_4M.fd"
}

source "qemu" "ubuntu_2404_desktop" {
  vm_name          = "${var.image_name}.qcow2"
  output_directory = "output/${var.image_name}"

  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  disk_size      = var.disk_size
  format         = "qcow2"
  accelerator    = "kvm"
  disk_interface = "virtio"
  net_device     = "virtio-net"

  cpus   = 4
  memory = 8192

  headless = true

  machine_type = "q35"
  efi_boot     = true

  efi_firmware_code = var.efi_firmware_code
  efi_firmware_vars = var.efi_firmware_vars

  http_directory = "${path.root}/http"

  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = "120m"

  shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"

  boot_wait = "5s"

  boot_command = [
    "e<wait>",
    "<down><down><down><end>",
    " autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---",
    "<f10>"
  ]
}

build {
  name    = "ubuntu-24.04-desktop"
  sources = ["source.qemu.ubuntu_2404_desktop"]

  provisioner "shell" {
    scripts = [
      "${path.root}/../scripts/10-minimal-setup.sh",
      "${path.root}/../scripts/20-install-firstboot.sh",
      "${path.root}/../scripts/90-cleanup.sh"
    ]
  }
}
