# creating Elastic IP for EC2
resource "aws_eip" "eip" {
  instance = aws_instance.wordpressec2.id
  tags={
    Name="${var.naming_prefix}-elastic-ip"
  }
}