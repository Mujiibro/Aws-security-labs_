terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

# VPC
resource "aws_vpc" "lab_vpc" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "terraform-lab-vpc" }
}

# Restrict default security group — CKV2_AWS_12
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.lab_vpc.id
  tags   = { Name = "restricted-default-sg" }
}

# VPC Flow Logs — CKV2_AWS_11
resource "aws_flow_log" "vpc_flow" {
  vpc_id          = aws_vpc.lab_vpc.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_log_role.arn
  log_destination = aws_cloudwatch_log_group.flow_log.arn
}

# KMS Key for CloudWatch encryption — CKV_AWS_158
resource "aws_kms_key" "log_key" {
  description             = "KMS key for CloudWatch flow logs"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::881415010165:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
  tags = { Name = "terraform-log-kms-key" }
}

# CloudWatch Log Group — 365 day retention — CKV_AWS_338
resource "aws_cloudwatch_log_group" "flow_log" {
  name              = "/vpc/terraform-lab-flowlogs"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.log_key.arn
}

# IAM Role for Flow Logs
resource "aws_iam_role" "flow_log_role" {
  name = "terraform-flow-log-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })
}

# IAM Policy — scoped to specific log group — CKV_AWS_355
resource "aws_iam_role_policy" "flow_log_policy" {
  name = "flow-log-policy"
  role = aws_iam_role.flow_log_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "arn:aws:logs:ap-south-1:881415010165:log-group:/vpc/terraform-lab-flowlogs:*"
    }]
  })
}

# Public Subnet — no auto public IP — CKV_AWS_130
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = "10.1.10.0/24"
  map_public_ip_on_launch = false
  tags = { Name = "terraform-public-subnet" }
}

# Private Subnet
resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.lab_vpc.id
  cidr_block = "10.1.20.0/24"
  tags = { Name = "terraform-private-subnet" }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.lab_vpc.id
  tags   = { Name = "terraform-igw" }
}

# Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.lab_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "terraform-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# Hardened Security Group — CKV_AWS_24, CKV_AWS_382, CKV_AWS_23
resource "aws_security_group" "bastion" {
  name        = "terraform-bastion-sg"
  description = "Bastion host security group - SSH restricted to trusted IP"
  vpc_id      = aws_vpc.lab_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["39.57.35.111/32"]
    description = "SSH from trusted IP only"
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound only"
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP outbound only"
  }

  tags = { Name = "terraform-bastion-sg" }
}

# IAM Role for EC2 — CKV2_AWS_41
resource "aws_iam_role" "ec2_role" {
  name = "terraform-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "terraform-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# Latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Hardened Bastion EC2 — CKV2_AWS_5, CKV_AWS_126
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  monitoring             = true
  ebs_optimized          = false

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = { Name = "terraform-bastion-host" }
}
