resource "aws_db_instance" "url-shortener-db" {
  identifier             = "url-shortener-db"
  db_name                = "urlshortnerdb01"
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  parameter_group_name   = "default.postgres15"
  skip_final_snapshot    = true
  deletion_protection    = false
  db_subnet_group_name   = aws_db_subnet_group.url-shortener-db-subnet-group.name
  publicly_accessible    = false
  storage_encrypted      = true
  username               = var.db_username
  password               = var.db_password
  vpc_security_group_ids = [aws_security_group.sg_rds.id]

  tags = {
    Name      = "URL-shortener-DB"
    Project   = "URL-shortener"
    ManagedBy = "Terraform"
  }
}

resource "aws_db_subnet_group" "url-shortener-db-subnet-group" {
  name        = "url-shortener-db-subnet-group"
  description = "DB subnet group for RDS in private subnets"
  subnet_ids  = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name      = "URL-shortener-DB-Subnet-Group"
    Project   = "URL-shortener"
    ManagedBy = "Terraform"
  }
}