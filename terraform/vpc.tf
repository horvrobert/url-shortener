resource "aws_vpc" "url-shortener-vpc" {
  cidr_block           = "192.168.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name      = "URL-shortener-VPC"
    Project   = "URL-shortener"
    ManagedBy = "Terraform"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.url-shortener-vpc.id
  cidr_block              = "192.168.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name      = "Public-1"
    Project   = "URL-shortener"
    ManagedBy = "Terraform"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.url-shortener-vpc.id
  cidr_block              = "192.168.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name      = "Public-2"
    Project   = "URL-shortener"
    ManagedBy = "Terraform"
  }
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.url-shortener-vpc.id
  cidr_block        = "192.168.11.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name      = "Private-1"
    Project   = "URL-shortener"
    ManagedBy = "Terraform"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.url-shortener-vpc.id
  cidr_block        = "192.168.12.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name      = "Private-2"
    Project   = "URL-shortener"
    ManagedBy = "Terraform"
  }
}