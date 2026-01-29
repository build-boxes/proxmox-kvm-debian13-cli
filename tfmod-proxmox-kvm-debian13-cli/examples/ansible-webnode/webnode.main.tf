## Example of running an Ansible playbook against the created VM.
## Assumes Ansible is installed on the local machine running Terraform.
## Also assumes the Ansible playbook is located in ../scripts/ansible_main.yml
##
resource "null_resource" "run_ansible_playbook" {
  provisioner "local-exec" {
    #interpreter = ["/bin/bash"]
    working_dir = "scripts"
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u '${var.superuser_username}' -i '${local.host_ip},' --private-key ${var.pvt_key_file} -e 'pub_key=${var.pub_key_file}' ansible_main.yml"
  }
}

