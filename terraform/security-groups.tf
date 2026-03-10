resource "aws_security_group" "sg_rds" {
  name        = "url-shortener-sg"
  description = "Security group for URL shortener"
  vpc_id      = aws_vpc.url-shortener-vpc.id

  tags = {
    Name    = "URL-shortener-RDS-SG"
    Project = "URL-shortener"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_5432_from_sg_app" {
  security_group_id            = aws_security_group.sg_rds.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.sg_app.id
}

resource "aws_vpc_security_group_egress_rule" "allow_egress_rds" {
  security_group_id = aws_security_group.sg_rds.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}


resource "aws_security_group" "sg_app" {
  name        = "url-shortener-app-sg"
  description = "Security group for URL shortener"
  vpc_id      = aws_vpc.url-shortener-vpc.id

  tags = {
    Name    = "URL-shortener-APP-SG"
    Project = "URL-shortener"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_8000_from_sg_alb" {
  security_group_id            = aws_security_group.sg_app.id
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
  referenced_security_group_id = aws_security_group.sg_alb.id
}

resource "aws_vpc_security_group_egress_rule" "allow_egress_app" {
  security_group_id = aws_security_group.sg_app.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "sg_alb" {
  name        = "url-shortener-alb-sg"
  description = "Security group for URL shortener"
  vpc_id      = aws_vpc.url-shortener-vpc.id

  tags = {
    Name    = "URL-shortener-ALB-SG"
    Project = "URL-shortener"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_80_from_internet" {
  security_group_id = aws_security_group.sg_alb.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "allow_443_from_internet" {
  security_group_id = aws_security_group.sg_alb.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "allow_aegress_alb" {
  security_group_id = aws_security_group.sg_alb.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
