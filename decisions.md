## Decision: Use Python with FastAPI to build the app

Why this exists:
- Python can use options such as Flask, Django or Node.js but FastAPI is modern and fast to write

Alternatives considered:
- Python/Django
- Python/Flask
- Node.js

Why Django and Flask rejected:
- Flask is older, more minimal, and lacks built-in validation and automatic docs
- Django is too heavy for a simple API
- Node.js has manual validation

Why FastAPI chosen:
- modern and fast to write
- generates OpenAPI/Swagger UI docs automatically
- built-in data validation via Pydantic

Trade-offs accepted:
- Python is slower than compiled languages like Go, but performance is not a constraint for this use case


## Decision: ECS Fargate over Lambda or EC2

Why this exists:
- ECS to run Docker that will run the app

Alternatives considered:
- Lambda
- EC2

Why Lambda and EC2 rejected:
- Lambda doesn't fit long-running containerized workloads
- EC2 requires managing the underlying servers

Why ECS Fargate chosen:
- Fargate runs containers without managing servers
- scales automatically
- is the standard container platform in CEE job specs

Trade-offs accepted:
- Fargate has higher per-task cost than EC2 at sustained load, but eliminates server management overhead


## Decision: ECS Fargate over EKS

Why this exists:
- Needed a container orchestration platform that doesn't require managing underlying infrastructure

Alternatives considered:
- EKS

Why EKS rejected:
- EKS adds Kubernetes complexity
- EKS adds ~$72/month just for the control plane

Why ECS Fargate chosen:
- Docker simplicity comes first, Kubernetes complexity comes later
- ECS handles scheduling, load balancing, and service discovery out of the box

Trade-offs accepted:
- not learning Kubernetes yet


## Decision: RDS over DynamoDB

Why this exists:
- RDS to store URL mapping

Alternatives considered:
- DynamoDB

Why DynamoDB rejected:
- DynamoDB's value is in scale and flexible schema, neither of which this app needs

Why RDS chosen:
- URL shortener has a simple relational pattern — one table, lookup by code, no variable schema

Trade-offs accepted:
- RDS requires more setup, lives in a VPC, needs subnet groups, and costs more than DynamoDB for a simple lookup table


## Decision: Secrets Manager over environment variables for RDS credentials

Why this exists:
- The RDS credentials need to be stored securely

Alternatives considered:
- Environment variables

Why environment variables rejected:
- Environment variables are not secure — they can be exposed in logs or code

Why Secrets Manager chosen:
- Provides fine-grained IAM access control and integrates with RDS natively
- ECS task retrieves credentials at runtime via the AWS SDK

Trade-offs accepted:
- Costs $0.40/month per secret plus $0.05 per 10,000 API calls — acceptable for proper credential management
- Credentials passed via TF_VAR environment variables, never stored in terraform.tfvars


## Decision: RDS in private subnet, no public accessibility

Why this exists:
- Databases must not be internet-accessible

Why private subnet chosen:
- The private subnet has no IGW route, so even if publicly_accessible were true, no route exists
- Defence in depth — both the subnet and the RDS flag enforce isolation

Why public subnet rejected:
- No legitimate reason to expose a database to internet-routable traffic

Why Multi-AZ rejected:
- A DB subnet group requires two AZs for RDS to launch — a second private subnet was added to satisfy this requirement, not for high availability

Trade-offs accepted:
- RDS requires more setup, lives in a VPC, needs subnet groups, and costs more than DynamoDB for a simple lookup table


## Decision: VPC endpoints over NAT Gateway or public subnet

Why this exists:
- ECS tasks in private subnets have no route to ECR, Secrets Manager, or CloudWatch Logs

Alternatives considered:
- Move ECS tasks to public subnet with assign_public_ip = true
- NAT Gateway
- VPC endpoints

Why public subnet rejected:
- ECS tasks become publicly addressable — not production-correct

Why NAT Gateway rejected:
- For this project the goal was demonstrating private subnet isolation with traffic staying entirely within the AWS network
- NAT Gateway still routes outbound traffic over the public internet — VPC endpoints keep traffic on the AWS backbone
- For a URL shortener specifically, payloads are tiny so NAT Gateway data transfer costs would be negligible — the cost argument actually favours NAT Gateway for this workload

Why VPC endpoints chosen:
- Portfolio goal: demonstrate production-correct private subnet isolation
- Traffic to ECR, Secrets Manager, CloudWatch, and S3 stays within the AWS network with no internet path
- Architecturally correct for high data transfer workloads where endpoint costs are justified by traffic volume

Trade-offs accepted:
- 5 endpoints at ~€0.90-0.95/day each = ~€135-140/month at sustained run
- For this specific workload NAT Gateway would likely be cheaper — data transfer costs would be negligible
- VPC endpoints make economic sense when traffic volume is high enough to justify the fixed cost over NAT Gateway per-GB charges
- Accepted the higher cost for portfolio correctness


