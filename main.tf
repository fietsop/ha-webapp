terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Jenkins-Server"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Data source for latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Get current IP for security group (optional)
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

# VPC - Use default or specify custom VPC
data "aws_vpc" "default" {
  default = var.use_default_vpc
}

# Use default subnet or create custom
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group for Jenkins
resource "aws_security_group" "jenkins" {
  name        = "${var.project_name}-${var.environment}-sg"
  description = "Security group for Jenkins server"
  vpc_id      = data.aws_vpc.default.id

  # SSH access
  ingress {
    description = "SSH from allowed IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr_blocks
  }

  # Jenkins web UI
  ingress {
    description = "Jenkins web UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.allowed_jenkins_cidr_blocks
  }

  # HTTP (if using Nginx reverse proxy)
  ingress {
    description = "HTTP access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidr_blocks
  }

  # HTTPS (if using Nginx with SSL)
  ingress {
    description = "HTTPS access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_https_cidr_blocks
  }

  # Outbound internet access
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-sg"
  }
}

# IAM Role for Jenkins EC2 instance
resource "aws_iam_role" "jenkins" {
  name = "${var.project_name}-${var.environment}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-role"
  }
}

# IAM Policy for Jenkins (customize based on your needs)
resource "aws_iam_role_policy" "jenkins_policy" {
  name = "${var.project_name}-${var.environment}-policy"
  role = aws_iam_role.jenkins.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach AWS managed policies
resource "aws_iam_role_policy_attachment" "ssm_managed_instance" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.project_name}-${var.environment}-profile"
  role = aws_iam_role.jenkins.name

  tags = {
    Name = "${var.project_name}-${var.environment}-profile"
  }
}

