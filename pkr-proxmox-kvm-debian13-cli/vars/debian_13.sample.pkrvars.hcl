## INSTRUCTIONS: Make a copy of this file named "debian_13.actual.pkvars.hcl" and fill in the Actual values.
##
# This is a Shadow file, illustrating what the actual file should contain.
#
proxmox_host      = "10.0.0.10:8006"
proxmox_node      = "shackvm01"
vm_name           = "template-debian-13-cli"
vmid              = "9101"
cpu_type          = "host"
cores             = "1"
memory            = "512M"
storage_pool      = "local-lvm"
disk_size         = "4096M"
disk_format       = "raw"
disk_ssd_enabled  = false
vm_image_tags     = ["template", "debian13", "cli", "minimal"]

iso_file         = "vmdata:iso/debian-13.3.0-amd64-netinst.iso"
iso_checksum     = "sha512:1ada40e4c938528dd8e6b9c88c19b978a0f8e2a6757b9cf634987012d37ec98503ebf3e05acbae9be4c0ec00b52e8852106de1bda93a2399d125facea45400f8"
iso_storage_pool = "local:iso"
iso_url          = "https://cdimage.debian.org/debian-cd/13.3.0/amd64/iso-cd/debian-13.3.0-amd64-netinst.iso"

# it is hard coded in preseed cfg
debian_root_password = "packer"
preseed_url = "http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg"

# superuser details for (cloud-cfg file)
superuser_name     = "terraform"
superuser_gecos    = "Terraform Admin"
# md5 encoded password for "Hey0Password"
superuser_password = "$y$j9T$meabcdefghijkl"
superuser_ssh_pub_key = "ssh-rsa AAAAB3NzaC1ycXXXXXzRs= terraform@ServerName"
