
resource "aws_vpc_endpoint" "ecr_api_endpoint" {
  vpc_id              = aws_vpc.url-shortener-vpc.id
  service_name        = "com.amazonaws.eu-central-1.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  security_group_ids  = [aws_security_group.sg_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name      = "URL-Shortener-ECR-API-Endpoint"
    Project   = "URL-shortener"
    ManagedBy = "Terraform"
  }
}

resource "aws_vpc_endpoint" "ecr_dkr_endpoint" {
  vpc_id              = aws_vpc.url-shortener-vpc.id
  service_name        = "com.amazonaws.eu-central-1.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  security_group_ids  = [aws_security_group.sg_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name      = "URL-Shortener-ECR-DKR-Endpoint"
    Project   = "URL-shortener"
    ManagedBy = "Terraform"
  }
}

resource "aws_vpc_endpoint" "secretsmanager_endpoint" {
  vpc_id              = aws_vpc.url-shortener-vpc.id
  service_name        = "com.amazonaws.eu-central-1.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  security_group_ids  = [aws_security_group.sg_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name      = "URL-Shortener-Secrets-Manager-Endpoint"
    Project   = "URL-shortener"
    ManagedBy = "Terraform"
  }
}

resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id            = aws_vpc.url-shortener-vpc.id
  service_name      = "com.amazonaws.eu-central-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_rt.id]

  tags = {
    Name      = "URL-Shortener-S3-Endpoint"
    Project   = "URL-shortener"
    ManagedBy = "Terraform"
  }
}

resource "aws_security_group" "sg_endpoints" {
  name        = "url-shortener-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.url-shortener-vpc.id

  tags = {
    Name    = "URL-shortener-endpoints-SG"
    Project   = "URL-shortener"
    ManagedBy = "Terraform"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_443_from_vpc" {
  security_group_id = aws_security_group.sg_endpoints.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "192.168.0.0/16"

  tags = {
    Name      = "Allow-HTTPS-From-VPC"
    Project   = "URL-shortener"
    ManagedBy = "Terraform"
  }
}

resource "aws_vpc_security_group_egress_rule" "allow_all_outbound" {
  security_group_id = aws_security_group.sg_endpoints.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name      = "Allow-All-Outbound"
    Project   = "URL-shortener"
    ManagedBy = "Terraform"
  }
}

resource "aws_vpc_endpoint" "logs_endpoint" {
  vpc_id              = aws_vpc.url-shortener-vpc.id
  service_name        = "com.amazonaws.eu-central-1.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  security_group_ids  = [aws_security_group.sg_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name      = "URL-Shortener-Logs-Endpoint"
    Project   = "URL-shortener"
    ManagedBy = "Terraform"
  }
}
