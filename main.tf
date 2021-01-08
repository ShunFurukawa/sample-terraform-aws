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
  vpc_id                  = aws_vpc.myVPC.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "sample-terraform-ap-northeast-1a-public-subnet"
  }
}

resource "aws_subnet" "public-c" {
  vpc_id            = aws_vpc.myVPC.id
  cidr_block        = "10.1.2.0/24"
  availability_zone = "ap-northeast-1c"
  tags = {
    Name = "sample-terraform-ap-northeast-1c-public-subnet"
  }
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

resource "aws_security_group_rule" "https" {
  security_group_id = aws_security_group.main.id
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 443
  to_port           = 443
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
  subnet_id = aws_subnet.public-a.id
  key_name  = aws_key_pair.sample-terraform.id
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

resource "aws_lb" "main" {
  load_balancer_type = "application"
  name               = "sample-terraform-balancer"
  security_groups    = [aws_security_group.main.id]
  subnets            = [aws_subnet.public-a.id, aws_subnet.public-c.id]
}

resource "aws_lb_listener" "http" {
  port              = "80"
  protocol          = "HTTP"
  load_balancer_arn = aws_lb.main.arn
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code  = "200"
      message_body = "ok"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  certificate_arn   = aws_acm_certificate.main.arn
  port              = "443"
  protocol          = "HTTPS"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.id
  }
}

resource "aws_lb_target_group" "main" {
  name     = "sample-terraform-lb-target-group"
  vpc_id   = aws_vpc.myVPC.id
  port     = 80
  protocol = "HTTP"
  health_check {
    port = 80
    path = "/"
  }
}

resource "aws_lb_listener_rule" "main" {
  listener_arn = aws_lb_listener.http.arn
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.id
  }
  condition {
    path_pattern {
      values = ["*"]
    }
  }
}

resource "aws_lb_target_group_attachment" "main" {
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = aws_instance.sample-terraform.id
  port             = 80
}

resource "aws_route53_zone" "main" {
  name = var.domain
}

resource "aws_acm_certificate" "main" {
  domain_name               = var.domain
  subject_alternative_names = ["*.${var.domain}"]
  validation_method         = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  depends_on      = [aws_acm_certificate.main]
  zone_id         = aws_route53_zone.main.id
  ttl             = 60
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}

resource "aws_route53_record" "main" {
  type    = "A"
  name    = var.domain
  zone_id = aws_route53_zone.main.id
  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

output "public_ip_of_sample-terraform" {
  value = aws_instance.sample-terraform.public_ip
}
