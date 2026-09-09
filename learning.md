## Sprint 1 - FastAPI app, running locally, two endpoints

### Sprint 1, Phase 1

- Using Python build a tiny web server running locally, listening for HTTP requests on port 8000 and responding to them
- Pydentic validates incoming request data automatically
- Create virtual environment, activate it, install FastAPI, uvicorn, psycopg2-binary, freeze requirements.txt
- Write main.py with two endpoints — POST /shorten and GET /{code}
- main.py uses in-memory dict 'db = {}' as fake database - data dies on restart
- Run it with uvicorn main:app --reload
- Hit both endpoints in your browser or Postman and confirm they work

    1. Install virtual environment
        cd url-shortener
        python3 -m venv venv
        source venv/bin/activate
        pip install fastapi uvicorn psycopg2-binary
        pip freeze > requirements.txt

    2. Create main.py

        ```python
        # Imports the FastAPI framework. This is what turns your Python file into a web server
        from fastapi import FastAPI   

        # Handles data validation
        # When someone sends a request to your API, Pydantic checks that the data is in the right format before your code touches it.
        from pydantic import BaseModel 

        import random                       
        import string                      

        # Creates your web server instance
        app = FastAPI()                     

        # A Python dictionary acting as a fake database
        # Keys are short codes, values are long URLs
        # Lives in memory — dies when you restart the server
        # Temporary for Phase 1
        db = {}

        # Defines what a valid request body looks like
        # When someone calls POST /shorten, FastAPI expects a JSON body with a long_url field that's a string
        # If it's missing or wrong type, FastAPI rejects it automatically
        class URLRequest(BaseModel):
            long_url: str

        # Generates a random 6-character code like aB3xZ9
        # This becomes the short code for the URL
        def generate_code():
            return ''.join(random.choices(string.ascii_letters + string.digits, k=6))

        # This is your first endpoint 
        # When someone sends a POST request to /shorten with a long URL, it generates a short code
        # and stores the mapping in the dictionary, then returns the short code back.
        @app.post("/shorten")
        def shorten_url(request: URLRequest):
            code = generate_code()
            db[code] = request.long_url
            return {"short_code": code, "long_url": request.long_url}

        # This is your second endpoint. 
        # When someone visits /aB3xZ9, it looks up that code in the dictionary 
        # and returns the original long URL. 
        # If the code doesn't exist, it returns an error.
        @app.get("/{code}")
        def redirect_url(code: str):
            if code not in db:
                return {"error": "Code not found"}
            return {"long_url": db[code]}
        
    3. Run it to start the web sever locally

        uvicorn main:app --reload

        - Uvicorn is the thing that actually listens on port 8000 and handles incoming HTTP connections
        - --reload means it automatically restarts whenever you save changes to the code, so no manual restart during  development

    4. Test it
        Open your browser and go to <http://localhost:8000/docs> — FastAPI generates a Swagger UI automatically.
        Use it to test both endpoints.

        curl -X POST <http://localhost:8000/shorten> -H "Content-Type: application/json" -d '{"long_url": "<https://www.google.com"}>'

### Sprint 1 - Phase 2: Docker

- Dockerfile packages the app and its dependencies into an image
- FROM python:3.12-slim — slim base image keeps size down
- COPY requirements.txt before COPY . . — layer caching, only reinstalls packages when requirements change
- EXPOSE is documentation only — actual port mapping is -p 8000:8000 at runtime
- docker compose up starts multiple containers together — app + database

```bash
        # Build the image
        docker build -t url-shortener .

        # Run the container
        docker run -p 8000:8000 url-shortener

        # Start both containers (app + PostgreSQL)
        docker compose up --build

        # Stop containers
        docker compose down

        # Check container logs
        docker compose logs app
