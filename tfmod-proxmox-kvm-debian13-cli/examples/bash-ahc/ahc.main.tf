
## Example of copying and running a custom script on the created VM.
## Assumes the custom script is located in ../scripts/install_ahc.sh
##
resource "null_resource" "call_custom_script" {
  provisioner "local-exec" {
    command = <<EOT
      scp -o StrictHostKeyChecking=no -i ${var.pvt_key_file} ../scripts/install_ahc.sh ${var.superuser_username}@${local.host_ip}:/home/${var.superuser_username}/install_ahc.sh
      ssh -o StrictHostKeyChecking=no -i ${var.pvt_key_file} ${var.superuser_username}@${local.host_ip} "chmod +x /home/${var.superuser_username}/install_ahc.sh && /home/${var.superuser_username}/install_ahc.sh"
    EOT
  }
}
