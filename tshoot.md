================================================================================
ISSUE: ECS task unable to pull image from ECR
================================================================================

ERROR
-----
ResourceInitializationError: unable to pull secrets or registry auth:
The task cannot pull registry auth from Amazon ECR: There is a connection
issue between the task and Amazon ECR.

Full event message:
"service url-shortener-service was unable to place a task. Reason:
ResourceInitializationError: unable to pull secrets or registry auth:
The task cannot pull registry auth from Amazon ECR: There is a connection
issue between the task and Amazon ECR. Check your task network configuration.
operation error ECR: GetAuthorizationToken, exceeded maximum number of
attempts, 3, https response error StatusCode: 0, RequestID: , request send
failed, Post "https://api.ecr.eu-central-1.amazonaws.com/": dial tcp
3.122.128.199:443: i/o timeout."


ROOT CAUSE
----------
ECS tasks deployed in private subnets have no route to ECR endpoints.
Private subnets have no IGW route and no VPC endpoints configured for ECR.
Task attempted to reach ECR over the public internet (3.122.128.199:443)
but the private subnet has no path there.


SOLUTION OPTIONS
----------------
1. Add VPC endpoints for ecr.api, ecr.dkr, s3, secretsmanager, and logs (~$22/month)
2. Move ECS tasks to public subnets with assign_public_ip = true (free, less secure)


STEPS TO FIX (Option 1 - chosen)
=================================

STEP 1: Add VPC endpoints in endpoints.tf
------------------------------------------
Interface endpoints: ecr.api, ecr.dkr, secretsmanager, logs in private subnets.
Gateway endpoint: s3 on private route table.
All interface endpoints use a dedicated sg_endpoints security group allowing
port 443 ingress from the VPC CIDR (192.168.0.0/16).

STEP 2: Apply Terraform
------------------------
terraform plan
terraform apply


VERIFICATION
------------
- ECS task reaches RUNNING state
- No ResourceInitializationError in ECS service events
- CloudWatch logs appear in /ecs/url-shortener

Decision documented in decisions.md. Option 2 rejected - ECS tasks in public
subnets are not production-correct.


================================================================================
ISSUE: ECS task fails with exec format error - architecture mismatch
================================================================================

ERROR
-----
exec /usr/local/bin/uvicorn: exec format error

Event message:
"Essential container in task exited. Exit code: 255."


ROOT CAUSE
----------
Docker image built for linux/arm64 (Apple M1/M2 Mac).
AWS Fargate requires linux/amd64. Architecture mismatch causes immediate
container exit on startup.


STEPS TO FIX
============

STEP 1: Update Dockerfile to pin platform
------------------------------------------
ARG BUILDPLATFORM=linux/amd64
FROM --platform=${BUILDPLATFORM} python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]


STEP 2: Authenticate with ECR
------------------------------
aws ecr get-login-password --region eu-central-1 | \
  docker login --username AWS --password-stdin 373270679710.dkr.ecr.eu-central-1.amazonaws.com


STEP 3: Build for amd64 and push to ECR
-----------------------------------------
docker buildx build --platform linux/amd64 \
  -t 373270679710.dkr.ecr.eu-central-1.amazonaws.com/url-shortener:v1.0.1 \
  --push .

Key points:
- Use docker buildx build, not docker build, for cross-platform builds
- --push pushes directly to ECR during build
- Use specific version tags (v1.0.1), not :latest
- Must use full ECR URI


STEP 4: Verify image architecture
-----------------------------------
aws ecr batch-get-image \
  --repository-name url-shortener \
  --image-ids imageTag=v1.0.1 \
  --region eu-central-1 \
  --query 'images[0].imageManifest' | jq '.config.architecture'

Expected output: "amd64"


STEP 5: Update image tag in ecs.tf and redeploy
-------------------------------------------------
Update container_definitions image field to the new tag, then:

aws ecs update-service \
  --cluster url-shortener-cluster \
  --service url-shortener-service \
  --force-new-deployment \
  --region eu-central-1


VERIFICATION
------------
- Task reaches RUNNING state in ECS console
- Check CloudWatch logs: /ecs/url-shortener
- Verify container is healthy in ECS task details


================================================================================
ISSUE: GET /{code} returns JSON instead of redirecting + /health returns 404
================================================================================

ERROR
-----
curl -L http://<alb-dns>/mUGHZX
{"long_url":"https://google.com"}   <- expected HTTP 301 redirect

curl http://<alb-dns>/health
{"detail":"Code not found"}         <- expected {"status": "healthy"}


ROOT CAUSE
----------
Two separate bugs in main.py:

1. redirect_url() returned {"long_url": row[0]} (plain JSON) instead of a
   RedirectResponse. RedirectResponse was never imported or used.

2. No dedicated GET /health endpoint existed. FastAPI routed /health to the
   /{code} catch-all handler, which looked up "health" in the database,
   found nothing, and raised a 404.


STEPS TO FIX
============

STEP 1: Import RedirectResponse
---------------------------------
from fastapi.responses import RedirectResponse


STEP 2: Add /health endpoint BEFORE the /{code} route
-------------------------------------------------------
@app.get("/health")
def health_check():
    return {"status": "healthy"}


STEP 3: Fix redirect_url to return a 301
------------------------------------------
@app.get("/{code}")
def redirect_url(code: str):
    ...
    return RedirectResponse(url=row[0], status_code=301)


WHY ROUTE ORDER MATTERS IN FASTAPI
------------------------------------
FastAPI matches routes top to bottom. A catch-all like /{code} will intercept
any path including /health, /docs, /favicon.ico unless more specific routes
are declared first. Always define specific routes before catch-alls.


VERIFICATION
------------
curl http://<alb-dns>/health
  -> {"status": "healthy"}

curl -X POST http://<alb-dns>/shorten -H "Content-Type: application/json" \
  -d '{"long_url": "https://google.com"}'
  -> {"short_code": "...", "long_url": "..."}

curl -L http://<alb-dns>/<short-code>
  -> follows 301, returns destination page