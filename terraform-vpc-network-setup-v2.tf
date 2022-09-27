#############################################################################################################
# Author: Upinder Sujlana                                                                                   #
# Version: v1.0.1                                                                                           #
# Date: 09/26/2022                                                                                          #
# Description: This demo TF file will create all VPC networking related objects & than create               #
#              2 EC2 instances as demo in public and private subnet. The TF file is intentinally verbose    #
#              to capture all elements steps with links for posterity                                       #
# Usage: terraform plan   , terraform apply  , terraform destroy                                            #
#############################################################################################################
terraform {
  # Below in required_providers block specify all the providers and their attributes
  required_providers {
    aws = {
      # Which provider your want to download
      source = "hashicorp/aws"
      # What version of the provider plugin you want
      version = "~> 3.40.0"
    }
  }
  # What version of terraform we want to use
  required_version = "~> 0.15.1"
}
#----------------------------------------------------------------------------
# What is the Region of AWS this infrastruture shall be created in.
provider "aws" {
  region = "us-west-2"
}
#----------------------------------------------------------------------------
# Create a VPC - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc
resource "aws_vpc" "vpc1" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "vpc1"
  }
}
#----------------------------------------------------------------------------
# Create 2 Subnets (publicsubnet, privatesubnet) - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet
# Note below the vpc_id should have the vpc1 ID

resource "aws_subnet" "publicsubnet" {
  vpc_id     = aws_vpc.vpc1.id
  cidr_block = "10.0.1.0/24"

  # configure subnet to give out public IP to EC2 that come up in this subnet
  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet
  map_public_ip_on_launch = true

  tags = {
    Name = "publicsubnet"
  }
}

resource "aws_subnet" "privatesubnet" {
  vpc_id     = aws_vpc.vpc1.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "privatesubnet"
  }
}
#----------------------------------------------------------------------------
# Create a internet gateway & attach to vpc1 - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc1.id

  tags = {
    Name = "igw"
  }
}
#----------------------------------------------------------------------------
#Create a Security group for the EC2 that shall allow SSH, HTTP & HTTPS
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
# https://medium.com/swlh/making-terraform-work-a-bit-harder-da3d05fd7c38
variable "sg_ports" {
  type        = list(number)
  description = "list of ingress ports"
  default     = [22, 80, 443]
}
resource "aws_security_group" "vpc1-security-group" {
  name        = "vpc1-security-group"
  description = "vpc1-security-group"
  vpc_id      = aws_vpc.vpc1.id

  tags = {
    Name = "vpc1-security-group"
  }

  dynamic "ingress" {
    for_each = var.sg_ports
    iterator = port
    content {
      from_port   = port.value
      to_port     = port.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  dynamic "egress" {
    for_each = var.sg_ports
    iterator = port
    content {
      from_port   = port.value
      to_port     = port.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

#----------------------------------------------------------------------------
#Create a NACL and associate it to both the public and private subnet
resource "aws_network_acl" "NACL_for_both_subnet" {
  vpc_id     = aws_vpc.vpc1.id
  subnet_ids = [aws_subnet.publicsubnet.id, aws_subnet.privatesubnet.id]
  tags = {
    Name = "NACL_for_both_subnet"
  }
}

# Allow inbound and outbound ssh port traffic
resource "aws_network_acl_rule" "ssh-ingress" {
  network_acl_id = aws_network_acl.NACL_for_both_subnet.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 22
  to_port        = 22
}
resource "aws_network_acl_rule" "ssh-egress" {
  network_acl_id = aws_network_acl.NACL_for_both_subnet.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 22
  to_port        = 22
}

# Allow inbound and outbound http port traffic
resource "aws_network_acl_rule" "http-ingress" {
  network_acl_id = aws_network_acl.NACL_for_both_subnet.id
  rule_number    = 200
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}
resource "aws_network_acl_rule" "http-egress" {
  network_acl_id = aws_network_acl.NACL_for_both_subnet.id
  rule_number    = 200
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

# Allow inbound and outbound https port traffic
resource "aws_network_acl_rule" "https-ingress" {
  network_acl_id = aws_network_acl.NACL_for_both_subnet.id
  rule_number    = 300
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}
resource "aws_network_acl_rule" "https-egress" {
  network_acl_id = aws_network_acl.NACL_for_both_subnet.id
  rule_number    = 300
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

#Allow inbound & outbound ephemeral  traffic
# https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html#VPC_ACLs_Ephemeral_Ports
resource "aws_network_acl_rule" "ephemeral-ingress" {
  network_acl_id = aws_network_acl.NACL_for_both_subnet.id
  rule_number    = 400
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}
resource "aws_network_acl_rule" "ephemeral-egress" {
  network_acl_id = aws_network_acl.NACL_for_both_subnet.id
  rule_number    = 400
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}
#----------------------------------------------------------------------------
# Create a public & private routing table - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table

resource "aws_route_table" "PublicRT" {
  vpc_id = aws_vpc.vpc1.id

  route {
    # For public subnet all external traffic send to IGW
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "PublicRT"
  }

}

resource "aws_route_table" "PrivateRT" {
  vpc_id = aws_vpc.vpc1.id

  route {
    # For private subnet all external traffic send to the nat gateway (look below for the code for the creation)
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.natgw.id
  }

  tags = {
    Name = "PrivateRT"
  }

}
#----------------------------------------------------------------------------
# Make route table association - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association

# Essentially associate the public subnet to the public route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.publicsubnet.id
  route_table_id = aws_route_table.PublicRT.id
}

# Essentially associate the private subnet to the private route table
resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.privatesubnet.id
  route_table_id = aws_route_table.PrivateRT.id
}

#----------------------------------------------------------------------------
#Add a elastic IP to be used by nat gateway later on - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip

resource "aws_eip" "nateip" {
  vpc = true
}
#----------------------------------------------------------------------------
# Add NAT Gateway (for private subnet) and add it to the public subnet so it can reach the internet via gateway
# it will need the public subnet id and also a elastic ip we created previosly
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway

resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.nateip.id
  subnet_id     = aws_subnet.publicsubnet.id

  tags = {
    Name = "natgw"
  }

}
#----------------------------------------------------------------------------
# Test - Create 2 EC2 instances , 1 each in the public & private subnet
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance

# Got the AMI ID "ami-0c2ab3b8efb09f272" from EC2 directly

resource "aws_instance" "web" {
  ami                    = "ami-0c2ab3b8efb09f272"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.vpc1-security-group.id]

  #put this in the public subnet - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance
  subnet_id = aws_subnet.publicsubnet.id

  # SSH keys to use - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance
  key_name = "terraform-key-pair"

  tags = {
    Name = "webserver"
  }
}


resource "aws_instance" "dbserver" {
  ami                    = "ami-0c2ab3b8efb09f272"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.vpc1-security-group.id]

  #put this in the private subnet  - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance
  subnet_id = aws_subnet.privatesubnet.id

  # SSH keys to use - https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance
  key_name = "terraform-key-pair"

  tags = {
    Name = "dbserver"
  }
}

#----------------------------------------------------------------------------
