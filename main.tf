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

resource "aws_security_group" "main" {
  name        = "sample-terraform-security_group"
  description = "Sample Terraform Security Group"
  vpc_id      = aws_vpc.myVPC.id
}

resource "aws_security_group_rule" "ssh" {
  security_group_id = aws_security_group.main.id
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
}

resource "aws_security_group_rule" "icmp" {
  security_group_id = aws_security_group.main.id
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
}

resource "aws_security_group_rule" "http" {
  security_group_id = aws_security_group.main.id
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
}

resource "aws_security_group_rule" "out_all" {
  security_group_id = aws_security_group.main.id
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
}

resource "aws_instance" "sample-terraform" {
  ami           = var.images.ap-northeast-1
  instance_type = "t2.nano"
  vpc_security_group_ids = [
    aws_security_group.main.id
  ]
  subnet_id                   = aws_subnet.public-a.id
  associate_public_ip_address = "true"
  key_name                    = aws_key_pair.sample-terraform.id
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

resource "aws_key_pair" "sample-terraform" {
  key_name   = "sample-terraform"
  public_key = file("./sample-terraform-aws-key.pub")
}

output "public_ip_of_sample-terraform" {
  value = aws_instance.sample-terraform.public_ip
}
