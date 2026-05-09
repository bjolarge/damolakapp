# DAMOLAKAPP — Production DevOps Deployment

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Tech Stack](#tech-stack)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Deployment Steps](#deployment-steps)
- [CI/CD Pipeline](#cicd-pipeline)
- [Design Decisions](#design-decisions)
- [Assumptions](#assumptions)
- [Limitations & Future Improvements](#limitations--future-improvements)

---

## Architecture Overview

```
Developer → GitHub (push) → Jenkins CI/CD Pipeline
                                    │
                    ┌───────────────┼───────────────┐
                 Build           Test          Docker Build
                (npm ci)      (Jest tests)   (push to ECR)
                                                     │
                                              Deploy to EC2
                                                     │
                                    ┌────────────────┴──────────────┐
                               Nginx (port 80)              CloudWatch
                               reverse proxy                Logs + Metrics
                                    │
                         NestJS Container (port 3000)
                                    │
                         Aiven PostgreSQL (TLS/SSL)
                         port 13839 — external managed DB
```

**Traffic flow:**
- HTTP requests hit EC2 on port 80
- Nginx reverse proxies to the NestJS container on port 3000
- NestJS connects to Aiven PostgreSQL over SSL using credentials fetched from AWS Secrets Manager
- CloudWatch Agent ships container logs and system metrics to AWS CloudWatch

---

## Tech Stack

| Layer | Technology |
|---|---|
| Application | NestJS (Node.js), TypeORM |
| Database | Aiven Managed PostgreSQL |
| Containerization | Docker (multi-stage build) |
| Container Registry | AWS ECR |
| Infrastructure | Terraform (modular) |
| Cloud | AWS EC2, Secrets Manager, CloudWatch |
| CI/CD | Jenkins (Declarative Pipeline) |
| Reverse Proxy | Nginx |
| IaC | Terraform >= 1.5.0 |

---

## Repository Structure

```
damolakapp/
├── src/                          # NestJS application source
├── test/                         # Jest tests
├── terraform/                    # All infrastructure as code
│   ├── main.tf                   # Root module
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example  # Template — never commit tfvars
│   └── modules/
│       ├── vpc/main.tf           # VPC, subnets, routing
│       ├── ecr/main.tf           # Container registry
│       ├── secrets/main.tf       # AWS Secrets Manager
│       └── ec2/
│           ├── main.tf           # EC2, IAM, security groups
│           └── user_data.sh      # Bootstrap script
├── Dockerfile                    # Multi-stage production build
├── docker-compose.yml            # Local development
├── .dockerignore
├── Jenkinsfile                   # CI/CD pipeline definition
├── package.json
└── README.md
```

---

## Prerequisites

Before deploying, ensure you have:

- [ ] AWS account with programmatic access (Access Key + Secret)
- [ ] AWS CLI installed and configured (`aws configure`)
- [ ] Terraform >= 1.5.0 installed
- [ ] Docker installed
- [ ] An AWS EC2 Key Pair created in your target region
- [ ] Jenkins server running with these plugins:
  - Pipeline: AWS Steps
  - SSH Agent Plugin
- [ ] Aiven PostgreSQL instance running with SSL enabled
- [ ] Your `DB_SSLG` — base64 encoded Aiven CA certificate

---

## Deployment Steps

### 1. Clone the repository
```bash
git clone https://github.com/your-username/damolakapp.git
cd damolakapp
```

### 2. Set up Terraform variables
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your real values — never commit this file
```

### 3. Provision AWS infrastructure
```bash
terraform init
terraform plan
terraform apply
```

After apply, note the outputs:
```
ec2_public_ip      = "x.x.x.x"
ecr_repository_url = "123456789.dkr.ecr.us-east-1.amazonaws.com/damolakapp"
secret_arn         = "arn:aws:secretsmanager:..."
```

### 4. Configure Jenkins credentials
In Jenkins → Manage Jenkins → Credentials, add:

| Credential ID | Type | Description |
|---|---|---|
| `ECR_REPO_URL` | Secret text | ECR URL from Terraform output |
| `EC2_HOST` | Secret text | EC2 public IP from Terraform output |
| `AWS_CREDENTIALS` | AWS credentials | AWS access key + secret key |
| `EC2_SSH_KEY` | SSH private key | Your EC2 `.pem` key file |

### 5. Create Jenkins Pipeline job
- New Item → Pipeline
- Set Pipeline definition to: **Pipeline script from SCM**
- SCM: Git → your repository URL
- Script Path: `Jenkinsfile`
- Save and run

### 6. Trigger deployment
Push to your main branch — Jenkins will automatically:
1. Build the NestJS app
2. Run tests
3. Build and push Docker image to ECR
4. SSH into EC2 and deploy the new container

### 7. Verify deployment
```bash
# App
curl http://<EC2_PUBLIC_IP>

# Swagger docs
curl http://<EC2_PUBLIC_IP>/api
```

### Local Development
```bash
cp .env.example .env       # fill in your local DB values
docker compose up --build  # starts app + local postgres
```

---

## CI/CD Pipeline

The Jenkins pipeline has 5 stages:

```
Checkout → Build → Test → Docker Build & Push → Deploy to EC2
```

| Stage | What it does |
|---|---|
| Checkout | Pulls latest code from GitHub |
| Build | Runs `npm ci` and `npm run build` |
| Test | Runs Jest test suite (`--passWithNoTests` for safety) |
| Docker Build & Push | Builds multi-stage image, tags with build number + `latest`, pushes to ECR |
| Deploy to EC2 | SSHs into EC2, pulls latest image, restarts container with zero downtime swap |

---

## Design Decisions

**Aiven PostgreSQL over AWS RDS**
The application already uses an existing Aiven managed PostgreSQL instance. This avoids provisioning and managing an RDS instance, reduces AWS costs, and Aiven provides built-in SSL, backups, and high availability out of the box.

**AWS Secrets Manager for credentials**
All sensitive values (DB host, port, password, SSL cert) are stored in Secrets Manager and fetched by EC2 at boot time into `/etc/app.env` with `chmod 600`. This means no secrets ever touch the codebase, CI/CD logs, or environment variables in plain text.

**Multi-stage Docker build**
The production image only contains compiled `dist/` output and production `node_modules`. Dev dependencies, TypeScript source, and tooling are discarded — resulting in a significantly smaller and more secure image.

**EC2 over ECS/EKS**
EC2 was chosen for simplicity and direct control. For this application's scale, the operational overhead of ECS or EKS is unnecessary. EC2 with Docker and Nginx provides a straightforward, auditable deployment that is easy to debug and maintain.

**Modular Terraform**
Infrastructure is split into four focused modules (`vpc`, `ecr`, `secrets`, `ec2`) so each concern can be updated, tested, or reused independently without affecting others.

**Nginx as reverse proxy**
Nginx handles port 80 traffic and proxies to the NestJS container on port 3000. This keeps the container unexposed directly and provides a layer to add SSL termination, rate limiting, or caching in the future.

---

## Assumptions

- A single EC2 instance is sufficient for this workload
- The Aiven PostgreSQL instance is already provisioned and accessible from AWS
- SSL is enforced on the Aiven DB connection in production via `DB_SSLG` (base64 CA cert)
- Jenkins is running on a separate server with Docker and AWS CLI installed
- The AWS key pair for EC2 SSH access is created before running Terraform
- `NODE_ENV=production` is set via Secrets Manager, not hardcoded

---

## Limitations & Future Improvements

| Limitation | Suggested Improvement |
|---|---|
| Single EC2 instance — no high availability | Add an Auto Scaling Group + Application Load Balancer |
| No HTTPS on Nginx | Add ACM certificate + ALB with HTTPS listener, or use Certbot on EC2 |
| SSH port 22 open to `0.0.0.0/0` | Restrict to Jenkins server IP or use AWS SSM Session Manager |
| No rollback mechanism | Tag images with build numbers in ECR; redeploy previous tag on failure |
| `synchronize: true` in TypeORM | Switch to TypeORM migrations for production schema changes |
| Jenkins server not provisioned by Terraform | Add Jenkins EC2 module or migrate to GitHub Actions |
| No health check endpoint | Add `/health` endpoint and configure Nginx to monitor it |
| Container logs only via CloudWatch | Add structured JSON logging with a log aggregator like Datadog or ELK |