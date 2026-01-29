terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.93.0"
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

module "debian13-cli" {
    #source = "git::https://github.com/build-boxes/proxmox-kvm-debian13-cli.git//tfmod-proxmox-kvm-debian13-cli"
    source = "../.."

    pub_key_file=var.pub_key_file
    pvt_key_file=var.pvt_key_file
    superuser_username=var.superuser_username
    superuser_old_password=var.superuser_old_password
    superuser_new_password=var.superuser_new_password
    root_new_password=var.root_new_password
    prefix=var.prefix

    proxmox_node_address=var.proxmox_node_address
    proxmox_node_name=var.proxmox_node_name
    proxmox_datastore_id=var.proxmox_datastore_id

    proxmox_vm_template_tags=var.proxmox_vm_template_tags
    proxmox_vm_tags=var.proxmox_vm_tags

    vm_fixed_ip=var.vm_fixed_ip
    vm_fixed_gateway=var.vm_fixed_gateway
    vm_fixed_dns=var.vm_fixed_dns
    cpu_core_count=var.cpu_core_count
    memory_size=var.memory_size
    disk_size_boot=var.disk_size_boot
    disk_boot_ssd_enabled=var.disk_boot_ssd_enabled
    docker_intalled=var.docker_intalled
}

resource "null_resource" "copy_compose_file" {
  depends_on = [module.debian13-cli]
  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -i ${var.pvt_key_file} scripts/docker-compose.yml ${var.superuser_username}@${module.debian13-cli.ip}:/home/${var.superuser_username}/"
  }
}

resource "null_resource" "run_docker_compose" {
  depends_on = [null_resource.copy_compose_file]
  provisioner "local-exec" {
    command = <<EOT
      ssh -o StrictHostKeyChecking=no -i ${var.pvt_key_file} ${var.superuser_username}@${module.debian13-cli.ip} "cd /home/${var.superuser_username} && sudo docker compose up -d && sleep 10 && sudo docker compose down && sleep 10 && sudo docker compose up -d"
    EOT
  }
}

output "vm1_ip_address" {
  value = module.debian13-cli.ip
}

output "script_output" {
    value = null_resource.run_docker_compose.*.triggers
}