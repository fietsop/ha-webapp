# Jenkins Server on Amazon Linux - Terraform Automation

Complete Terraform automation for deploying a production-ready Jenkins CI/CD server on Amazon Linux 2023.

## 🎯 What This Does

Automatically provisions a complete Jenkins server with:

- ✅ **Amazon Linux 2023** EC2 instance
- ✅ **Jenkins LTS** - Latest stable version
- ✅ **Java 17** - Amazon Corretto OpenJDK
- ✅ **Git** - Pre-installed for repository access
- ✅ **Docker** (optional) - For containerized builds
- ✅ **Nginx** (optional) - Reverse proxy for Jenkins
- ✅ **CloudWatch Monitoring** - Logs and metrics
- ✅ **IAM Roles** - Secure AWS service access
- ✅ **Security Groups** - Configured firewall rules
- ✅ **Elastic IP** - Consistent public IP address

## 🏗️ Architecture

```
Internet
   │
   ▼
Security Group (Ports: 22, 8080, 80, 443)
   │
   ▼
EC2 Instance (Amazon Linux 2023)
   ├─ Jenkins (Port 8080)
   ├─ Java 17 (Amazon Corretto)
   ├─ Git
   ├─ Docker (optional)
   ├─ Nginx (optional - Port 80)
   └─ CloudWatch Agent
```

## 📋 Prerequisites

### Required:
- **Terraform** >= 1.0 installed
- **AWS CLI** configured with credentials
- **AWS Account** with appropriate permissions
- **EC2 Key Pair** (optional, for SSH access)

### Permissions Needed:
```
ec2:*
iam:CreateRole
iam:AttachRolePolicy
iam:CreateInstanceProfile
ssm:PutParameter
logs:CreateLogGroup
cloudwatch:PutMetricAlarm
```

## 🚀 Quick Start (5 Minutes)

### 1. Clone/Download Project
```bash
cd jenkins-terraform
```

### 2. Configure Variables
Edit `terraform.tfvars`:

```hcl
# Minimum required changes
aws_region = "us-east-1"
key_name   = "my-keypair"  # Your EC2 key pair name

# IMPORTANT: Restrict access to your IP
allowed_ssh_cidr_blocks     = ["YOUR.IP.ADDRESS/32"]
allowed_jenkins_cidr_blocks = ["YOUR.IP.ADDRESS/32"]
```

Get your IP:
```bash
curl https://checkip.amazonaws.com
```

### 3. Deploy
```bash
# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Deploy (~5 minutes)
terraform apply
```

### 4. Access Jenkins
After deployment completes, Terraform will show:

```
jenkins_url = "http://34.XXX.XXX.XXX:8080"
```

### 5. Get Initial Password
```bash
# Method 1: Via AWS CLI
aws ssm get-parameter \
  --name /jenkins/prod/jenkins-initial-password \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text

# Method 2: Via SSH
ssh -i ~/.ssh/my-keypair.pem ec2-user@<JENKINS-IP>
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

# Method 3: From Terraform output
terraform output get_password_command
```

### 6. Complete Jenkins Setup
1. Open Jenkins URL in browser
2. Enter initial admin password
3. Click "Install suggested plugins"
4. Create admin user
5. Start using Jenkins!

## 📁 Project Structure

```
jenkins-terraform/
├── main.tf              # Main Terraform configuration
├── variables.tf         # Input variables
├── outputs.tf           # Output values
├── terraform.tfvars     # Your configuration
├── .gitignore          # Git ignore rules
└── README.md           # This file
```

## ⚙️ Configuration Options

### Instance Sizing

```hcl
# For small teams (default)
instance_type    = "t3.medium"   # 2 vCPU, 4GB RAM
root_volume_size = 30            # GB

# For medium teams
instance_type    = "t3.large"    # 2 vCPU, 8GB RAM
root_volume_size = 50            # GB

# For large teams
instance_type    = "m5.xlarge"   # 4 vCPU, 16GB RAM
root_volume_size = 100           # GB
```

### Optional Features

