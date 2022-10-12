# Create VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = var.enable_dns_support #gives you an internal domain name
  enable_dns_hostnames = var.enable_dns_hostnames #gives you an internal host name
  
  tags= {
    Name = "${var.naming_prefix}-VPC"
  }


}