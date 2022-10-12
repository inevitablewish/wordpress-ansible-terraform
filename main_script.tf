
# Save Rendered playbook content to local file
resource "local_file" "playbook-rendered-file" {
  content = "${data.template_file.playbook.rendered}"
  filename = "./playbook-rendered.yml"
}

resource "null_resource" "Wordpress_Installation_Waiting" {
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file(var.PRIV_KEY_PATH)
    host        = aws_eip.eip.public_ip
  }
 # Run script to update python on remote client
  provisioner "remote-exec" {
     
     inline = ["sudo yum update -y","sudo yum install python3 -y", "echo Done!"]
   
  }

# Play ansible playbook
  provisioner "local-exec" {
     command = "ANSIBLE_HOST_KEY_CHECKING=FALSE ansible-playbook -u ec2-user -i '${aws_eip.eip.public_ip},' --private-key ${var.PRIV_KEY_PATH}  playbook-rendered.yml"
    

}

}