```hcl
# Install Docker (recommended)
install_docker = true

# Install Nginx reverse proxy
install_nginx = true
domain_name   = "jenkins.yourdomain.com"

# Allocate Elastic IP (recommended)
allocate_elastic_ip = true

# Enable AWS Backup
enable_backup         = true
backup_retention_days = 14
```

### Security Configuration

```hcl
# Restrict to your office IP
allowed_ssh_cidr_blocks = ["203.0.113.0/24"]
allowed_jenkins_cidr_blocks = ["203.0.113.0/24"]

# Or restrict to single IP
allowed_ssh_cidr_blocks = ["203.0.113.45/32"]
allowed_jenkins_cidr_blocks = ["203.0.113.45/32"]

# Multiple IPs
allowed_ssh_cidr_blocks = [
  "203.0.113.45/32",  # Office
  "198.51.100.23/32"  # Home
]
```

## 📊 What Gets Created

| Resource | Description | Count |
|----------|-------------|-------|
| EC2 Instance | Jenkins server | 1 |
| Elastic IP | Static IP address | 0-1 |
| Security Group | Firewall rules | 1 |
| IAM Role | Instance permissions | 1 |
| IAM Instance Profile | Attach role to instance | 1 |
| IAM Policies | AWS service access | 3 |
| CloudWatch Log Group | Log aggregation | 1 |
| CloudWatch Alarms | Monitoring alerts | 2 |
| **Total Resources** | | **10-11** |

## 💰 Cost Estimation

### Monthly Costs (us-east-1):

| Resource | Configuration | Monthly Cost |
|----------|---------------|--------------|
| EC2 (t3.medium) | 2 vCPU, 4GB RAM | ~$30 |
| EBS Storage (30GB) | gp3 volume | ~$2.40 |
| Elastic IP | If allocated | ~$3.60 |
| Data Transfer | 1GB out/month | ~$0.09 |
| CloudWatch | Logs + Alarms | ~$2 |
| **Total** | | **~$38/month** |

**Cost Savings:**
- Use `t3.small` for dev/test: ~$15/month
- Reserved Instance (1-year): Save 40%
- Spot Instance: Save 70% (but less reliable)
- Turn off during non-business hours: Save 50%

## 🔧 Post-Deployment Tasks

### 1. Security Hardening

```bash
# SSH into instance
ssh -i ~/.ssh/my-keypair.pem ec2-user@<JENKINS-IP>

# Update security settings in Jenkins UI
# Navigate to: Manage Jenkins → Configure Global Security
# - Enable "Prevent Cross Site Request Forgery exploits"
# - Configure authorization strategy
# - Set up authentication (LDAP, GitHub OAuth, etc.)
```

### 2. Install Additional Plugins

Essential plugins to install:

- **Git Plugin** - For Git integration
- **GitHub Plugin** - For GitHub integration
- **Pipeline Plugin** - For Jenkins pipelines
- **Docker Plugin** - For Docker builds
- **AWS Steps Plugin** - For AWS deployments
- **Blue Ocean** - Modern UI
- **Slack Notification** - Team notifications

### 3. Configure Build Tools

```bash
# Inside Jenkins instance
sudo dnf install -y maven  # For Java projects
sudo dnf install -y nodejs # For Node.js projects
```

Or configure in Jenkins:
- **Manage Jenkins** → **Global Tool Configuration**
- Add Maven, Node.js, etc.

### 4. Set Up Backups

Enable automatic backups:

```hcl
# In terraform.tfvars
enable_backup         = true
backup_retention_days = 14
backup_schedule       = "cron(0 2 * * ? *)"  # Daily at 2 AM
```

Or manual backup script:
```bash
#!/bin/bash
# Backup Jenkins home
tar -czf jenkins-backup-$(date +%Y%m%d).tar.gz \
  --exclude=/var/lib/jenkins/workspace \
  --exclude=/var/lib/jenkins/war \
  /var/lib/jenkins

# Upload to S3
aws s3 cp jenkins-backup-$(date +%Y%m%d).tar.gz \
  s3://my-jenkins-backups/
```

### 5. Configure HTTPS (Recommended for Production)

