locals {
  # Store the computed host IP address for reuse throughout the configuration
  host_ip = coalesce(try(split("/",proxmox_virtual_environment_vm.clone_edited_template.initialization[0].ip_config[0].ipv4[0].address)[0], null),proxmox_virtual_environment_vm.clone_edited_template.ipv4_addresses[1][0] )
}


# see https://registry.terraform.io/providers/bpg/proxmox/0.75.0/docs/data-sources/virtual_environment_vms
data "proxmox_virtual_environment_vms" "debian13_templates" {
  tags = var.proxmox_vm_template_tags
  node_name="jupyter"
}

# see https://registry.terraform.io/providers/bpg/proxmox/0.75.0/docs/data-sources/virtual_environment_vm
data "proxmox_virtual_environment_vm" "debian13_template" {
  node_name = data.proxmox_virtual_environment_vms.debian13_templates.vms[0].node_name
  vm_id     = data.proxmox_virtual_environment_vms.debian13_templates.vms[0].vm_id
}

# the virtual machine cloudbase-init cloud-config.
# NB the parts are executed by their declared order.
# see https://github.com/cloudbase/cloudbase-init
# see https://cloudbase-init.readthedocs.io/en/1.1.6/userdata.html#cloud-config
# see https://cloudbase-init.readthedocs.io/en/1.1.6/userdata.html#userdata
# see https://registry.terraform.io/providers/hashicorp/cloudinit/latest/docs/data-sources/config.html
# see https://developer.hashicorp.com/terraform/language/expressions#string-literals
data "cloudinit_config" "initialize_sudo_disks" {
  gzip          = false
  base64_encode = false
  part {
    filename     = "initialize-disks.sh"
    content_type = "text/x-shellscript"
    content      = <<-EOF
      #!/bin/bash
      
      echo "${var.superuser_username} ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/${var.superuser_username}
      sudo chmod 0440 /etc/sudoers.d/${var.superuser_username}

      # Identify all disks without partitions and initialize them for LVM
      echo "Starting non-boot disk initialization for LVM..."      
      n=2
      for disk in $(lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print $1}'); do
        if ! lsblk /dev/$disk | grep -q part; then
          echo "Found raw disk: /dev/$disk"
      
          # Create an MBR partition table
          parted -s /dev/$disk mklabel msdos
      
          # Create a single primary partition that spans the entire disk
          parted -s /dev/$disk mkpart primary ext4 0% 100%
      
          # Wait for the kernel to re-read partition table
          partprobe /dev/$disk
      
          # Prepare the partition for LVM (create PV)
          pvcreate /dev/$${disk}1
      
          # Optional: add to VG (example: vgname)
          vgcreate my_vg_edisk$n /dev/$${disk}1
          ((n++))
      
          echo "Initialized /dev/$${disk}1 for LVM"
        fi
      done
      echo "... Non-boot disk initialization for LVM completed."
      EOF
  }
}

# see https://registry.terraform.io/providers/bpg/proxmox/0.75.0/docs/resources/virtual_environment_file
resource "proxmox_virtual_environment_file" "initialize_ci_user_data" {
  content_type = "snippets"
  datastore_id = var.proxmox_datastore_id
  node_name    = var.proxmox_node_name
  source_raw {
    file_name = "${var.prefix}-ci-user-data.txt"
    data      = data.cloudinit_config.initialize_sudo_disks.rendered
  }
}

# see https://registry.terraform.io/providers/bpg/proxmox/0.75.0/docs/resources/virtual_environment_vm
resource "proxmox_virtual_environment_vm" "clone_edited_template" {
  name      = var.prefix
  node_name = var.proxmox_node_name
  tags      = var.proxmox_vm_tags
  clone {
    vm_id = data.proxmox_virtual_environment_vm.debian13_template.vm_id
    full  = true
  }
  cpu {
    type  = "host"
    #type  = "x86-64-v2-AES"
    cores = var.cpu_core_count
  }
  memory {
    dedicated = endswith(var.memory_size, "G") ? 1024 * tonumber(replace(var.memory_size, "G", "")) : ( endswith(var.memory_size, "M") ? tonumber(replace(var.memory_size, "M", "")) : tonumber(var.memory_size) )
  }
  network_device {
    bridge = "vmbr0"
  }
  disk {      # Boot Disk, Size can be increased here. Then manually Increase Volume size inside Windows-2025.
    datastore_id = var.proxmox_datastore_id
    interface   = "scsi0"
    file_format = "raw"
    iothread    = true
    ssd         = var.disk_boot_ssd_enabled
    discard     = "on"
    size        = endswith(var.disk_size_boot, "G") ? tonumber(replace(var.disk_size_boot, "G", "")) : ( endswith(var.disk_size_boot, "M") ? tonumber(replace(var.disk_size_boot, "M", "")) / 1024 : tonumber(var.disk_size_boot) / 1024 )
  }
  ## Add additional Disks here, if required.
  ##
  ##
  # disk {      # Boot Disk, Size can be increased here. Then manually Increase Volume size inside Windows-2025.
  #   datastore_id = var.proxmox_datastore_id
  #   interface   = "scsi1"
  #   file_format = "raw"
  #   iothread    = true
  #   ssd         = true
  #   discard     = "on"
  #   size        = 16     # minimum size of the Template image disk.
  # }

  agent {
    enabled = true
    #trim    = true
  }
  # NB we use a custom user data because this terraform provider initialization
  #    block is not entirely compatible with cloudbase-init (the cloud-init
  #    implementation that is used in the windows base image).
  # see https://pve.proxmox.com/wiki/Cloud-Init_Support
  # see https://cloudbase-init.readthedocs.io/en/latest/services.html#openstack-configuration-drive
  # see https://registry.terraform.io/providers/bpg/proxmox/0.75.0/docs/resources/virtual_environment_vm#initialization
  initialization {
    user_data_file_id = proxmox_virtual_environment_file.initialize_ci_user_data.id
    datastore_id = var.proxmox_datastore_id    
    # # >>> Fixed IP -- Start
    # # Use following if need fixed IP Address, otherwise comment out
    ip_config {
      ipv4 {
        address = var.vm_fixed_ip
        gateway = var.vm_fixed_gateway
      }
    }
    dns {
      servers = var.vm_fixed_dns
    }
    # # >>> Fixed IP -- End
  }
}

