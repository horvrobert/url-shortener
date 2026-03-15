## Sprint 1 - Phase 1: Local API

Test: POST /shorten
Input: long IKEA URL
Expected: short code returned
Result: PASS - returned code VnlAlK

Test: GET /{code}
Input: VnlAlK
Expected: original URL returned
Result: PASS


## Sprint 1 - Phase 2: Dockerized API

Test: docker build
Expected: image builds without errors
Result: PASS

Test: docker run -p 8000:8000 url-shortener
Expected: container starts, uvicorn running on 0.0.0.0:8000
Result: PASS

Test: POST /shorten (inside container)
Input: long URL
Expected: short code returned
Result: PASS

Test: GET /{code} (inside container)
Input: returned code
Expected: original URL returned
Result: PASS


## Sprint 2 - Phase 1: Docker Compose with PostgreSQL

Test: docker compose up --build
Expected: both app and db containers start without errors
Result: PASS

Test: POST /shorten (app connected to PostgreSQL)
Input: long IKEA URL
Expected: short code returned
Result: PASS - returned code JVNo98

Test: GET /{code} (reading from PostgreSQL)
Input: JVNo98
Expected: original URL returned
Result: PASS

Test: Data persistence across restart
Steps: docker compose down, docker compose up, GET /JVNo98
Expected: data still present after restart
Result: PASS - volume working correctly


## Sprint 2 - Phase 2: RDS provisioned in private subnet

Test: RDS provisioned in private subnet
Expected: RDS instance running, not publicly accessible, attached to private subnets
Result: PASS - confirmed in AWS console, publicly_accessible = false

Test: Secrets Manager Secret Retrieval
Expected: ECS has access to Secrets Manager. Credentials are stored correctly and retrievable at runtime.
Result: PASS

Steps:

```bash
aws secretsmanager get-secret-value \
  --secret-id url-shortener-db-credentials \
  --region eu-central-1
```

Expected result: JSON response containing `username` and `password` fields.

Actual result: Secret returned successfully. Used returned credentials to authenticate to RDS.

```bash
    "SecretString": "{\"dbname\":\"urlshortnerdb01\",\"host\":\"url-shortener-db.c1e00qcsmzm4.eu-central-1.rds.amazonaws.com\",\"password\":\"xxxxxxxxx\",\"port\":5432,\"username\":\"xxxxxxxxxxx\"}",
```


## Sprint 3 - ECS Fargate Deployment

Test: ECS task running (amd64 image)
Expected: task reaches RUNNING state, no crashes
Result: PASS - image rebuilt for linux/amd64 platform, task stable

Test: ALB target group health check
Expected: target shows healthy in target group
Result: PASS - confirmed in AWS console

Test: ALB DNS reachability
Input: GET /health via ALB DNS
Expected: 200 response
Result: PASS - returns {"status": "healthy"} after adding dedicated /health endpoint before /{code} catch-all route

Test: POST /shorten via ALB
Input: {"long_url": "https://google.com"}
Expected: short code returned
Result: PASS - returned code ZnhtwS

Test: GET /{code} redirect via ALB
Input: GET /ZnhtwS (curl -L)
Expected: HTTP 301 redirect to https://google.com
Result: PASS - curl -L followed redirect, Google homepage HTML returned confirming redirect working end to end


## Sprint 4 - CI/CD Pipeline

Test: GitHub Actions workflow triggers on push to main
Expected: workflow starts automatically on push
Result: PASS - Build and Deploy workflow triggered on commit

Test: OIDC authentication to AWS
Expected: GitHub Actions assumes url-shortener-github-actions-role via OIDC
Result: PASS - no static credentials, short-lived token issued per run

Test: Docker image build and push to ECR
Expected: image built for linux/amd64, tagged with Git SHA, pushed to ECR
Result: PASS - image tagged sha-${{ github.sha }} pushed successfully

Test: ECS task definition updated with new image
Expected: new task definition revision created with updated image URI
Result: PASS - task definition updated automatically by pipeline

Test: ECS service redeployed
Expected: ECS service updated to use new task definition, service stable
Result: PASS - pipeline waited for service stability, deployment confirmed

Test: Health check after pipeline deployment
Input: GET /health via ALB DNS
Expected: {"status": "healthy"}
Result: PASS - curl http://url-shortener-alb-1795196136.eu-central-1.elb.amazonaws.com/health returned {"status":"healthy"}


## Sprint 5 - S3 + CloudFront Frontend

Test: S3 bucket created with public access blocked
Expected: bucket exists, all public access settings blocked, only CloudFront OAC can read
Result: PASS - confirmed in AWS console

Test: CloudFront distribution deployed
Expected: distribution enabled, default root object index.html, HTTPS redirect active
Result: PASS - distribution domain dmjud0bhi7eg8.cloudfront.net accessible

Test: index.html served via CloudFront
Expected: URL Shortener UI loads over HTTPS
Result: PASS - frontend loads at https://dmjud0bhi7eg8.cloudfront.net

Test: POST /shorten via frontend
Expected: short code returned and displayed
Result: FAIL - mixed content block — CloudFront serves HTTPS but API call targets ALB over HTTP
Browser blocks HTTP requests from HTTPS pages

Test: CORS fix deployed
Expected: FastAPI accepts requests from CloudFront origin
Result: PASS - CORSMiddleware added with allow_origins set to CloudFront domain

Test: Mixed content fix
Expected: frontend calls ALB over HTTPS
Result: BLOCKED - ALB only has HTTP listener, no ACM certificate configured
Resolution: requires custom domain + ACM certificate + HTTPS ALB listener (in progress)

## Sprint 5 - Custom Domain + HTTPS (continued)

Test: ACM certificate issued and validated
Expected: certificate status Active, DNS validation records created in Route 53
Result: PASS - certificate validated automatically via Route 53 DNS validation

Test: HTTPS listener on ALB
Expected: ALB accepts HTTPS :443 traffic, forwards to ECS target group
Result: PASS - shrinkr.click reachable over HTTPS

Test: HTTP to HTTPS redirect
Expected: HTTP requests to shrinkr.click redirect to HTTPS with 301
Result: PASS - browser follows redirect automatically

Test: shrinkr.click root path
Expected: visiting shrinkr.click redirects to CloudFront frontend
Result: PASS after fix - initial visit returned FastAPI 404, fixed by adding GET / root redirect in main.py

Test: POST /shorten via frontend at shrinkr.click
Expected: short code returned and displayed in UI
Result: PASS - frontend at CloudFront calls https://shrinkr.click/shorten, short code returned

Test: GET /shrinkr.click/{code} redirect
Expected: short link redirects to original URL
Result: PASS - 301 redirect working end to end on branded domain