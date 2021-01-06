resource "aws_vpc" "myVPC" {
  cidr_block           = "10.1.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "false"
  tags = {
    Name = "myVPC"
  }
}

resource "aws_internet_gateway" "myGW" {
  vpc_id     = aws_vpc.myVPC.id
  depends_on = [aws_vpc.myVPC]
}

resource "aws_subnet" "public-a" {
  vpc_id            = aws_vpc.myVPC.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "ap-northeast-1a"
}

resource "aws_route_table" "public-route" {
  vpc_id = aws_vpc.myVPC.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myGW.id
  }
}

resource "aws_route_table_association" "public-a" {
  subnet_id      = aws_subnet.public-a.id
  route_table_id = aws_route_table.public-route.id
}

resource "aws_security_group" "admin" {
  name        = "admin"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.myVPC.id
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
}

resource "aws_instance" "sample-terraform" {
  ami           = var.images.ap-northeast-1
  instance_type = "t2.nano"
  vpc_security_group_ids = [
    aws_security_group.admin.id
  ]
  subnet_id                   = aws_subnet.public-a.id
  associate_public_ip_address = "true"
  root_block_device {
    volume_type = "gp2"
    volume_size = "20"
  }
  ebs_block_device {
    device_name = "/dev/sdf"
    volume_type = "gp2"
    volume_size = "100"
  }
  tags = {
    Name = "sample-terraform"
  }
}

output "public_ip_of_sample-terraform" {
  value = aws_instance.sample-terraform.public_ip
}