resource "time_sleep" "wait_1_minutes_1" {
  depends_on = [proxmox_virtual_environment_vm.clone_edited_template]
  # 12 minutes sleep. I have a slow Proxmox Host :(
  create_duration = "1m"
}

# # NB this can only connect after about 3m15s (because the ssh service in the
# #    windows base image is configured as "delayed start").
resource "null_resource" "ssh_into_vm" {
  depends_on = [time_sleep.wait_1_minutes_1]
  provisioner "remote-exec" {
    connection {
      target_platform = "unix"
      type            = "ssh"
      host            = local.host_ip
      user            = var.superuser_username
      password        = var.superuser_old_password
      private_key = file("${var.pvt_key_file}")
      agent = false
      timeout = "2m"
    }
    # NB this is executed as a batch script by cmd.exe.
    inline = [
      <<-EOF
      echo "Sucessfully logged in as user: '$(whoami)'";
      echo "Resetting password expiration...";
      echo "${var.superuser_username}:${var.superuser_new_password}" | sudo chpasswd;
      sudo chage -I -1 -m 0 -M -1 -E -1 ${var.superuser_username};
      echo "Resetting 'root' password expiration...";
      echo "root:${var.root_new_password}" | sudo chpasswd;
      sudo chage -I -1 -m 0 -M -1 -E -1 root;
      echo "Configuring passwordless sudo for ${var.superuser_username}...";
      echo "${var.superuser_username} ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/${var.superuser_username};
      sudo chmod 0440 /etc/sudoers.d/${var.superuser_username};
      echo "Password reset and sudo configuration completed";      
      USERID="${var.superuser_username}";
      BASHRC="/home/${var.superuser_username}/.bashrc";
      if [ -d "/home/${var.superuser_username}" ] && [ -f "$BASHRC" ]; then
        grep -q "/usr/sbin" "$BASHRC" || echo 'export PATH="/usr/sbin:$PATH"' >> "$BASHRC"
        echo "Added /usr/sbin to user PATH variable"
      fi;
      # Fix Flathub inclusion in gnome-software app for user
      #gnome-software --quit
      flatpak --user remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
      flatpak --user remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
      echo "Fixed Flathub inclusion in gnome-software App store for User"
      # Set Hostname to prefix
      echo "Setting hostname to ${var.prefix}"
      sudo hostnamectl set-hostname ${var.prefix}
      sudo sed -i 's/127.0.1.1\s\+debian/127.0.1.1\t${var.prefix}/' /etc/hosts
      ## For debian13-cli - Fix dns, Disable ipv6
      ##
      echo "Setting DNS servers to ${join(" ", var.vm_fixed_dns)}"
      sudo bash -c 'cat > /etc/resolv.conf << EOL
      nameserver ${join("\nnameserver ", var.vm_fixed_dns)}
      EOL'
      echo "Disabling IPv6..."
      sudo bash -c 'cat >> /etc/sysctl.d/99-disable-ipv6.conf << EOL
      net.ipv6.conf.all.disable_ipv6 = 1
      net.ipv6.conf.default.disable_ipv6 = 1
      net.ipv6.conf.lo.disable_ipv6 = 1
      EOL'
      sudo sysctl -p /etc/sysctl.d/99-disable-ipv6.conf
      ##
      ## End dns and ipv6 fix
      ##
      ## Extend Root filesystem to fill boot disk
      ##
      echo "Extending root filesystem to fill boot disk..."
      sudo growpart /dev/sda 3
      sudo pvresize /dev/sda3
      sudo lvextend -l +100%FREE /dev/debian-vg/root
      sudo resize2fs /dev/debian-vg/root
      echo "Extended root filesystem to fill boot disk."
      ## End Extend Root filesystem to fill boot disk
      EOF
    ]
  }
}

