#!/bin/bash
set -e

# Install dependencies
yum update -y
yum install -y docker aws-cli nginx jq
systemctl enable docker nginx
systemctl start docker nginx

# Add ec2-user to docker group
usermod -aG docker ec2-user

# Install CloudWatch agent
yum install -y amazon-cloudwatch-agent

# Fetch secrets from Secrets Manager and write to /etc/app.env
aws secretsmanager get-secret-value \
  --secret-id "${secret_arn}" \
  --region "${aws_region}" \
  --query SecretString \
  --output text | jq -r 'to_entries[] | "\(.key)=\(.value)"' > /etc/app.env

chmod 600 /etc/app.env

# Authenticate Docker to ECR
aws ecr get-login-password --region "${aws_region}" | \
  docker login --username AWS --password-stdin "${ecr_repo_url}"

# Pull and run the app container
docker pull "${ecr_repo_url}:latest"

docker run -d \
  --name "${app_name}" \
  --env-file /etc/app.env \
  --restart unless-stopped \
  -p 3000:3000 \
  "${ecr_repo_url}:latest"

# Configure Nginx reverse proxy
cat > /etc/nginx/conf.d/${app_name}.conf << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

nginx -t && systemctl reload nginx

# Start CloudWatch agent for logs
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/lib/docker/containers/*/*-json.log",
            "log_group_name": "/${app_name}/app",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  },
  "metrics": {
    "metrics_collected": {
      "cpu": { "measurement": ["cpu_usage_idle", "cpu_usage_user"] },
      "mem": { "measurement": ["mem_used_percent"] }
    }
  }
}
EOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s