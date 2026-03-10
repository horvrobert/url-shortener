variable "aws_region" {
  default = "eu-central-1"
}

variable "project_name" {
  default = "url-shortener"
}

variable "db_username" {
  description = "Username for the RDS instance"
  type        = string
}

variable "db_password" {
  description = "Password for the RDS instance"
  type        = string
}
