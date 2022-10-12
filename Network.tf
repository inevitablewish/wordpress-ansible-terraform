data "aws_availability_zones" "available" {
  state = "available"
}



#############
## NETWORK ##
#############
# Create Public Subnet for EC2
resource "aws_subnet" "prod-public-subnet" {
  #count                   = var.vpc_private_subnet_count
  vpc_id                  = aws_vpc.prod-vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr_block,8,0)
  map_public_ip_on_launch = var.map_public_ip_on_launch //it makes this a public subnet
  availability_zone       = data.aws_availability_zones.available.names[1] # Added availibility zone
  tags={
    Name = "RDS-Public-Subnet-1"
  }
}

# Create Private subnet for RDS
resource "aws_subnet" "prod-private-subnet" {
  count                   = var.vpc_private_subnet_count
  vpc_id                  = aws_vpc.prod-vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr_block,8,count.index+2)
  map_public_ip_on_launch = "false" //it makes private subnet
  availability_zone       = data.aws_availability_zones.available.names[count.index] # Added availibility zone
  tags={
    Name = "RDS-Private-Subnet-${count.index}"
  }
}

# Create IGW for internet connection 
resource "aws_internet_gateway" "prod-igw" {
  vpc_id = aws_vpc.prod-vpc.id
  tags= {
    Name = "${var.naming_prefix}-igw"
  }
}

# Creating Route table 
resource "aws_route_table" "prod-public-crt" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    //associated subnet can reach everywhere
    cidr_block = "0.0.0.0/0"
    //CRT uses this IGW to reach internet
    gateway_id = aws_internet_gateway.prod-igw.id
  }

  tags= {
    Name = "${var.naming_prefix}-crt" 
    }

}


# Associating route tabe to public subnet
resource "aws_route_table_association" "prod-crta-public-subnet-1" {
  count          = var.vpc_public_subnet_count
  subnet_id      = aws_subnet.prod-public-subnet.id
  route_table_id = aws_route_table.prod-public-crt.id
}



//security group for EC2

resource "aws_security_group" "ec2_allow_rule" {


  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "MYSQL/Aurora"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  vpc_id = aws_vpc.prod-vpc.id
  tags = {
    Name = "${var.naming_prefix}-ec2-sg"
  }

  
}


# Security group for RDS
resource "aws_security_group" "RDS_allow_rule" {
  vpc_id = aws_vpc.prod-vpc.id
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = ["${aws_security_group.ec2_allow_rule.id}"]
  }
  # Allow all outbound traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.naming_prefix}-RDS-sg"
  }

}



# Create RDS Subnet group
resource "aws_db_subnet_group" "RDS_subnet_grp" {
  subnet_ids = aws_subnet.prod-private-subnet.*.id
  tags = {
    Name = "${var.naming_prefix}-RDS-subnet-grp"
  }
}