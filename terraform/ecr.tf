resource "aws_ecr_repository" "app" {
  name                 = var.project_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name      = "URL-Shortener-App-Repository"
    Project   = "URL-shortener"
    ManagedBy = "Terraform"
  }
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}
