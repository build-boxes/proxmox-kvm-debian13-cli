# Packer Debian 13 (Trixie) Template for Proxmox
Packer configuration for creating Debian 13 virtual machine templates for Proxmox VE.

## Original Work Acknowledgement
This Packer builder is heavily derived from the original work done at [https://github.com/shackofnoreturn/packer-proxmox-debian-12-bookworm-template](https://github.com/shackofnoreturn/packer-proxmox-debian-12-bookworm-template)

## Requirements
For Client, running the build tools...
- WSL2 on Windows 11, OR Linux CLI - Debian/Ubuntu or RHEL/Fedora. 
- [Packer](https://www.packer.io/downloads)
- [Ansible control node](https://docs.ansible.com/projects/ansible/latest/installation_guide/intro_installation.html)
For Server, Hosting the VMs....
- [Proxmox VE](https://www.proxmox.com/en/proxmox-ve), [Enabling Proxmox No-Subscription Library](https://www.youtube.com/watch?v=5j0Zb6x_hOk&t=720s)


## Why
Time and time again you create a VM and go through the setup manually. This method automatically goes through all manual options using a preseed text script.  
This Packer script will build a minimal VM and convert it into template. This template will be saved on your Proxmox VE server. When ever you need a new VM, use the accompanying Terraform Module script to spin up a new customized and resized (if required) VM.

More info on preseeding: [preseed documentation](https://wiki.debian.org/DebianInstaller/Preseed)

## How
### 1. Authorized Keys
If you don't have one already. Create a new keypair.

```sh
ssh-keygen
```

I've just saved the key to the default location and left the passphrase empty.
After doing that you'll find your private (id_rsa) and public keys (id_rsa.pub) in your profile .ssh directory. (/Users/**YourUsername**/.ssh)

Copy the contents of your public key file and paste it in cloud.cfg
Replace or remove the example if you need to.

### 2. Creating a new VM Template
Templates are created by converting an existing VM to a template. Navigate to the project directory customize the scripts using any text editor.  
When ready to build the VM Template, you have 2 options.

#### Option 1 - Manually Download Debian13 ISO file and Build 
Execute the following command:

```bash
cd pkr*
packer init .
packer build -var-file vars/debian_13.actual.pkrvars.hcl -var "proxmox_api_password=PASSWORD_HERE" .
```

#### Option 2 - Dynamically determine the latest Debian13 ISO file and Build
Execute the following command:

```bash
cd pkr*
packer init .
./scripts/fetch-latest-debian13-iso-details.sh && packer build -var-file vars/debian_13.actual.pkrvars.hcl -var-file vars/generated-debian13-vars.pkrvars.hcl -var "proxmox_api_password=PASSWORD_HERE" .
```

### 3. Deploy a VM from a Template
To Manually deploy a new VM, Right-click the template in Proxmox VE, and select "Clone".

- **full clone** is a complete copy and is fully independent from the original VM or VM Template, but it requires the same disk space as the original
- **linked clone** requires less disk space but cannot run without access to the base VM Template. Not supported with LVM & ISCSI storage types

To use Terraform scripts to Automatically clone the template, resize and customize the Deployed VM, see the accompanying [Terraform Module Documentation](../tfmod-proxmox-kvm-debian13-cli/README.md).

### 4. Connect with cloned VM over SSH
(*Change the IP with your new VM's IP*)

```sh
ssh shackadmin@10.0.0.226
```

The ssh public/private keys, that were uploaded during Template Build, should work and no passwords should be needed.
