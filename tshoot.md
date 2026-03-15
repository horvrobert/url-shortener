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


================================================================================
ISSUE: Frontend fails with mixed content block — HTTPS page calling HTTP API
================================================================================

ERROR
-----
Browser blocks POST request from https://dmjud0bhi7eg8.cloudfront.net to
http://url-shortener-alb-206207805.eu-central-1.elb.amazonaws.com/shorten

Network tab shows: Mixed Block, 0 B transferred, Finish: 0 ms


ROOT CAUSE
----------
CloudFront serves the frontend over HTTPS. Browsers enforce mixed content
policy — HTTPS pages cannot make requests to HTTP endpoints. The ALB only
has an HTTP :80 listener with no TLS certificate, so the API is only
reachable over HTTP.

This is separate from CORS. CORS middleware was added to FastAPI but the
request never reaches the server — the browser blocks it before sending.


SOLUTION
--------
Add HTTPS to the ALB:
1. Register a custom domain in Route 53
2. Request an ACM certificate for the domain
3. Add HTTPS :443 listener to the ALB using the ACM certificate
4. Update index.html API_BASE to use the custom domain over HTTPS
5. Update FastAPI CORS allow_origins to the custom domain

STEPS TO FIX
============

STEP 1: Register domain in Route 53
-------------------------------------
Registered shrinkr.click via Route 53 (~$3/year .click TLD)

STEP 2: Add dns.tf
--------------------
- Route 53 hosted zone data source for shrinkr.click
- ACM certificate with DNS validation for shrinkr.click
- Route 53 A record aliased to ALB

STEP 3: Update alb.tf
-----------------------
- HTTP listener changed from forward to HTTP 301 redirect to HTTPS
- New HTTPS :443 listener using ACM certificate ARN
- TLS policy: ELBSecurityPolicy-TLS13-1-2-2021-06

STEP 4: Update main.py CORS origin
------------------------------------
allow_origins changed from CloudFront domain to https://shrinkr.click

STEP 5: Update index.html API_BASE
------------------------------------
const API_BASE = 'https://shrinkr.click'

STEP 6: Add root redirect in main.py
--------------------------------------
GET / returns RedirectResponse to CloudFront frontend
Required because shrinkr.click DNS points to ALB — visiting root in browser
returned FastAPI 404 without a dedicated root route


VERIFICATION
------------
- https://shrinkr.click redirects to CloudFront frontend
- https://shrinkr.click/abc123 redirects to original URL
- HTTP requests to shrinkr.click redirect to HTTPS automatically
- ACM certificate valid, no browser TLS warnings

================================================================================
ISSUE: CORS preflight blocked — OPTIONS returns 400, missing Allow-Origin header
================================================================================

ERROR
-----
Cross-Origin Request Blocked: The Same Origin Policy disallows reading the
remote resource at https://shrinkr.click/shorten.
Reason: CORS header 'Access-Control-Allow-Origin' missing. Status code: 400.

Network tab shows:
- POST to shrinkr.click/shorten — 0 B transferred
- OPTIONS to shrinkr.click/shorten — 400, CORS Missing Allow Origin


ROOT CAUSE
----------
FastAPI CORS middleware was configured with:
  allow_origins=["https://shrinkr.click"]

But the frontend is served from https://dmjud0bhi7eg8.cloudfront.net.
The browser sends the Origin header as the CloudFront domain, not shrinkr.click.
FastAPI rejected the preflight because the origin didn't match.

Note: this is separate from the mixed content issue. The request now reaches
the server over HTTPS, but the CORS policy rejected it.


STEPS TO FIX
============

STEP 1: Add CloudFront domain to allow_origins in main.py
-----------------------------------------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://shrinkr.click",
        "https://dmjud0bhi7eg8.cloudfront.net"
    ],
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
)

STEP 2: Push to main — pipeline deploys automatically
------------------------------------------------------
git add main.py
git commit -m "fix: add CloudFront domain to CORS allow_origins"
git push origin main


WHY BOTH ORIGINS ARE NEEDED
-----------------------------
shrinkr.click points to the ALB (API). The frontend is served from CloudFront.
Until shrinkr.click is pointed to CloudFront for the frontend (with api.shrinkr.click
for the API), both origins must be allowed. This is a known trade-off documented
in decisions.md.


VERIFICATION
------------
- OPTIONS preflight to https://shrinkr.click/shorten returns 200
- POST /shorten returns {"short_code": "...", "long_url": "..."}
- Short URL displayed in frontend UI

================================================================================
ISSUE: CloudFront rejects ACM certificate — InvalidViewerCertificate
================================================================================

ERROR
-----
Error: updating CloudFront Distribution (EX5Z7T6XDTE4T): operation error
CloudFront: UpdateDistribution, https response error StatusCode: 400,
InvalidViewerCertificate: The specified SSL certificate doesn't exist,
isn't in us-east-1 region, isn't valid, or doesn't include a valid
certificate chain.


ROOT CAUSE
----------
CloudFront is a global service and only accepts ACM certificates from
us-east-1 regardless of where your other infrastructure lives.
The ACM certificate was created in eu-central-1 (same region as the ALB),
which is correct for ALB but invalid for CloudFront.


STEPS TO FIX
============

STEP 1: Add us-east-1 provider to main.tf
------------------------------------------
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

STEP 2: Add second ACM certificate in us-east-1 in dns.tf
-----------------------------------------------------------
resource "aws_acm_certificate" "shrinkr_us" {
  provider                  = aws.us_east_1
  domain_name               = "shrinkr.click"
  subject_alternative_names = ["www.shrinkr.click"]
  validation_method         = "DNS"
  ...
}

resource "aws_acm_certificate_validation" "shrinkr_us" {
  provider        = aws.us_east_1
  certificate_arn = aws_acm_certificate.shrinkr_us.arn
  validation_record_fqdns = [for record in aws_route53_record.shrinkr_cert_validation : record.fqdn]
}

STEP 3: Update cloudfront.tf to use us-east-1 certificate
-----------------------------------------------------------
viewer_certificate {
  acm_certificate_arn      = aws_acm_certificate_validation.shrinkr_us.certificate_arn
  ssl_support_method       = "sni-only"
  minimum_protocol_version = "TLSv1.2_2021"
}


WHY TWO CERTIFICATES
---------------------
- eu-central-1 certificate — used by ALB HTTPS listener
- us-east-1 certificate — used by CloudFront (mandatory requirement)
Both cover the same domains (shrinkr.click, www.shrinkr.click) and use
the same Route 53 DNS validation records.


VERIFICATION
------------
- terraform apply completes without certificate errors
- https://www.shrinkr.click loads frontend
- CloudFront distribution shows custom SSL certificate in console