# User Data Script for Jenkins Installation
locals {
  user_data = <<-EOF
              #!/bin/bash
              set -e
              
              # Log output
              exec > >(tee /var/log/user-data.log)
              exec 2>&1
              
              echo "=== Starting Jenkins Installation ==="
              date
              
              # Update system
              echo "Updating system packages..."
              dnf update -y
              
              # Install Java 17 (required for Jenkins)
              echo "Installing Java 17..."
              dnf install -y java-17-amazon-corretto-devel
              
              # Verify Java installation
              java -version
              
              # Set JAVA_HOME
              JAVA_HOME=$(readlink -f $(which java) | sed "s:/bin/java::")
              echo "export JAVA_HOME=$JAVA_HOME" >> /etc/profile
              echo "export PATH=\$PATH:\$JAVA_HOME/bin" >> /etc/profile
              
              # Install Git (useful for Jenkins jobs)
              echo "Installing Git..."
              dnf install -y git
              
              # Add Jenkins repository
              echo "Adding Jenkins repository..."
              wget -O /etc/yum.repos.d/jenkins.repo \
                  https://pkg.jenkins.io/redhat-stable/jenkins.repo
              
              # Import Jenkins GPG key
              rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
              
              # Install Jenkins
              echo "Installing Jenkins..."
              dnf install jenkins -y
              
              # Start and enable Jenkins
              echo "Starting Jenkins service..."
              systemctl daemon-reload
              systemctl enable jenkins
              systemctl start jenkins
              
              # Wait for Jenkins to start
              echo "Waiting for Jenkins to start..."
              sleep 60
              
              # Get initial admin password
              if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
                  JENKINS_PASSWORD=$(cat /var/lib/jenkins/secrets/initialAdminPassword)
                  echo "=== Jenkins Initial Admin Password ==="
                  echo "$JENKINS_PASSWORD"
                  echo "========================================"
                  
                  # Store password in SSM Parameter Store (optional)
                  aws ssm put-parameter \
                      --name "/${var.project_name}/${var.environment}/jenkins-initial-password" \
                      --value "$JENKINS_PASSWORD" \
                      --type "SecureString" \
                      --overwrite \
                      --region ${var.aws_region} || echo "Failed to store in SSM"
              fi
              
              ${var.install_docker ? <<-DOCKER
              # Install Docker (optional)
              echo "Installing Docker..."
              dnf install -y docker
              systemctl start docker
              systemctl enable docker
              
              # Add jenkins user to docker group
              usermod -aG docker jenkins
              
              # Restart Jenkins to apply group changes
              systemctl restart jenkins
              DOCKER
              : ""}
              
              ${var.install_nginx ? <<-NGINX
              # Install and configure Nginx as reverse proxy (optional)
              echo "Installing Nginx..."
              dnf install -y nginx
              
              # Configure Nginx for Jenkins
              cat > /etc/nginx/conf.d/jenkins.conf << 'NGINXCONF'
              upstream jenkins {
                  server 127.0.0.1:8080 fail_timeout=0;
              }
              
              server {
                  listen 80;
                  server_name ${var.domain_name != "" ? var.domain_name : "_"};
                  
                  location / {
                      proxy_pass http://jenkins;
                      proxy_set_header Host \$host;
                      proxy_set_header X-Real-IP \$remote_addr;
                      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                      proxy_set_header X-Forwarded-Proto \$scheme;
                      
                      # WebSocket support
                      proxy_http_version 1.1;
                      proxy_set_header Upgrade \$http_upgrade;
                      proxy_set_header Connection "upgrade";
                  }
              }
              NGINXCONF
              
              # Start Nginx
              systemctl start nginx
              systemctl enable nginx
              NGINX
              : ""}
              
              # Install CloudWatch agent (optional)
              echo "Installing CloudWatch agent..."
              wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
              rpm -U ./amazon-cloudwatch-agent.rpm
              
              # Configure CloudWatch agent
              cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json << 'CWCONFIG'
              {
                "metrics": {
                  "namespace": "Jenkins",
                  "metrics_collected": {
                    "mem": {
                      "measurement": [
                        {"name": "mem_used_percent", "rename": "MemoryUtilization", "unit": "Percent"}
                      ],
                      "metrics_collection_interval": 60
                    },
                    "disk": {
                      "measurement": [
                        {"name": "used_percent", "rename": "DiskUtilization", "unit": "Percent"}
                      ],
                      "metrics_collection_interval": 60,
                      "resources": ["/"]
                    }
                  }
                },
                "logs": {
                  "logs_collected": {
                    "files": {
                      "collect_list": [
                        {
                          "file_path": "/var/log/jenkins/jenkins.log",
                          "log_group_name": "/aws/ec2/jenkins",
                          "log_stream_name": "{instance_id}/jenkins.log"
                        }
                      ]
                    }
                  }
                }
              }
              CWCONFIG
              
              # Start CloudWatch agent
              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
                  -a fetch-config \
                  -m ec2 \
                  -s \
                  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json
              
              # Create info page
              cat > /tmp/jenkins-info.html << 'INFOPAGE'
              <!DOCTYPE html>
              <html>
              <head><title>Jenkins Server Info</title></head>
              <body>
                  <h1>Jenkins Server Successfully Deployed!</h1>
                  <p><strong>Access Jenkins at:</strong> http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080</p>
                  <p><strong>Instance ID:</strong> $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
                  <p><strong>Check initial password:</strong> sudo cat /var/lib/jenkins/secrets/initialAdminPassword</p>
              </body>
              </html>
              INFOPAGE
              
              echo "=== Jenkins Installation Complete ==="
              echo "Jenkins should be accessible at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
              echo "Initial admin password location: /var/lib/jenkins/secrets/initialAdminPassword"
              date
              EOF
}

# EC2 Instance for Jenkins
resource "aws_instance" "jenkins" {
  ami                    = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.jenkins.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins.name
  
  # Use first available subnet
  subnet_id = length(data.aws_subnets.default.ids) > 0 ? data.aws_subnets.default.ids[0] : null

  user_data = base64encode(local.user_data)

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring = true

  tags = {
    Name = "${var.project_name}-${var.environment}-server"
  }

  lifecycle {
    ignore_changes = [
      ami,
      user_data
    ]
  }
}

# Elastic IP (optional but recommended for consistent access)
resource "aws_eip" "jenkins" {
  count    = var.allocate_elastic_ip ? 1 : 0
  instance = aws_instance.jenkins.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-eip"
  }
}

# CloudWatch Log Group for Jenkins logs
resource "aws_cloudwatch_log_group" "jenkins" {
  name              = "/aws/ec2/jenkins"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-${var.environment}-logs"
  }
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.jenkins.id
  }
}

resource "aws_cloudwatch_metric_alarm" "instance_health" {
  alarm_name          = "${var.project_name}-${var.environment}-health-check"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "0"
  alarm_description   = "This metric monitors instance health checks"
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.jenkins.id
  }
}
