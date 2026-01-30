# tfmod-proxmox-kvm-debian13-cli
Terraform module for Proxmox VE based KVM(Qemu VM) Debian13-CLI

## Overview
This module provisions a Debian 13 CLI-only virtual machine on Proxmox VE using Terraform, Ansible and KVM/QEMU.

## Features
- Automated VM deployment on Proxmox VE
- Debian 13 minimal CLI installation
- Configurable CPU, memory, and storage
- Network interface management
- Cloud-init support for custom provisioning

## Requirements
1. VM Hosting Server
    - Proxmox VE 8.0+
2. A computer to execute Terraform and Ansible.
    - WSL2 on Windows, or Debian/Ubuntu or RHEL/Fedora.
    - Terraform >= 1.12
    - Ansible client - needed for Docker installation at the minimum.
    - Git

## Usage

### Basic Example
```hcl
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.93.0"
    }
  }
}

provider "proxmox" {
    endpoint = "https://192.168.4.20:8006/api2/json"
    username = "terraform-prov@pve"
    password = "XXXXXXXX"
    insecure = true

  ssh {
    agent = true
    node {  
      name    = "pve"
      address = "192.168.4.20"
    }
  }
} 

module "debian13_vm" {
    source = "./tfmod-proxmox-kvm-debian13-cli"

    #VM-Name
    prefix = "debian-cli-01"
    
    cpu_core_count=3
    memory_size="2048M"
    disk_size_boot="20G"
    docker_installed=true

    pub_key_file="/home/XXXX/.ssh/id_rsa.pub"
    pvt_key_file="/home/XXXX/.ssh/id_rsa"
    superuser_username="terraform"
    superuser_old_password="XXXXXXXX"     # Set in Packer variables.
    superuser_new_password="XXXXXXXX"
    root_new_password="XXXXXXXX"

    # Tags used to identify Packer Built Template that this module supports....
    proxmox_vm_template_tags=["template", "debian13", "cli", "minimal"]

}
```

### Advanced Example
```hcl
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.93.0"
    }
  }
}

provider "proxmox" {
    endpoint = "https://192.168.4.20:8006/api2/json"
    username = "terraform-prov@pve"
    password = "XXXXXXXX"
    insecure = true

  ssh {
    agent = true
    node {  
      name    = "pve"
      address = "192.168.4.20"
    }
  }
} 

module "debian13_vm" {
    #source = "./tfmod-proxmox-kvm-debian13-cli"
    source = "git::https://github.com/build-boxes/proxmox-kvm-debian13-cli.git//tfmod-proxmox-kvm-debian13-cli"

    #VM-Name
    prefix = "debian-cli-01"
    
    cpu_core_count=1
    memory_size="512M"
    disk_size_boot="4G"
    docker_installed=false

    pub_key_file="/home/XXXX/.ssh/id_rsa.pub"
    pvt_key_file="/home/XXXX/.ssh/id_rsa"
    superuser_username="terraform"
    superuser_old_password="XXXXXXXX"     # Set in Packer variables.
    superuser_new_password="XXXXXXXX"
    root_new_password="XXXXXXXX"

    # Tags used to identify Packer Built Template that this module supports....
    proxmox_vm_template_tags=["template", "debian13", "cli", "minimal"]
    # Tags to give to created VM instance
    proxmox_vm_tags=["debian13", "cli", "random", "minimal"]

}
```

## Variables
See [`variables.tf`](./debian13-cli.variables.tf) for complete variable definitions.

## Outputs
See [`outputs.tf`](./debian13-cli.outputs.tf) for available outputs.

## License
MIT [LICENSE](./LICENSE)
