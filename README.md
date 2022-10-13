# In Progress ...
# Deployment of WordPress Environment

# Summary

In this project, I have deployed WordPress on AWS using following tools/ technologies:

- Terraform
- Ansible
- Jinja

Terraform is used to create the infrastructure required to support the deployment of WordPress and Ansible is used to configure the WordPress environment (PHP, Apache web server, Database, WordPress Installation). Jinja is used to create WordPress configuration.

# Tools required
![image](https://user-images.githubusercontent.com/26683138/195488935-eee35cd1-3620-459f-9892-4bf79461f1dc.png)     ![image](https://user-images.githubusercontent.com/26683138/195488980-cca2fbe6-9fb4-4e52-94f6-28809eb2bee2.png)   ![image](https://user-images.githubusercontent.com/26683138/195489085-b3f12dbc-c400-46aa-8758-efbfd2adf07c.png)   ![image](https://user-images.githubusercontent.com/26683138/195489115-956cdac4-3df6-4eb4-aa3b-46f04682446a.png)   ![image](https://user-images.githubusercontent.com/26683138/195489142-d74cfe41-f166-4ba6-a73f-96da1923a12f.png)






# Environment Setup

The host machine requires to have Terraform and Ansible installed. The host machine OS is required to be Linux OS (Amazon Linux, Centos, RHEL) since Ansible is friendly in Windows OS. If the Linux OS is from Debian family, package manager changes are required in Ansible playbook.

# Requirements

- Establish configuration management master connectivity with WordPress server. ****
- Validate connectivity from master to slave machine. ****
- Prepare IaC scripts to install WordPress and its dependent components. ****
- Execute scripts to perform installation of complete WordPress environment. ****
- Validate installation using the public IP of VM by accessing WordPress application. ****

# Solution

## Terraform setup

1. Firstly, we will create terraform for the infrastructure to be deployed. A high level of architecture diagram provided below reflects the main components of the infrastructure.

![image](https://user-images.githubusercontent.com/26683138/195489247-547ddb33-59ed-42fe-a965-d6dbc429b0e7.png)

_Figure 1 Wordpress Architecture in AWS_

1. The main components of the infrastructure are listed as follows:

- EC2-Instance (wordpress installation)
- RDS Instance for Database
- 1 – Public Subnet (Ec2 Instance)
- 2 – Private Subnets for (RDS Database)
- Security Group for EC2 and RDS Database
- Routing Tables and their associations with respective subnets
- Elastic-IP for Ec2-instance to be keep static IP to be accessible from internet.
- Elastic Network interface to connect the traffic between public and private subnets.
- Internet gateway to connect to the internet.
- Virtual Private Cloud encapsulating all the above items.

1. The terraforms for respective components of infrastructure is shown below with a summary

### EC2- Instance:
```
data"aws\_ssm\_parameter""ami" {

  name ="/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86\_64-gp2"

}

# Create EC2 ( only after RDS is provisioned)

resource"aws\_instance""wordpressec2" {

  ami             =nonsensitive(data.aws\_ssm\_parameter.ami.value)

  instance\_type   = var.instance\_type

  subnet\_id       = aws\_subnet.prod-public-subnet.id

  security\_groups =["${aws\_security\_group.ec2\_allow\_rule.id}"]

  key\_name = aws\_key\_pair.wp-key.id

  tags ={

    Name = "Wordpress.web"

  }

  # this will stop creating EC2 before RDS is provisioned

  depends\_on =[aws\_db\_instance.wordpressdb]

}

// Sends your public key to the instance

resource"aws\_key\_pair""wp-key" {

  key\_name   ="wp-key"

  public\_key =file(var.PUBLIC\_KEY\_PATH)

}
```
When creating terraform for ec2-instance, I have firstly declared the data type to get the Amazon Machine Image to be used in the instance. Afterwards, an ec2 resource is generated with attributes like ANI, Security Groups, Subnet ID, Instance type and SSH keyname.

Ec2-Instance creation depends upon database instance since number of parameters e.g. RDS end-point creation before ec2 instance creation. Lastly, SSH **aws-key-pair** is generated to remotely access the instance. The same key will be used to deploy Ansible playbook at the later stage.

### RDS Database Instance
```
# Create RDS instance

resource"aws\_db\_instance""wordpressdb" {

  allocated\_storage      =10

  engine                 ="mysql"

  engine\_version         ="5.7"

  instance\_class         = var.instance\_class

  db\_subnet\_group\_name   = aws\_db\_subnet\_group.RDS\_subnet\_grp.id

  vpc\_security\_group\_ids =["${aws\_security\_group.RDS\_allow\_rule.id}"]

  db\_name                = var.database\_name

  username               = var.database\_user

  password               = var.database\_password

  skip\_final\_snapshot    =true

  tags ={

    Name = "${var.naming\_prefix}-RDS-instance"

  }

}

# change USERDATA variable values after grabbing RDS endpoint info

data"template\_file""playbook" {

  template =file("${path.module}/playbook\_wp.yml")

  vars ={

    db\_username      = "${var.database\_user}"

    db\_user\_password = "${var.database\_password}"

    db\_name          = "${var.database\_name}"

    db\_RDS           = "${aws\_db\_instance.wordpressdb.endpoint}"

  }

}
```
In RDS creation, database instance resource is declared with attributes encapsulating mysql configurations, security groups, subnets and storage.

This will result in creation of database endpoint that will be used in updating the yaml playbook to be used at later stage. This process is performed using template file data type and passing variables to **playbook.yaml**

### Network

#### Subnets
```
data"aws\_availability\_zones""available" {

  state ="available"

}

#############

## NETWORK ##

#############

# Create Public Subnet for EC2

resource"aws\_subnet""prod-public-subnet" {

  vpc\_id                  = aws\_vpc.prod-vpc.id

  cidr\_block              =cidrsubnet(var.vpc\_cidr\_block,8,0)

  map\_public\_ip\_on\_launch = var.map\_public\_ip\_on\_launch//it makes this a public subnet

  availability\_zone       = data.aws\_availability\_zones.available.names[1] # Added availibility zone

  tags={

    Name = "RDS-Public-Subnet-1"

  }

}

# Create Private subnet for RDS

resource"aws\_subnet""prod-private-subnet" {

  count                   = var.vpc\_private\_subnet\_count

  vpc\_id                  = aws\_vpc.prod-vpc.id

  cidr\_block              =cidrsubnet(var.vpc\_cidr\_block,8,count.index+2)

  map\_public\_ip\_on\_launch ="false"//it makes private subnet

  availability\_zone       = data.aws\_availability\_zones.available.names[count.index] # Added availibility zone

  tags={

    Name = "RDS-Private-Subnet-${count.index}"

  }

}
```
Within virtual private networks, subnets are created to segregate different type of resources. In our case, 1 public subnet is created for ec2 instance that is accessible from internet and two private subnets are created for database with no access to internet.

In the above code, I have used **cidrsubnet** function to provide subnet network range for CIDR block for public and private subnets.

In case of private subnet an increment of **2** is added to **count.index** to avoid overlap with public subnet.

#### Internet Gateway

An internet gateway is primary requirement for the wordpress to be accessible from outside world from internet. Internet gateway resource only requires VPC id as attribute.
```
# Create IGW for internet connection

resource"aws\_internet\_gateway""prod-igw" {

  vpc\_id = aws\_vpc.prod-vpc.id

  tags={

    Name = "${var.naming\_prefix}-igw"

  }

}
```
#### Route Table and association

Route table connects the VPC with internet through internet gateway on one side and associate the routing with public subnet
```
# Creating Route table

resource"aws\_route\_table""prod-public-crt" {

  vpc\_id = aws\_vpc.prod-vpc.id

  route {

    //associated subnet can reach everywhere

    cidr\_block ="0.0.0.0/0"

    //CRT uses this IGW to reach internet

    gateway\_id = aws\_internet\_gateway.prod-igw.id

  }

  tags={

    Name = "${var.naming\_prefix}-crt"

    }

}

# Associating route tabe to public subnet

resource"aws\_route\_table\_association""prod-crta-public-subnet-1" {

  #count          = var.vpc\_public\_subnet\_count

  subnet\_id      = aws\_subnet.prod-public-subnet.id

  route\_table\_id = aws\_route\_table.prod-public-crt.id

}
```
#### Security Groups

Security groups are created to control the flow of information between ec2-instance and database instance. This helps in managing the type of traffic and source to be allowed to communicate with database and ec2-instance. Two security groups are created for that purpose one for each ec2-instance and RDS Instance
```
//security group for EC2

resource"aws\_security\_group""ec2\_allow\_rule" {

  ingress {

    description ="HTTPS"

    from\_port   =443

    to\_port     =443

    protocol    ="tcp"

    cidr\_blocks =["0.0.0.0/0"]

  }

  ingress {

    description ="HTTP"

    from\_port   =80

    to\_port     =80

    protocol    ="tcp"

    cidr\_blocks =["0.0.0.0/0"]

  }

  ingress {

    description ="MYSQL/Aurora"

    from\_port   =3306

    to\_port     =3306

    protocol    ="tcp"

    cidr\_blocks =["0.0.0.0/0"]

  }

  ingress {

    description ="SSH"

    from\_port   =22

    to\_port     =22

    protocol    ="tcp"

    cidr\_blocks =["0.0.0.0/0"]

  }

  egress {

    from\_port   =0

    to\_port     =0

    protocol    ="-1"

    cidr\_blocks =["0.0.0.0/0"]

  }

  vpc\_id = aws\_vpc.prod-vpc.id

  tags ={

    Name = "${var.naming\_prefix}-ec2-sg"

  }

}

# Security group for RDS

resource"aws\_security\_group""RDS\_allow\_rule" {

  vpc\_id = aws\_vpc.prod-vpc.id

  ingress {

    from\_port       =3306

    to\_port         =3306

    protocol        ="tcp"

    security\_groups =["${aws\_security\_group.ec2\_allow\_rule.id}"]

  }

  # Allow all outbound traffic.

  egress {

    from\_port   =0

    to\_port     =0

    protocol    ="-1"

    cidr\_blocks =["0.0.0.0/0"]

  }

  tags ={

    Name = "${var.naming\_prefix}-RDS-sg"

  }

}
```
#### RDS Subnet Group

Since there is a requirement from AWS to set up two subnets when setting up RDS instance. In this project, I have added them together to be referenced in RDS Instance
```
resource"aws\_db\_subnet\_group""RDS\_subnet\_grp" {

  subnet\_ids =aws\_subnet.prod-private-subnet.\*.id

  tags ={

    Name = "${var.naming\_prefix}-RDS-subnet-grp"

  }

}
```
This completes the network part of the terraform.

### Elastic IP

Elastic IP is generated to address any downtime of ec2-instance by remapping it to another active instance.
```
# creating Elastic IP for EC2

resource"aws\_eip""eip" {

  instance = aws\_instance.wordpressec2.id

  tags={

    Name="${var.naming\_prefix}-elastic-ip"

  }

}
```
### VPC

Virtual Private Cloud is created to encapsulate the above created infrastructure as it is referenced in number of infrastructure items. Following is the terraform for creating a VPC
```
# Create VPC

resource"aws\_vpc""prod-vpc" {

  cidr\_block           = var.vpc\_cidr\_block

  enable\_dns\_support   = var.enable\_dns\_support#gives you an internal domain name

  enable\_dns\_hostnames = var.enable\_dns\_hostnames#gives you an internal host name

  tags={

    Name = "${var.naming\_prefix}-VPC"

  }

}
```
### Providers

In terraform, there are many types of providers available. A complete list of providers is available on [https://registry.terraform.io/browse/providers](https://registry.terraform.io/browse/providers).

In our case, AWS is the provider of our choice, and it can be declared as follow:
```
provider"aws" {

  region                  = var.region

  profile                 = var.aws\_profile\_name

}
```
### Terraform.tfvars

This file contains the values for the variables that are consistent throughout the environment. These are type of variables where the respective values already exists or provided.
```
database\_name           ="wordpress\_db"          // database name

database\_user           ="wordpress\_user"        //database username

shared\_credentials\_file ="~/.aws"                //Access key and Secret key file location

region                  ="ap-southeast-2"        //sydney region

PUBLIC\_KEY\_PATH         ="./wp-key.pub"          // key name for ec2, make sure it is created before terrafomr apply

PRIV\_KEY\_PATH           ="./wp-key"

instance\_type           ="t2.micro"              //type of instance

instance\_class          ="db.t2.micro"
```
### Variables

All variables used in this terraform are declared under variables.tf
```
variable"database\_name" {}

#variable "database\_password" {}

#variable "database\_user" {}

#variable "region" {}

#variable "shared\_credentials\_file" {}

#variable "ami" {}

#variable "AZ1" {}

#variable "AZ2" {}

#variable "AZ3" {}

variable"instance\_type" {

  type        =string

  description ="Type for EC2 Instnace"

  default     ="t2.micro"

}

#variable "instance\_class" {}

#variable "PUBLIC\_KEY\_PATH" {}

#variable "PRIV\_KEY\_PATH" {}

variable"aws\_profile\_name" {

    type =string

    description ="AWS Profile Name on your computer"

    sensitive =true

}

variable"vpc\_cidr\_block" {

  type        =string

  description ="Base CIDR Block for VPC"

  default     ="10.1.0.0/16"

}

variable"enable\_dns\_hostnames" {

  type        =bool

  description ="Enable DNS hostnames in VPC"

  default     =true

}

variable"enable\_dns\_support" {

  type        =bool

  description ="Enable DNS Support within VPC"

  default     =true

}

variable"vpc\_public\_subnet\_count" {

  type        =number

  description ="Number of Subnets to create"

  default     =1

}

## RDS Requires atleast 2 subnets in two different AZs

variable"vpc\_private\_subnet\_count" {

  type        =number

  description ="Number of Subnets to create"

  default     =1

}

##

variable"map\_public\_ip\_on\_launch" {

  type        =bool

  description ="Map a public IP address for Subnet instances"

  default     =true

}

variable"naming\_prefix" {

  type        =string

  description ="Naming Prefix for all Resources"

  default     ="wordpress"

}
```
### Main.tf

Main.tf has couple of resources to create updated yaml file that will be used to run using Ansible.
```
# Save Rendered playbook content to local file

resource"local\_file""playbook-rendered-file" {

  content ="${data.template\_file.playbook.rendered}"

  filename ="./playbook-rendered.yml"

}

A null resource is created to access wordpress remotely through SSH, remote-exec provisioner is used pass inline command to update the remote instance with python3 (for Ansible) and standard yum updates. Once these updates are completed, Ansible command is executed using local-exec provisioner at runtime, calling the inventory, username, SSH key and running the updated playbook saved in the parent directory.

resource"null\_resource""Wordpress\_Installation\_Waiting" {

  connection {

    type        ="ssh"

    user        ="ec2-user"

    private\_key =file(var.PRIV\_KEY\_PATH)

    host        = aws\_eip.eip.public\_ip

  }

# Run script to update python on remote client

  provisioner"remote-exec" {

     inline =["sudo yum update -y","sudo yum install python3 -y", "echo Done!"]

  }

# Play ansible playbook

  provisioner"local-exec" {

     command ="ANSIBLE\_HOST\_KEY\_CHECKING=FALSE ansible-playbook -u ec2-user -i '${aws\_eip.eip.public\_ip},' --private-key ${var.PRIV\_KEY\_PATH}  playbook-rendered.yml"

  }

}
```
### Outputs

After successfully running the terraform, it will provide us with the IP Address of ec2-instance (essentially an elastic IP) and the Database endpoint.
```
output"IP" {

  value = aws\_eip.eip.public\_ip

}

output"RDS-Endpoint" {

  value = aws\_db\_instance.wordpressdb.endpoint

}

output"INFO" {

  value ="AWS Resources and Wordpress has been provisioned. Go to http://${aws\_eip.eip.public\_ip}"

}
```
### Steps to deploy the infrastructure to AWS

1. To deploy the infrastructure declared in terraform, an SSH key is generated and saved in the root directory. SSH Key with filename wp-key is generated as follow
```
ssh-keygen -f wp-key
```
1. Press Enter from keyboard until key is generated, it looks like this
```
Generating public/private rsa key pair.

Enter passphrase (empty for no passphrase):

Enter same passphrase again:

Your identification has been saved in wp-key.

Your public key has been saved in wp-key.pub.

The key fingerprint is:

SHA256:g3tegMZqRMgoQasC7UVj7bDZ6xqw+GaUnBgR9EohY7A nova\mohsin.malik@NB-J1PV2Z2

The key's randomart image is:

+---[RSA3072]----+

|X\*  +.           |

|+B++...          |

|E++.o\*           |

|\*..oo.oo         |

|o=oo. =.S        |

|o.=+ o.. o       |

|... +.. . .      |

| .o. ..o .       |

| o. ..  .        |

+----[SHA256]-----+
```
## Ansible Setup

1. Now that Terraform has been set up, its time to configure Ansible. Ansible playbook named "playbook-wp.yml" is used to deploy wordpress , PHP, linux updates and permission sets.
2. In the first task, variables are declared to be used in different tasks.
```
- name: Install wordpress in new server

  hosts: all

  become: yes

  tasks:

  - name: Setting up variables

    set\_fact:

      php\_modules: [  'php-fpm',

                      'php-mysqlnd',

                      'php-curl',

                      'php-gd',

                      'php-mbstring',

                      'php-xml',

                      'php-xmlrpc',

                      'php-soap',

                      'php-intl',

                      'php-zip'

                      ]

#MySQL Settings to be rendered by terraform

      mysql\_rds: ${db\_RDS}

      mysql\_db: ${db\_name}

      mysql\_user: ${db\_username}

      mysql\_password: ${db\_user\_password}

1. Above snippet of yaml initiates playbook-wp with number of php modules declared as a list. This list can be used further to install in different task in the same file.
2. Set\_fact also contains number of other values for MySQL database to be set with data generated through terraform.
3. The next two tasks helps to update yum package manager, install Apache Server and MySQL respectively

  - name: Yum update

    yum:

      name: '\*'

      state: latest

  - name: install Apache server and mysql

    yum:

      name={{ item }}

      state=present

    loop: ['httpd','mysql']

1. In the next task, PHP is installed and cleaned any residual meta data as reflected below

  #installing php using linux-extra

  - name: Installing PHP

    shell: amazon-linux-extras enable php7.4

  - name: Clean metadata

    shell: yum clean metadata

1. Php extensions are installed as a separate task that leverages terraform loop:

# install php extension

  - name: install php extensions

    yum:

      name={{ item }}

      state=present

    loop: "{{ php\_modules }}"

1. The tasks afterwards are setting up the permissions for files and directories in Apache server so that WordPress can be installed. chmod 2775 is used to set the permissions for the group for directories and subdirectories and chmod 0664 set execution and write conditions.

## Chmod 2775 (chmod a+rwx,o-w,ug+s,+t,u-s,-t) sets permissions so that,

## (U)ser / owner can read, can write and can execute. (G)roup can read,

##can write and can execute. (O)thers can read, can't write and can execute.

  - name: Set permissions for directories

    shell: "/usr/bin/find /var/www/html/ -type d -exec chmod 2775 {} \\;"

## Chmod 0664 (chmod a+rwx,u-x,g-x,o-wx,ug-s,-t) sets permissions so that,

## (U)ser / owner can read, can write and can't execute. (G)roup can read,

## can write and can't execute. (O)thers can read, can't write and can't execute.

  - name: Set permissions for files

    shell: "/usr/bin/find /var/www/html/ -type f -exec chmod 0664 {} \\;"

1. The next task is to install WordPress and copy over the file structure to Apache directory:

 # wordpress download and install

  - name: Wordpress download and unpacking

    unarchive:

      src: https://wordpress.org/latest.tar.gz

      dest: "/var/www"

      remote\_src: yes

  # -r copies files and subdirectories to the destination folder

  - name: Copy wordpress files to /html folder

    shell: cp /var/www/wordpress/. /var/www/html -r

  - name: Delete old wordpress files

    shell: rm /var/www/wordpress -r

1. This is now the time to use Jinja template to update settings for WordPress through wp-config

# using Jinja template to update wp-config

  - name: Set up wp-config

    template:

      src: "files/wp-config.php.j2"

      dest: "/var/www/html/wp-config.php"

1. Once configured, we need to add the current user in ec2-instance to Apache group

## chown NewUser:NewGroup FILE

## user ec2-user is added to group named apache

  - name: set permission (chmod 774)

    shell: chown -R ec2-user:apache /var/www/html

1. Lastly, its time to restart the Apache server

 - name: services started

    service:

      name={{ item }}

      state=restarted

      enabled=True

    loop: ['httpd']
```
## Applying Terraform

1. Now with Terraform and Ansible are set up, it's time to initialize terraform in the directory where all the terraform files, YAML playbook and files folder for Jinja template exists. The directory looks like as follows:

![](RackMultipart20221013-1-vl58sn_html_28bbb6f7271e7964.png)

1. Terraform initialize reflects number of provider plugins installed (AWS, Null, Local and Template)

![](RackMultipart20221013-1-vl58sn_html_62dae546176e5da3.png)

1. With terraform initialized, lets run terraform validate to confirm the configuration is correct.

![](RackMultipart20221013-1-vl58sn_html_67121f747d004744.png)

1. When terraform is successfully validated, we can plan the deployment with the following terraform command. This in turn provides a terraform .tfplan file containing all the details of infrastructure deployment.

![](RackMultipart20221013-1-vl58sn_html_bb413d87f29b258a.png)

1. The way I have configured terraform is that it asks to provide the name of AWS profile name configured on the host machine. In my case, the profile name was named 'personal'
2. When terraform plan is completed, the outcome suggests to apply the output " **mydeployment.tfplan"** to AWS as shown below:

![](RackMultipart20221013-1-vl58sn_html_4a6e3c68bddaf0ed.png)

1. Running terraform apply " **mydeployment.tfplan**" will firstly provision the infrastructure, export the Database Credentials to Ansible and run the Ansible command on the remote machine (ec2-instance) on runtime.
2. The output of the process turns out to be an IP address that is accessible from [https://IP-Address](https://IP-Address/)

# Reference

1. Github: https://github.com/inevitablewish/wordpress-ansible-terraform.git
2. AWS Resources: https://github.com/aws-samples/aws-refarch-wordpress
3. Terraform website: https://www.hashicorp.com/products/terraform
4. Ansible Documentation: https://docs.ansible.com/

Mohsin Abbas Malik Simplilearn-Project
