resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.url-shortener-vpc.id

  tags = {
    Name      = "URL-shortener-IGW"
    Project   = "URL-shortener"
    ManagedBy = "Terraform"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.url-shortener-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name      = "URL-shortener-Public-RT"
    Project   = "URL-shortener"
    ManagedBy = "Terraform"
  }
}

resource "aws_route_table_association" "public_subnets" {
  for_each = {
    public_1 = aws_subnet.public_1.id
    public_2 = aws_subnet.public_2.id
  }

  subnet_id      = each.value
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.url-shortener-vpc.id

  tags = {
    Name      = "URL-shortener-Private-RT"
    Project   = "URL-shortener"
    ManagedBy = "Terraform"
  }
}

resource "aws_route_table_association" "private_subnets" {
  for_each = {
    private_1 = aws_subnet.private_1.id
    private_2 = aws_subnet.private_2.id
  }

  subnet_id      = each.value
  route_table_id = aws_route_table.private_rt.id
}