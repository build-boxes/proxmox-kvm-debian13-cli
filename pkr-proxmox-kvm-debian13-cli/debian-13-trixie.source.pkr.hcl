# This Packer builder is heavily derived from the original work done at https://github.com/shackofnoreturn/packer-proxmox-debian-12-bookworm-template
#
#
source "proxmox-iso" "debian-13" {
  proxmox_url              = "https://${var.proxmox_host}/api2/json"
  username                 = var.proxmox_api_user
  password                 = var.proxmox_api_password
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node

  vm_name                 = var.vm_name
  template_description    = "Debian 13 Trixie Packer, minimal  -- Created: ${formatdate("YYYY-MM-DD hh:mm:ss ZZZ", timestamp())}"
  tags                    = join(";", var.vm_image_tags)
  vm_id                   = var.vmid
  os                      = "l26"
  cpu_type                = var.cpu_type
  sockets                 = "1"
  cores                   = var.cores
  memory                  = endswith(var.memory, "G") ? convert(1024*parseint(replace(var.memory, "G", ""),10),string) : ( endswith(var.memory, "M") ? replace(var.memory, "M", "") : var.memory )
  machine                 = "q35"
  bios                    = "ovmf"
  efi_config {
      efi_storage_pool  = var.storage_pool
      pre_enrolled_keys = false
      efi_format        = "raw"
      efi_type          = "4m"
  }
  scsi_controller         = "virtio-scsi-single"
  qemu_agent              = true
  cloud_init              = true
  cloud_init_storage_pool = var.storage_pool

  network_adapters {
    bridge   = "vmbr0"
    firewall = true
    model    = "virtio"
    vlan_tag = var.network_vlan
  }

  disks {
    disk_size         = var.disk_size
    format            = var.disk_format
    storage_pool      = var.storage_pool
    ssd               = var.disk_ssd_enabled
    type              = "scsi"
  }

  boot_iso {
    type              = "sata"
    #iso_file          = var.iso_file
    iso_url           = var.dynamic_iso_url
    iso_storage_pool  = var.iso_storage_pool
    #iso_checksum      = var.iso_checksum
    iso_checksum      = var.dynamic_iso_checksum
    unmount           = true
  }

  http_directory = "http"
  http_port_min  = 8100
  http_port_max  = 8100
  boot_wait      = "13s"
  #boot_command   = ["<esc><wait>auto url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg<enter>"]
  #boot_command   = ["<esc><wait>auto url=${var.preseed_url}<enter>"]
  # Following is for debian13-normal-memory (1G RAM)
  # boot_command   = ["<esc><wait><down><down><wait2s><enter><wait4s><down><down><down><down><down><wait2s><enter><wait90s>${var.preseed_url}<wait2s><enter>"]
  # following is for debian13-minimal-memory (512M RAM)
  boot_command   = ["<esc><wait><down><down><wait2s><enter><wait4s><down><down><down><down><down><wait2s><enter><wait5s><enter><wait90s>${var.preseed_url}<wait2s><enter>"]
  #boot_command   = ["<esc><wait>", "install <wait>", " preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg <wait>", "debian-installer=en_US.UTF-8 <wait>", "auto <wait>", "locale=en_US.UTF-8 <wait>", "kbd-chooser/method=us <wait>", "keyboard-configuration/xkb-keymap=us <wait>", "netcfg/get_hostname={{ .Name }} <wait>", "netcfg/get_domain=vagrantup.com <wait>", "fb=false <wait>", "debconf/frontend=noninteractive <wait>", "console-setup/ask_detect=false <wait>", "console-keymaps-at/keymap=us <wait>", "grub-installer/bootdev=/dev/sda <wait>", "<enter><wait>"]

  ssh_username = "root"
  ssh_password = var.debian_root_password
  ssh_timeout  = "60m"
}
