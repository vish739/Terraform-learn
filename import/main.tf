resource "aws_vpc" "vishal" {
  cidr_block = "10.0.0.0/24"

  tags = {
    Name = "vishal-vpc"
  }
}

resource "aws_subnet" "vishal" {
  vpc_id            = aws_vpc.vishal.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "ap-southeast-2a"

  tags = {
    Name = "vishal-subnet-01"
  }
}

resource "aws_route_table" "vishal" {
  vpc_id = aws_vpc.vishal.id

  tags = {
    Name = "vishal-route"
  }
}

resource "aws_security_group" "web" {
  name        = "launch-wizard-1"
  description = "launch-wizard-1 created 2026-11-21T17:37:53.634Z"

  vpc_id = "vpc-000f63a6d4be992e9"

  ingress {
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

  tags = {}
}

resource "aws_instance" "web" {
  ami           = "ami-0331e43da0c1f186e"
  instance_type = "t3.micro"

  tags = {
    Name = "vishal-ec2"
  }
}