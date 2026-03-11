resource "aws_secretsmanager_secret" "db_credentials" {
  name = "url-shortener-db-credentials-02"
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = aws_db_instance.url-shortener-db.address
    port     = aws_db_instance.url-shortener-db.port
    dbname   = "urlshortnerdb01"
  })
}
