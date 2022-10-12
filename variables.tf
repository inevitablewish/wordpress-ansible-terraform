variable "database_name" {}
variable "database_password" {}
variable "database_user" {}

variable "region" {}
variable "shared_credentials_file" {}
#variable "ami" {}
#variable "AZ1" {}
#variable "AZ2" {}
#variable "AZ3" {}
variable "instance_type" {
  type        = string
  description = "Type for EC2 Instnace"
  default     = "t2.micro"
}
variable "instance_class" {}
variable "PUBLIC_KEY_PATH" {}
variable "PRIV_KEY_PATH" {}

variable "aws_profile_name" {
    type = string
    description = "AWS Profile Name on your computer"
    sensitive = true
}

variable "vpc_cidr_block" {
  type        = string
  description = "Base CIDR Block for VPC"
  default     = "10.1.0.0/16"
}
variable "enable_dns_hostnames" {
  type        = bool
  description = "Enable DNS hostnames in VPC"
  default     = true
}

variable "enable_dns_support" {
  type        = bool
  description = "Enable DNS Support within VPC"
  default     = true
}
variable "vpc_public_subnet_count" {
  type        = number
  description = "Number of Subnets to create"
  default     = 1
}
## RDS Requires atleast 2 subnets in two different AZs
variable "vpc_private_subnet_count" {
  type        = number
  description = "Number of Subnets to create"
  default     = 2
}
## 
variable "map_public_ip_on_launch" {
  type        = bool
  description = "Map a public IP address for Subnet instances"
  default     = true
}

variable "naming_prefix" {
  type        = string
  description = "Naming Prefix for all Resources"
  default     = "wordpress"
}
