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