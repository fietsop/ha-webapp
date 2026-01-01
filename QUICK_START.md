# Highly Available Web Application - Quick Start

## 🎯 What You Have

A complete, production-ready Terraform infrastructure for deploying a highly available web application on AWS.

## 📁 Project Structure

```
terraform-ha-webapp/
├── README.md                    # Complete documentation
├── DEPLOYMENT.md                # Step-by-step deployment guide
├── INTERVIEW_GUIDE.md           # Interview prep with Q&A
├── main.tf                      # Root configuration
├── variables.tf                 # Input variables
├── outputs.tf                   # Output values
├── terraform.tfvars             # Your configuration (edit this!)
├── .gitignore                   # Git ignore rules
└── modules/
    ├── vpc/                     # VPC, subnets, NAT gateways
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── security/                # Security groups
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── alb/                     # Application Load Balancer
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── asg/                     # Auto Scaling Group
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── rds/                     # RDS Database
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## 🚀 Quick Deploy (5 Minutes)

### 1. Prerequisites
```bash
# Install Terraform
brew install terraform  # macOS
# or download from https://www.terraform.io/downloads

# Configure AWS CLI
aws configure
```

### 2. Configure
Edit `terraform.tfvars`:
```hcl
aws_region   = "us-east-1"
db_username  = "admin"
db_password  = "YourSecurePassword123!"  # Change this!
```

### 3. Deploy
```bash
cd terraform-ha-webapp

# Initialize
terraform init

# Review plan
terraform plan

# Deploy
terraform apply
```

### 4. Access Application
```bash
# Get URL
terraform output application_url

# Test
curl $(terraform output -raw application_url)
```

## 🏗️ Architecture

```
                    Internet
                       │
                       ▼
        ┌──────────────────────────┐
        │  Application Load        │
        │  Balancer (ALB)          │
        │  Public Subnets          │
        │  (Multi-AZ)              │
        └──────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────┐
        │  Auto Scaling Group      │
        │  EC2 Instances           │
        │  Private Subnets         │
        │  (Multi-AZ)              │
        └──────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────┐
        │  RDS Database            │
        │  Multi-AZ                │
        │  Database Subnets        │
        └──────────────────────────┘
```

## ✨ Key Features

- ✅ **High Availability**: 2 Availability Zones
- ✅ **Auto Scaling**: 2-6 instances based on CPU
- ✅ **Load Balancing**: Application Load Balancer
- ✅ **Database**: RDS Multi-AZ with backups
- ✅ **Security**: Private subnets, Security Groups
- ✅ **Monitoring**: CloudWatch alarms
- ✅ **Modular**: Reusable Terraform modules

## 📊 Resources Created

| Category | Resources | Count |
|----------|-----------|-------|
| Networking | VPC, Subnets, NAT Gateways, IGW | ~15 |
| Compute | ALB, ASG, Launch Template | ~8 |
| Database | RDS, DB Subnet Group | ~5 |
| Security | Security Groups, IAM Roles | ~6 |
| Monitoring | CloudWatch Alarms | ~10 |
| **Total** | | **~60** |

## 💰 Estimated Cost

| Resource | Monthly Cost |
|----------|--------------|
| NAT Gateway (×2) | $64.80 |
| ALB | $22-30 |
| EC2 (t3.micro ×2) | $15.20 |
| RDS (db.t3.micro Multi-AZ) | $24.48 |
| **Total** | **~$116/month** |

**Cost Saving Options:**
- Single NAT Gateway: Save $32/month
- Reserved Instances: Save 40-60%
- Auto-scaling: Pay only for what you use

## 🎓 Interview Preparation

### Must-Know Topics

1. **Why ALB instead of NLB?**
   - Layer 7 (HTTP) vs Layer 4 (TCP)
   - Content-based routing
   - Advanced health checks

2. **How do health checks work?**
   - Interval, timeout, thresholds
   - ELB vs EC2 health checks
   - Recovery process

3. **How does Auto Scaling react to load?**
   - CloudWatch metrics
   - Scaling policies
   - Cooldown periods

4. **How are private subnets secured?**
   - No Internet Gateway route
   - NAT Gateway for outbound
   - Security group layers
   - Defense in depth

**Full Q&A:** See `INTERVIEW_GUIDE.md`

## 📚 Documentation

| File | Purpose |
|------|---------|
| `README.md` | Complete architecture docs |
| `DEPLOYMENT.md` | Step-by-step deployment |
| `INTERVIEW_GUIDE.md` | Interview Q&A prep |
| This file | Quick reference |

## 🔧 Common Commands

```bash
# Initialize Terraform
terraform init

# Check formatting
terraform fmt

# Validate configuration
terraform validate

# Plan changes
terraform plan

# Apply changes
terraform apply

# Show current state
terraform show

# List outputs
terraform output

# Destroy everything
terraform destroy
```

## 🧪 Testing

### Health Check
```bash
curl http://<alb-dns>/health
# Should return: OK
```

### Load Test
```bash
ab -n 1000 -c 50 http://<alb-dns>/
```

### View Instance Health
```bash
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)
```

## 🔐 Security Checklist

- [ ] Update `db_password` in terraform.tfvars
- [ ] Restrict `allowed_cidr_blocks` (not 0.0.0.0/0)
- [ ] Add your SSH key to `key_name`
- [ ] Enable deletion protection for RDS
- [ ] Configure HTTPS with ACM certificate
- [ ] Set up CloudWatch alarms with SNS
- [ ] Review security group rules
- [ ] Enable CloudTrail
- [ ] Configure AWS Secrets Manager

## 🚨 Troubleshooting

**Application not accessible?**
```bash
# Check ALB status
aws elbv2 describe-load-balancers

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)

# Check security groups
aws ec2 describe-security-groups
```

**Database connection failed?**
```bash
# Test from EC2 instance
mysql -h <rds-endpoint> -u admin -p

# Check RDS status
aws rds describe-db-instances
```

**Auto Scaling not working?**
```bash
# View scaling activities
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name $(terraform output -raw asg_name)

# Check CloudWatch alarms
aws cloudwatch describe-alarms
```

## 🎯 Next Steps

1. ✅ Deploy infrastructure
2. 🔲 Test application access
3. 🔲 Configure custom domain
4. 🔲 Enable HTTPS
5. 🔲 Deploy your application
6. 🔲 Set up monitoring alerts
7. 🔲 Perform load testing
8. 🔲 Review security
9. 🔲 Plan disaster recovery
10. 🔲 Practice interview answers

## 📞 Support Resources

- **AWS Docs**: https://docs.aws.amazon.com
- **Terraform Docs**: https://www.terraform.io/docs
- **This Project**: See README.md and other docs

## 📝 Notes

- Default region: us-east-1
- Default environment: prod
- Min instances: 2
- Max instances: 6
- RDS Multi-AZ: Enabled
- Backups: 7 days retention
- Health check: /health endpoint

---

**🎉 You're ready to deploy! Start with `terraform init`**

**💡 Pro Tip:** Read INTERVIEW_GUIDE.md before your interview!
