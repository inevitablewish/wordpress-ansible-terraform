data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}
# Create EC2 ( only after RDS is provisioned)
resource "aws_instance" "wordpressec2" {
  ami             = nonsensitive(data.aws_ssm_parameter.ami.value)
  instance_type   = var.instance_type
  subnet_id       = aws_subnet.prod-public-subnet.id
  security_groups = ["${aws_security_group.ec2_allow_rule.id}"]
  
  key_name = aws_key_pair.wp-key.id
  tags = {
    Name = "Wordpress.web"
  }
  # this will stop creating EC2 before RDS is provisioned
  depends_on = [aws_db_instance.wordpressdb]
}
// Sends your public key to the instance
resource "aws_key_pair" "wp-key" {
  key_name   = "wp-key"
  public_key = file(var.PUBLIC_KEY_PATH)
}