```bash
# Install Certbot for Let's Encrypt
sudo dnf install -y certbot python3-certbot-nginx

# Get SSL certificate
sudo certbot --nginx -d jenkins.yourdomain.com

# Configure auto-renewal
sudo systemctl enable --now certbot-renew.timer
```

## 🧪 Testing

### Verify Jenkins is Running

```bash
# Check service status
ssh -i ~/.ssh/my-keypair.pem ec2-user@<JENKINS-IP>
sudo systemctl status jenkins

# Check logs
sudo journalctl -u jenkins -f

# Test HTTP access
curl http://localhost:8080
```

### Create Test Job

1. **Jenkins Dashboard** → **New Item**
2. Name: `test-job`
3. Type: **Freestyle project**
4. Build step: **Execute shell**
   ```bash
   echo "Hello from Jenkins!"
   date
   hostname
   ```
5. **Save** and **Build Now**

### Test Docker Integration

```bash
# Inside Jenkins
docker run hello-world

# Verify jenkins user can run Docker
sudo -u jenkins docker ps
```

## 📈 Monitoring

### CloudWatch Dashboards

View metrics in AWS Console:
- **CloudWatch** → **Dashboards**
- Create dashboard for:
  - CPU Utilization
  - Disk Usage
  - Memory Usage
  - Network In/Out

### CloudWatch Alarms

Pre-configured alarms:
- **High CPU**: Alert when CPU > 80% for 10 minutes
- **Instance Health**: Alert on status check failures

### View Logs

```bash
# Via CloudWatch
aws logs tail /aws/ec2/jenkins --follow

# Via SSH
ssh -i ~/.ssh/my-keypair.pem ec2-user@<JENKINS-IP>
sudo tail -f /var/log/jenkins/jenkins.log
sudo tail -f /var/log/user-data.log  # Installation logs
```

## 🔄 Updates and Maintenance

### Update Jenkins

```bash
# SSH into instance
ssh -i ~/.ssh/my-keypair.pem ec2-user@<JENKINS-IP>

# Update Jenkins
sudo dnf update jenkins -y

# Restart Jenkins
sudo systemctl restart jenkins
```

### Update Terraform Infrastructure

```bash
# Make changes to terraform files
vim terraform.tfvars

# Review changes
terraform plan

# Apply changes
terraform apply
```

### Backup Before Updates

```bash
# Manual backup
ssh -i ~/.ssh/my-keypair.pem ec2-user@<JENKINS-IP>
sudo tar -czf /tmp/jenkins-backup.tar.gz /var/lib/jenkins

# Download backup
scp -i ~/.ssh/my-keypair.pem \
  ec2-user@<JENKINS-IP>:/tmp/jenkins-backup.tar.gz \
  ./jenkins-backup-$(date +%Y%m%d).tar.gz
```

## 🆘 Troubleshooting

### Jenkins Won't Start

```bash
# Check logs
sudo journalctl -u jenkins -n 100 --no-pager

# Check Java
java -version

# Check Jenkins status
sudo systemctl status jenkins

# Restart Jenkins
sudo systemctl restart jenkins
```

### Can't Access Jenkins UI

```bash
# 1. Verify instance is running
aws ec2 describe-instances \
  --instance-ids $(terraform output -raw instance_id) \
  --query 'Reservations[0].Instances[0].State.Name'

# 2. Check Security Group
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw security_group_id)

# 3. Test from instance
ssh -i ~/.ssh/my-keypair.pem ec2-user@<JENKINS-IP>
curl http://localhost:8080

# 4. Check firewall
sudo firewall-cmd --list-all  # If using firewalld
```

### Out of Disk Space

```bash
# Check disk usage
df -h

# Clean Jenkins workspace
sudo rm -rf /var/lib/jenkins/workspace/*

# Clean old builds (be careful!)
sudo find /var/lib/jenkins/jobs -type d -name builds -exec rm -rf {} \;

# Increase volume size
# Edit terraform.tfvars
root_volume_size = 50  # Increase from 30 to 50

# Apply changes
terraform apply
```

### High Memory Usage

```bash
# Increase Jenkins heap size
sudo vim /usr/lib/systemd/system/jenkins.service

# Add to [Service] section:
Environment="JAVA_OPTS=-Xms1024m -Xmx2048m"

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart jenkins
```