```

## Sprint 2: AWS Infrastructure

- Security groups are stateful firewalls — reference other security groups as sources, not IP ranges, for internal traffic
- RDS in private subnet means no IGW route exists — defence in depth
- Secrets Manager stores credentials as JSON, retrieved at runtime via AWS SDK
- Never commit *.tfstate or terraform.tfvars — add to .gitignore before first commit
- Pass credentials via TF_VAR_db_password=value terraform apply in production — never store in files

## Sprint 3 - main.py update

- boto3 is the AWS SDK for Python
- App checks for DB_SECRET_ARN env var — if present, calls Secrets Manager and builds connection string from JSON secret
- Falls back to DATABASE_URL if no ARN — local Docker Compose still works unchanged

    1. Install boto3

        ```bash
        source venv/bin/activate
        pip install boto3
        pip freeze > requirements.txt
        ```

    2. Update main.py with boto3

        - The app now checks for DB_SECRET_ARN environment variable first
        - If it exists, it calls Secrets Manager and builds the connection string from the secret
        - If not, it falls back to DATABASE_URL — so local Docker Compose still works unchanged.
        - In ECS you'll pass DB_SECRET_ARN as an environment variable in the task definition. Locally nothing changes.

        ```python
        from fastapi import FastAPI, HTTPException
        from pydantic import BaseModel
        from sqlalchemy import create_engine, text
        import random
        import string
        import os
        import boto3
        import json

        app = FastAPI()

        def get_db_url():
            secret_arn = os.getenv("DB_SECRET_ARN")
            
            if secret_arn:
                client = boto3.client("secretsmanager", region_name="eu-central-1")
                secret = client.get_secret_value(SecretId=secret_arn)
                creds = json.loads(secret["SecretString"])
                return f"postgresql://{creds['username']}:{creds['password']}@{creds['host']}:{creds['port']}/{creds['dbname']}"
            
            return os.getenv("DATABASE_URL")

        engine = create_engine(get_db_url())

        def init_db():
            with engine.connect() as conn:
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS urls (
                        id SERIAL PRIMARY KEY,
                        short_code VARCHAR(10) UNIQUE NOT NULL,
                        long_url TEXT NOT NULL,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                """))
                conn.commit()

        @app.on_event("startup")
        def startup():
            init_db()

        class URLRequest(BaseModel):
            long_url: str

        def generate_code():
            return ''.join(random.choices(string.ascii_letters + string.digits, k=6))

        @app.post("/shorten")
        def shorten_url(request: URLRequest):
            code = generate_code()
            with engine.connect() as conn:
                conn.execute(text(
                    "INSERT INTO urls (short_code, long_url) VALUES (:code, :url)"
                ), {"code": code, "url": request.long_url})
                conn.commit()
            return {"short_code": code, "long_url": request.long_url}

        @app.get("/{code}")
        def redirect_url(code: str):
            with engine.connect() as conn:
                result = conn.execute(text(
                    "SELECT long_url FROM urls WHERE short_code = :code"
                ), {"code": code})
                row = result.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="Code not found")
            return {"long_url": row[0]}
        ```

    3. Run docker locally and test the fallback to DATABASE_URL

        ```console
            docker compose up --build
        ```

       - POST /shorten — confirms the app starts correctly, connects to PostgreSQL, and inserts a record.
       - GET /{code} — confirms the app reads from PostgreSQL correctly.
       - Why test now — you changed main.py to add the Secrets Manager logic
       - You need to confirm the fallback to DATABASE_URL still works locally before deploying to AWS
       - If it's broken locally, it'll definitely be broken in ECS.

    4. Push the updated docker image to ECR [boto3 pulls a lot of dependencies so the image size iz over 700MB]
```bash
                docker build -t url-shortener .
                docker tag url-shortener:latest 373270679710.dkr.ecr.eu-central-1.amazonaws.com/url-shortener:latest
                docker push 373270679710.dkr.ecr.eu-central-1.amazonaws.com/url-shortener:latest
```
    - reauthenticate if needed
    ```bash
    aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin 373270679710.dkr.ecr.eu-central-1.amazonaws.com
    ```





You need three VPC endpoints in vpc.tf or a new endpoints.tf:
Interface endpoints (these need a security group and subnet association):

com.amazonaws.eu-central-1.ecr.api
com.amazonaws.eu-central-1.ecr.dkr

Gateway endpoint (no security group needed, attaches to route table):

com.amazonaws.eu-central-1.s3

For the interface endpoints you need:

A security group allowing HTTPS (443) inbound from your VPC CIDR
Deployed in your private subnets
private_dns_enabled = true

For the S3 gateway endpoint:

Associate it with your private route table

Also add one more endpoint while you're at it:

com.amazonaws.eu-central-1.secretsmanager — your app needs to reach Secrets Manager at runtime too

Four endpoints: ecr.api, ecr.dkr, secretsmanager (interface type), and s3 (gateway type)
Interface endpoints need: service name, VPC ID, private subnets, a security group, private_dns_enabled = true
Gateway endpoint needs: service name, VPC ID, route table IDs (your private route table)
Security group for endpoints: inbound 443 from VPC CIDR (192.168.0.0/16), egress open

To list endpoints available:
aws ec2 describe-vpc-endpoint-services \
  --region eu-central-1 \
  --query 'ServiceNames' \
  --output text | tr '\t' '\n' | grep -E "ecr|secretsmanager|s3"


  ================================================================================
COMMON MISTAKES TO AVOID
================================================================================

MISTAKE 1: Using :latest tag
----------------------------
Problem: Can cause unexpected updates and architecture mismatches
Solution: Always use specific version tags (e.g., :v1.0.0)
Wrong:    docker buildx build -t repo:latest --push .
Correct:  docker buildx build -t repo:v1.0.0 --push .


MISTAKE 2: Pushing to docker.io/library instead of ECR URI
-----------------------------------------------------------
Problem: Tries to push to Docker Hub instead of your ECR, causes "denied: requested access to the resource is denied"
Solution: Always use full ECR URI with account ID and region
Wrong:    docker buildx build -t your-repo:v1.0.0 --push .
Correct:  docker buildx build -t 373270679710.dkr.ecr.eu-central-1.amazonaws.com/url-shortener:v1.0.0 --push .


MISTAKE 3: Using docker build instead of docker buildx
-------------------------------------------------------
Problem: Cannot build for different architectures on Mac/ARM machines
Solution: Use docker buildx for cross-platform builds
Wrong:    docker build --platform linux/amd64 -t image:v1.0.0 .
Correct:  docker buildx build --platform linux/amd64 -t image:v1.0.0 --push .


MISTAKE 4: Forgetting to authenticate with ECR
-----------------------------------------------
Problem: "denied: requested access to the resource is denied" error
Solution: Login to ECR before pushing
Command:  aws ecr get-login-password --region eu-central-1 | \
          docker login --username AWS --password-stdin 373270679710.dkr.ecr.eu-central-1.amazonaws.com


MISTAKE 5: ECR repository doesn't exist
----------------------------------------
Problem: "The repository with name 'url-shortener' does not exist in the registry"
Solution: Create repository first with AWS CLI or Terraform
Command:  aws ecr create-repository \
            --repository-name url-shortener \
            --region eu-central-1


================================================================================
ALL COMMANDS USED (in order)
================================================================================

1. CREATE ECR REPOSITORY
------------------------
aws ecr create-repository \
  --repository-name url-shortener \
  --region eu-central-1


2. LOGIN TO ECR
---------------
aws ecr get-login-password --region eu-central-1 | \
  docker login --username AWS --password-stdin 373270679710.dkr.ecr.eu-central-1.amazonaws.com


3. BUILD AND PUSH IMAGE TO ECR
-------------------------------
docker buildx build --platform linux/amd64 \
  -t 373270679710.dkr.ecr.eu-central-1.amazonaws.com/url-shortener:v1.0.0 \
  --push .


4. VERIFY IMAGE ARCHITECTURE
-----------------------------
aws ecr batch-get-image \
  --repository-name url-shortener \
  --image-ids imageTag=v1.0.0 \
  --region eu-central-1 \
  --query 'images[0].imageManifest' | jq '.config.architecture'


5. FORCE ECS SERVICE REDEPLOY
------------------------------
aws ecs update-service \
  --cluster url-shortener-cluster \
  --service url-shortener-service \
  --force-new-deployment \
  --region eu-central-1


6. CHECK ECR IMAGES (optional - for debugging)
-----------------------------------------------
aws ecr describe-images \
  --repository-name url-shortener \
  --query 'imageDetails[].imageTags' \
  --region eu-central-1


QUICK COPY-PASTE WORKFLOW
==========================

# Step 1: Create repo
aws ecr create-repository --repository-name url-shortener --region eu-central-1

# Step 2: Login
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin 373270679710.dkr.ecr.eu-central-1.amazonaws.com

# Step 3: Build & Push
docker buildx build --platform linux/amd64 -t 373270679710.dkr.ecr.eu-central-1.amazonaws.com/url-shortener:v1.0.0 --push .

# Step 4: Redeploy ECS
aws ecs update-service --cluster url-shortener-cluster --service url-shortener-service --force-new-deployment --region eu-central-1

## Sprint 4
The pipeline needs to do four things on every push to main:

Build the image for linux/amd64
Push to ECR with a new tag
Update the ECS task definition with the new image
Force a new ECS service deployment


#### NEED EXPLANATION TO THIS ########

data source instead of resource:
The OIDC provider is account-level, not project-level. There's only one GitHub OIDC provider per AWS account. You already created it in AdventureConnect with aws_iam_openid_connect_provider. If you try to create it again with resource, Terraform will either error or try to create a duplicate. data says "this already exists, just look it up" — you reference it without owning it in this project's state.
The rule: if a resource was created by another Terraform project and you need to reference it, use data. If you're creating it fresh, use resource.
StringLike instead of StringEquals:
The sub claim from GitHub looks like repo:horvrobert/url-shortener:ref:refs/heads/main — it includes the branch or environment at the end. StringEquals requires an exact match, so it would only work if you hardcode the full string including branch. StringLike with a wildcard * at the end matches any branch, any trigger from that repo.
The aud claim is always exactly sts.amazonaws.com — no variation, so StringEquals is correct there.
The pattern to remember: aud is fixed → StringEquals. sub includes variable parts → StringLike with *.


Image tag uses the Git SHA — every merge to main produces a unique tag, no manual versioning
wait-for-service-stability: true — the pipeline waits until ECS confirms the new task is healthy before marking the run green. If the container crashes, the pipeline fails
permissions: id-token: write — required for OIDC to work

## Sprint 5 - URL Deduplication

Before inserting a new record, check if the long_url already exists in the database.
If it does, return the existing short_code instead of generating a new one.
This is a SELECT before INSERT pattern — common in applications where uniqueness
on a non-primary-key column is required.

```python
# Check if URL already exists
result = conn.execute(text(
    "SELECT short_code FROM urls WHERE long_url = :url"
), {"url": request.long_url})
row = result.fetchone()
if row:
    return {"short_code": row[0], "long_url": request.long_url}

# Generate new code if not found
code = generate_code()
conn.execute(text(
    "INSERT INTO urls (short_code, long_url) VALUES (:code, :url)"
), {"code": code, "url": request.long_url})
conn.commit()
```

Trade-off: two users shortening the same URL get the same short link.
In production you might want per-user isolation — store user_id alongside the URL.

## CloudFront ACM Certificate Region Requirement

CloudFront is a global AWS service. Unlike regional services (ALB, ECS, RDS)
which use certificates from the same region, CloudFront only accepts ACM
certificates from us-east-1.

This means if your infrastructure is in eu-central-1:
- ALB needs an ACM cert in eu-central-1
- CloudFront needs a SEPARATE ACM cert in us-east-1

Both certs can cover the same domains and use the same DNS validation records
in Route 53 — you just need two aws_acm_certificate resources with different
provider aliases.

Rule to remember: CloudFront = us-east-1 certificate, always.

## Sprint 5 - Post-Launch Lessons

### IAM roles need updating when new pipeline steps are added
When you added the frontend deploy pipeline, you added a new AWS action (s3:PutObject)
but never updated the IAM role that the pipeline assumes. OIDC auth succeeded,
CloudFront permissions were there, but S3 was never included.
Rule: every time a pipeline gains a new AWS action, check the IAM role first.

### CORS allow_origins must exactly match the browser's Origin header
The browser sends the Origin header as the exact domain serving the page.
If your frontend is on www.shrinkr.click, the Origin is https://www.shrinkr.click.
If it's on the raw CloudFront domain, the Origin is that domain.
allow_origins=["https://shrinkr.click"] will not match www.shrinkr.click — they are
different origins. For portfolio projects with no auth, allow_origins=["*"] eliminates
this class of bug entirely. In production with auth tokens, lock it down.

### Browser input type="url" does not enforce protocol prefix
type="url" is a hint, not validation. Users can and will enter bare hostnames
like "www.google.com". If your API stores and redirects these as-is, the browser
treats them as relative paths on your domain, not absolute URLs.
Always prepend https:// if the protocol is missing before sending to the API.