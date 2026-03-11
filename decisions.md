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

## RDS Credentials: AWS Secrets Manager over Environment variables for credentials

Why this exists:

- The RDS credentials need to be stored securely

Alternatives considered:

- Environment variables

Why environment variables rejected:

- The environment variables are not secure, they can be exposed in the code

Why AWS Secrets Manager chosen:

- AWS Secrets Manager provides fine-grained IAM access control, and integrates with RDS natively
- The ECS task retrieves credentials at runtime via the AWS SDK

Trade-offs accepted:

- AWS Secrets Manager costs $0.40/month per secret plus $0.05 per 10,000 API calls — acceptable cost for proper credential management
- In production, credentials would be passed via TF_VAR environment variables, not stored in terraform.tfvars

## RDS: Private Subnet, No Public Accessibility

Why this exists:

- Databases must not be internet-accessible

Why RDS in the private subnet chosen:

- Databases must not be internet-accessible
- The private subnet has no IGW route, so even if `publicly_accessible` were true, no route exists. Defence in depth — both the subnet and the RDS flag enforce isolation.

Why RDS in the public subnet rejected:

- No legitimate reason to expose a database to internet-routable traffic

Why RDS Multi-AZ rejected:

- A DB subnet group still requires two AZs for RDS to launch; a second private subnet in a different AZ was added to satisfy this requirement.

Trade-offs accepted:

- RDS requires more setup, lives in a VPC, needs subnet groups, and costs more than DynamoDB for a simple lookup table  


## Decision: VPC endpoints over Public subnet

Why this exists:
- ECS task is unable to pull an image from ECR because ECS task is in a private subnet

Alternatives considered:
- Public subnet
- VPC endpoint

Why Public subnet rejected:
- ECS task would become publicly accessible making them vulnerable to threats

Why VPC endpoint chosen:
- ECS task stays in Private subnet
- Production-correct approach

Trade-offs accepted:
- Additional configuration
- VPC endpoints are not free, they come with billing roughly €0.90-0.95 per endpoint per day