resource "time_sleep" "wait_3_minutes_2" {
  depends_on = [null_resource.ssh_into_vm]
  # 12 minutes sleep. I have a slow Proxmox Host :(
  create_duration = "3m"
}

resource "null_resource" "wait_4_apt" {
  depends_on = [time_sleep.wait_3_minutes_2]
  provisioner "remote-exec" {
    connection {
      target_platform = "unix"
      type            = "ssh"
      host            = local.host_ip
      user            = var.superuser_username
      password        = var.superuser_new_password
      private_key     = file("${var.pvt_key_file}")
      agent           = false
      timeout         = "5m"
    }
    inline = [
      # Wait until no apt/dpkg lock is present
      "for i in {1..300}; do sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 || break; sleep 2; done",
      "for i in {1..300}; do sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || break; sleep 2; done",
      "for i in {1..300}; do sudo fuser /var/cache/apt/archives/lock >/dev/null 2>&1 || break; sleep 2; done"
    ]
  }
}

## Run Ansible Playbook to install and configure docker (if mandated by var.docker_installed).
## Assumes Ansible is installed on the local machine running Terraform.
## Also assumes the Ansible playbook is located in ../scripts/ansible_main.yml
##
resource "null_resource" "run_ansible_playbook" {
  depends_on = [null_resource.wait_4_apt]
  provisioner "local-exec" {
    #interpreter = ["/bin/bash"]
    working_dir = "../scripts"
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u '${var.superuser_username}' -i '${local.host_ip},' --private-key ${var.pvt_key_file} -e 'pub_key=${var.pub_key_file}' ansible_main.yml -e 'install_docker=${var.docker_intalled}'"
  }
}


resource "null_resource" "restart_vm" {
  depends_on = [null_resource.run_ansible_playbook]
  provisioner "remote-exec" {
    connection {
      target_platform = "unix"
      type            = "ssh"
      host            = local.host_ip
      user            = var.superuser_username
      password        = var.superuser_new_password
      private_key = file("${var.pvt_key_file}")
      agent = false
      timeout = "4m"
    }
    # NB this is executed as a batch script by cmd.exe.
    inline = [
      <<-EOF
      sudo reboot
      EOF
    ]
  }
}

resource "time_sleep" "wait_3_minutes_3" {
  depends_on = [null_resource.restart_vm]
  create_duration = "3m"
}

# resource "null_resource" "copy_compose_file" {
#   depends_on = [time_sleep.wait_3_minutes_2]
#   provisioner "local-exec" {
#     command = "scp -o StrictHostKeyChecking=no -i ${var.pvt_key_file} ../scripts/docker-compose.yml ${var.superuser_username}@${local.host_ip}:/home/${var.superuser_username}/"
#   }
# }

# resource "null_resource" "run_docker_compose" {
#   depends_on = [null_resource.copy_compose_file]
#   provisioner "local-exec" {
#     command = <<EOT
#       ssh -o StrictHostKeyChecking=no -i ${var.pvt_key_file} ${var.superuser_username}@${local.host_ip} "cd /home/${var.superuser_username} && sudo docker compose up -d && sleep 10 && sudo docker compose down && sleep 10 && sudo docker compose up -d"
#     EOT
#   }
# }

/*
## Example of copying and running a custom script on the created VM.
## Assumes the custom script is located in ../scripts/install_ahc.sh
##
resource "null_resource" "call_custom_script" {
  depends_on = [time_sleep.wait_3_minutes_2]
  provisioner "local-exec" {
    command = <<EOT
      scp -o StrictHostKeyChecking=no -i ${var.pvt_key_file} ../scripts/install_ahc.sh ${var.superuser_username}@${local.host_ip}:/home/${var.superuser_username}/install_ahc.sh
      ssh -o StrictHostKeyChecking=no -i ${var.pvt_key_file} ${var.superuser_username}@${local.host_ip} "chmod +x /home/${var.superuser_username}/install_ahc.sh && /home/${var.superuser_username}/install_ahc.sh"
    EOT
  }
}
*/


/*
## Example of running an Ansible playbook against the created VM.
## Assumes Ansible is installed on the local machine running Terraform.
## Also assumes the Ansible playbook is located in ../scripts/ansible_main.yml
##
resource "null_resource" "run_ansible_playbook" {
  depends_on = [time_sleep.wait_3_minutes_2]
  provisioner "local-exec" {
    #interpreter = ["/bin/bash"]
    working_dir = "../scripts"
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u '${var.superuser_username}' -i '${local.host_ip},' --private-key ${var.pvt_key_file} -e 'pub_key=${var.pub_key_file}' ansible_main.yml"
  }
}
*/
