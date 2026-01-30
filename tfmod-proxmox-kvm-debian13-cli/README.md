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
- Use pluggable custom scripts (Bash, docker-compose, Ansible, etc.) to automate further installation/customization as required.

## Requirements
1. Pre Built (by [Packer Automation](../pkr-proxmox-kvm-debian13-cli/README.md) ) VM Minimal Template stored on Proxmox VE Server.
1. VM Hosting Server
    - Proxmox VE 8.0+, [Proxmox VE](https://www.proxmox.com/en/proxmox-ve), [Enabling Proxmox No-Subscription Library](https://www.youtube.com/watch?v=5j0Zb6x_hOk&t=720s)
1. A computer to execute Terraform and Ansible.
    - WSL2 on Windows, or Debian/Ubuntu or RHEL/Fedora.
    - [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.12
    - [Ansible control node](https://docs.ansible.com/projects/ansible/latest/installation_guide/intro_installation.html) - needed for [Docker](https://docs.docker.com/get-started/docker-overview/) installation inside the VM.
    - [Git](https://git-scm.com/install/linux)

## Usage
1. Using a Text editor of your choice create a Terraform script, as shown in examples below or at [Project Website Examples](https://github.com/build-boxes/proxmox-kvm-debian13-cli/tree/main/tfmod-proxmox-kvm-debian13-cli/examples).
1. Provide meaningfull parameter values, or keep the defaults provided.
1. Make sure VM CPU, Memory, and Storage size are as per your requirements. Defaults are CPU-Count:1, Memory: 512M, OS_Disk: 4GB.
1. Optionaly provide further customization Scripts. Three examples are given:
  a. BASH Script
  b. Ansible Script
  c. docker-compose.yml file (Requires that VM parameter switch for docker is set to 'true')
1. Launch terraform. See section [Launch Terraform](#) below.

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

output "vm1_ip_address" {
  value = module.debian13_vm.ip
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

module "debian13_cli" {
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

# Following section is Launching Further Customization with a Bash Script.

## Example of copying and running a custom script on the created VM.
## Assumes the custom script is located in ../scripts/install_ahc.sh
##
resource "null_resource" "call_custom_script" {
  depends_on = [module.debian13_cli]  
  provisioner "local-exec" {
    command = <<EOT
      scp -o StrictHostKeyChecking=no -i ${var.pvt_key_file} ./scripts/install_ahc.actual.sh ${var.superuser_username}@${local.host_ip}:/home/${var.superuser_username}/install_ahc.sh
      ssh -o StrictHostKeyChecking=no -i ${var.pvt_key_file} ${var.superuser_username}@${local.host_ip} "chmod +x /home/${var.superuser_username}/install_ahc.sh && /home/${var.superuser_username}/install_ahc.sh"
    EOT
  }
}

output "vm1_ip_address" {
  value = module.debian13_cli.ip
}

output "script_output" {
    value = null_resource.call_custom_script.*.triggers
}

```
Bash Script
```BASH
#!/usr/bin/env bash
set -euo pipefail

# Installs: Accurate Hijri Calculator (AHC) in a Python virtual environment. https://github.com/accuhijri/ahc

# ------------------------------------------------------------
# Accurate Hijri Calculator (AHC) Automated Installer
# ------------------------------------------------------------

# Colors
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

echo -e "${GREEN}=== Accurate Hijri Calculator (AHC) Installer ===${RESET}"

# ------------------------------------------------------------
# 1. Check for required system packages
# ------------------------------------------------------------
echo -e "${YELLOW}Installing system dependencies...${RESET}"

if command -v apt >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y python3 python3-pip python3-venv git
elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y python3 python3-pip python3-virtualenv git
elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y python3 python3-pip python3-virtualenv git
else
    echo -e "${RED}Unsupported Linux distribution. Install Python3, pip, venv, and git manually.${RESET}"
    exit 1
fi

# ------------------------------------------------------------
# 2. Clone AHC repository
# ------------------------------------------------------------
echo -e "${YELLOW}Cloning AHC repository...${RESET}"

if [ ! -d "ahc" ]; then
    git clone https://github.com/hammadrauf/ahc.git
else
    echo -e "${YELLOW}Directory 'ahc' already exists. Updating...${RESET}"
    cd ahc
    git pull
    cd ..
fi

cd ahc

# ------------------------------------------------------------
# 3. Create virtual environment
# ------------------------------------------------------------
echo -e "${YELLOW}Creating Python virtual environment...${RESET}"

python3 -m venv venv
source venv/bin/activate

# ------------------------------------------------------------
# 4. Install Python dependencies
# ------------------------------------------------------------
echo -e "${YELLOW}Installing Python dependencies...${RESET}"

pip install --upgrade pip
pip install -r requirements.txt

# ------------------------------------------------------------
# 5. Install AHC package
# ------------------------------------------------------------
echo -e "${YELLOW}Installing AHC package...${RESET}"

pip install .

# ------------------------------------------------------------
# 6. Optional: Install geopandas (needed for visibility maps)
# ------------------------------------------------------------
echo -e "${YELLOW}Installing, optional package,  geopandas (needed for visibility maps)...${RESET}"
pip install geopandas

# ------------------------------------------------------------
# 7. Done
# ------------------------------------------------------------
echo -e "${GREEN}AHC installation complete!${RESET}"
echo -e "To activate the environment later, run:"
echo -e "${YELLOW}source ahc/venv/bin/activate${RESET}"

```

## More Examples
See [Project Website Examples](./examples)

## Launch Terraform
1. Switch into the sub folder containing your customized Terraform scripts.
1. Use the following command sequence to Launch Terraform deployemnts.
```bash
terraform init -upgrade
terraform plan
terraform apply -auto-approve
```
1. To delete the VM and all its resources use the following commands from the same folder.
```bash
terraform destroy -auto-approve
```


## Variables
See [`variables.tf`](./debian13-cli.variables.tf) for complete variable definitions.

## Outputs
See [`outputs.tf`](./debian13-cli.outputs.tf) for available outputs.

## License
MIT [LICENSE](./LICENSE)
