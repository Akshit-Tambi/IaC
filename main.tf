provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

# Key Pair
resource "aws_key_pair" "test" {
  key_name   = "terraform-vpc"
  public_key = file(var.ssh_public_key_path)
}

# VPC
resource "aws_vpc" "main_vpc" {    
  cidr_block = var.vpc_cidr
  instance_tenancy = "default"
  tags = {
    Name = "Test-vpc"
    Management = "Terraform"
  }
}

# Subnets
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = {
    Name = "subnet_pub"
  }
}

resource "aws_subnet" "subnet2" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = "${var.aws_region}b"
  tags = {
    Name = "subnet_pri"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id
}

# Route Tables
resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "asso" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.RT.id
}

# NAT Gateway
resource "aws_eip" "lb" {
  depends_on = [aws_internet_gateway.igw]
  domain     = "vpc"
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.lb.id
  subnet_id     = aws_subnet.subnet1.id
  depends_on    = [aws_internet_gateway.igw]
  tags = {
    Name = "NAT gw"
  }
}

resource "aws_route_table" "routenat" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.natgw.id
  }

  tags = {
    Name = "route_table_nat"
  }
}

resource "aws_route_table_association" "assonat" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.routenat.id
}

# Security Groups
resource "aws_security_group" "sg1" {
  name        = "sg1"
  description = "Allow MySQL inbound traffic"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description = "MySQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }  
 
  ingress {
    description = "MySQL Alternative"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }    
    
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mysqlhttp"
  }
}

resource "aws_security_group" "wp1" {
  name        = "wp1"
  description = "Allow WordPress inbound traffic"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description = "WordPress"
    from_port   = 8000
    to_port     = 8000
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

  tags = {
    Name = "wphttp"
  }
}

# EC2 Instances
resource "aws_instance" "mysql" {
  ami               = var.instance_ami
  instance_type     = var.instance_type
  availability_zone = "${var.aws_region}b"
  subnet_id         = aws_subnet.subnet2.id
  key_name          = aws_key_pair.test.key_name
  vpc_security_group_ids = [aws_security_group.sg1.id]
  
  user_data = <<-EOF
    #!/bin/bash
    sudo yum install docker -y
    sudo service docker start
    sudo docker pull mysql:5.7
    sudo docker run -dit -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=data -e MYSQL_USER=akshit -e MYSQL_PASSWORD=root -p 8080:3306 --name dbos mysql:5.7
  EOF
  
  tags = {
    Name = "mysql1"
  }
}

resource "aws_instance" "wordpress" {
  ami               = var.instance_ami
  instance_type     = var.instance_type
  availability_zone = "${var.aws_region}a"
  subnet_id         = aws_subnet.subnet1.id
  key_name          = aws_key_pair.test.key_name
  vpc_security_group_ids = [aws_security_group.wp1.id]
  
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file(var.ssh_private_key_path)
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install docker -y",
      "sudo service docker start",
      "sudo docker pull wordpress:5.1.1-php7.3-apache",
      "sudo docker run -dit -e WORDPRESS_DB_HOST=${aws_instance.mysql.private_ip}:8080 -e WORDPRESS_DB_USER=akshit -e WORDPRESS_DB_PASSWORD=root -e WORDPRESS_DB_NAME=data -p 8000:80 --name mywp wordpress:5.1.1-php7.3-apache"
    ]
  }

  tags = {
    Name = "wordpress1"
  }
}