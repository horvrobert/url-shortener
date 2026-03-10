# URL Shortener

A URL shortening REST API built with FastAPI, containerized with Docker, 
deployed on AWS ECS Fargate with RDS PostgreSQL.

## Architecture
- FastAPI (Python) — REST API
- Docker + ECR — containerization
- ECS Fargate — container orchestration
- RDS PostgreSQL — database (private subnet)
- Secrets Manager — credential management
- ALB — load balancing
- Terraform — infrastructure as code
- GitHub Actions — CI/CD pipeline

## Local Development (Sprint 1)

- FastAPI app with two endpoints: POST /shorten and GET /{code}
- Dockerized with multi-stage Dockerfile
- Docker Compose for local development with PostgreSQL
- Data persistence via Docker volumes

### Prerequisites
- Python 3.12+
- Docker Desktop

### Run locally
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload
```

API docs available at http://localhost:8000/docs

## Infrastructure (Sprint 2)

Provisioned via Terraform:
- VPC with public and private subnets across two availability zones
- ECR repository for Docker image storage
- RDS PostgreSQL in private subnets — no public access
- Secrets Manager storing database credentials as JSON
- Security groups for ALB, ECS app, and RDS with least-privilege rules


## Project Status
🚧 In progress — Sprint 2 of 6