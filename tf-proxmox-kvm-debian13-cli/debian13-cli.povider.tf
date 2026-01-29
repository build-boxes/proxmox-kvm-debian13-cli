# Adapted from: https://github.com/build-boxes/terraform-proxmox-windows-example/blob/main/main.tf
#
#
# see https://github.com/hashicorp/terraform
terraform {
  required_providers {
    # see https://registry.terraform.io/providers/hashicorp/random
    random = {
      source  = "hashicorp/random"
      version = "3.7.1"
    }
    # see https://registry.terraform.io/providers/hashicorp/cloudinit
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "2.3.6"
    }
    # see https://registry.terraform.io/providers/bpg/proxmox
    # see https://github.com/bpg/terraform-provider-proxmox
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.93.0"
    }
    time = {
          source = "hashicorp/time"
          version = "0.13.1"
    }
  }
}

provider "proxmox" {
    endpoint = var.PROXMOX_VE_ENDPOINT
    username = var.PROXMOX_VE_USERNAME
    password = var.PROXMOX_VE_PASSWORD
    insecure = var.PROXMOX_VE_INSECURE
  ssh {
    agent = true
    node {  
      name    = var.proxmox_node_name
      address = var.proxmox_node_address
    }
  }
}
