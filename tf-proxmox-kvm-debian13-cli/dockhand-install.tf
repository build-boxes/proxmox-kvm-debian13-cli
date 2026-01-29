resource "null_resource" "copy_compose_file" {
  depends_on = [time_sleep.wait_3_minutes_3]
  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -i ${var.pvt_key_file} ../scripts/docker-compose.yml ${var.superuser_username}@${local.host_ip}:/home/${var.superuser_username}/"
  }
}

resource "null_resource" "run_docker_compose" {
  depends_on = [null_resource.copy_compose_file]
  provisioner "local-exec" {
    command = <<EOT
      ssh -o StrictHostKeyChecking=no -i ${var.pvt_key_file} ${var.superuser_username}@${local.host_ip} "cd /home/${var.superuser_username} && sudo docker compose up -d && sleep 10 && sudo docker compose down && sleep 10 && sudo docker compose up -d"
    EOT
  }
}