## 🔒 Security Best Practices

### Implemented by Default:
✅ Security Groups with restricted access
✅ IAM roles (no hardcoded credentials)
✅ Encrypted EBS volumes
✅ IMDSv2 (metadata protection)
✅ CloudWatch logging
✅ Automated backups (optional)

### Recommended Additional Steps:
🔐 **Enable HTTPS** with SSL certificate
🔐 **Restrict Security Groups** to specific IPs
🔐 **Configure Authentication** (LDAP, SSO, OAuth)
🔐 **Enable Audit Logging** in Jenkins
🔐 **Regular Updates** of Jenkins and plugins
🔐 **Secrets Management** using AWS Secrets Manager
🔐 **Multi-Factor Authentication** for admin users
🔐 **Regular Security Scans** of Jenkins instance

### Security Checklist:
- [ ] Changed default admin password
- [ ] Restricted Security Group to trusted IPs
- [ ] Configured authentication provider
- [ ] Enabled HTTPS/SSL
- [ ] Set up regular backups
- [ ] Configured audit logging
- [ ] Updated all plugins
- [ ] Reviewed IAM permissions
- [ ] Enabled MFA for admin accounts
- [ ] Documented security procedures

## 🗑️ Cleanup

### Destroy Everything

```bash
# WARNING: This will delete Jenkins and all data
terraform destroy

# Confirm with: yes
```

### Preserve Data Before Destroying

```bash
# 1. Create AMI from instance
aws ec2 create-image \
  --instance-id $(terraform output -raw instance_id) \
  --name "jenkins-backup-$(date +%Y%m%d)" \
  --description "Jenkins backup before destroy"

# 2. Backup to S3
ssh -i ~/.ssh/my-keypair.pem ec2-user@<JENKINS-IP>
sudo tar -czf /tmp/jenkins-data.tar.gz /var/lib/jenkins
aws s3 cp /tmp/jenkins-data.tar.gz s3://my-backups/

# 3. Now safe to destroy
terraform destroy
```

## 📚 Additional Resources

- **Jenkins Documentation**: https://www.jenkins.io/doc/
- **Jenkins Plugins**: https://plugins.jenkins.io/
- **Pipeline Syntax**: https://www.jenkins.io/doc/book/pipeline/syntax/
- **AWS Best Practices**: https://docs.aws.amazon.com/

## 🤝 Common Use Cases

### CI/CD for Node.js Application

```groovy
pipeline {
    agent any
    stages {
        stage('Checkout') {
            steps {
                git 'https://github.com/yourorg/yourapp.git'
            }
        }
        stage('Build') {
            steps {
                sh 'npm install'
                sh 'npm run build'
            }
        }
        stage('Test') {
            steps {
                sh 'npm test'
            }
        }
        stage('Deploy') {
            steps {
                sh 'aws s3 sync dist/ s3://your-bucket/'
            }
        }
    }
}
```

### Docker Build and Push

```groovy
pipeline {
    agent any
    stages {
        stage('Build Image') {
            steps {
                sh 'docker build -t myapp:${BUILD_NUMBER} .'
            }
        }
        stage('Push to ECR') {
            steps {
                sh '''
                    aws ecr get-login-password | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
                    docker tag myapp:${BUILD_NUMBER} <account-id>.dkr.ecr.us-east-1.amazonaws.com/myapp:${BUILD_NUMBER}
                    docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/myapp:${BUILD_NUMBER}
                '''
            }
        }
    }
}
```

## 🎓 Next Steps

1. ✅ Deploy Jenkins server
2. ✅ Access Jenkins UI
3. 🔲 Install required plugins
4. 🔲 Configure build tools
5. 🔲 Create your first pipeline
6. 🔲 Set up GitHub webhooks
7. 🔲 Configure notifications
8. 🔲 Enable HTTPS
9. 🔲 Set up monitoring alerts
10. 🔲 Document your pipelines

---

**Need Help?**
- Check the troubleshooting section above
- Review Jenkins logs in CloudWatch
- Consult Jenkins documentation
- Review AWS documentation for EC2/IAM issues

**Deployed with ❤️ using Terraform**
