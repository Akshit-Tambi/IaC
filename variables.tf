variable "aws_region" {
  description = "AWS region"
  default     = "ap-south-1"
}

variable "aws_profile" {
  description = "AWS profile"
  default     = "akshit_tambi"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  default     = "192.168.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  default     = "192.168.0.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnet"
  default     = "192.168.1.0/24"
}

variable "instance_ami" {
  description = "AMI ID for EC2 instances"
  default     = "ami-08bf489a05e916bbd"
}

variable "instance_type" {
  description = "Instance type for EC2 instances"
  default     = "t2.micro"
}

variable "ssh_public_key_path" {
  description = "Path to public key file"
  default     = "C:/Users/htamb/.ssh/id_rsa.pub"
}

variable "ssh_private_key_path" {
  description = "Path to private key file"
  default     = "C:/Users/htamb/.ssh/id_rsa"
}