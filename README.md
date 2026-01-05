# Highly Available Web Application - Terraform Infrastructure

A production-ready, modular Terraform configuration for deploying a highly available web application on AWS.

## Architecture Overview

This infrastructure deploys a highly available,scalable web application with the following components:

```
Internet
    │
    ▼
┌─────────────────────────────────────────────────┐
│  Application Load Balancer (Public Subnets)    │
│         AZ-1          │         AZ-2            │
└─────────────────────────────────────────────────┘
    │                   │
    ▼                   ▼
┌─────────────────────────────────────────────────┐
│    Auto Scaling Group (Private Subnets)        │
│   EC2 Instances   │   EC2 Instances             │
│       AZ-1         │        AZ-2                 │
└─────────────────────────────────────────────────┘
    │                   │
    ▼                   ▼
┌─────────────────────────────────────────────────┐
│      RDS Multi-AZ (Database Subnets)            │
│    Primary (AZ-1)  │  Standby (AZ-2)            │
└─────────────────────────────────────────────────┘
```

### Key Features

✅ **High Availability**: Multi-AZ deployment across 2 availability zones
✅ **Auto Scaling**: Dynamic scaling based on CPU utilization
✅ **Load Balancing**: Application Load Balancer with health checks
✅ **Database**: RDS Multi-AZ with automated backups
✅ **Security**: Private subnets for application tier, isolated database layer
✅ **Monitoring**: CloudWatch alarms and metrics
✅ **NAT Gateway**: Secure outbound internet access for private instances

## Components

### 1. VPC Module (`modules/vpc/`)
- **VPC** with DNS support and hostnames
- **Public Subnets** (2 AZs) - for ALB
- **Private Subnets** (2 AZs) - for EC2 instances
- **Database Subnets** (2 AZs) - for RDS
- **Internet Gateway** for public subnet access
- **NAT Gateways** (configurable: 1 or 2) for private subnet outbound
- **Route Tables** for proper traffic routing
- **VPC Flow Logs** for network monitoring

### 2. Security Module (`modules/security/`)
- **ALB Security Group**: HTTP/HTTPS from internet
- **EC2 Security Group**: Traffic only from ALB
- **RDS Security Group**: Traffic only from EC2 instances
- **VPC Endpoints Security Group**: For AWS service access

### 3. ALB Module (`modules/alb/`)
- **Application Load Balancer** in public subnets
- **Target Group** with health checks
- **HTTP Listener** (HTTPS optional with ACM certificate)
- **CloudWatch Alarms** for response time and unhealthy hosts

### 4. Auto Scaling Group Module (`modules/asg/`)
- **Launch Template** with latest Amazon Linux 2023 AMI
- **Auto Scaling Group** across multiple AZs
- **Scaling Policies**: Scale up/down based on CPU
- **CloudWatch Alarms** for CPU utilization
- **IAM Roles**: CloudWatch Agent and SSM access
- **User Data**: Apache web server installation

### 5. RDS Module (`modules/rds/`)
- **RDS Instance** (MySQL or PostgreSQL)
- **Multi-AZ Deployment** for high availability
- **DB Subnet Group** in isolated subnets
- **Parameter Group** with optimized settings
- **Automated Backups** with configurable retention
- **Enhanced Monitoring** and Performance Insights
- **CloudWatch Alarms** for CPU, storage, memory, connections

## Prerequisites

- **Terraform** >= 1.0
- **AWS CLI** configured with appropriate credentials
- **AWS Account** with sufficient permissions
- **EC2 Key Pair** (optional, for SSH access)

## Quick Start

### 1. Clone and Configure

```bash
# Clone the repository
cd terraform-ha-webapp

# Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
```

### 2. Update `terraform.tfvars`

```hcl
# Minimum required changes
aws_region   = "us-east-1"
db_username  = "admin"
db_password  = "YourSecurePassword123!"  # Use AWS Secrets Manager in production
key_name     = "your-ec2-keypair"        # Optional
```

### 3. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

### 4. Access Your Application

After successful deployment, Terraform will output the ALB DNS name:

```bash
terraform output application_url
# Output: http://ha-webapp-prod-alb-1234567890.us-east-1.elb.amazonaws.com
```

## Configuration Options

### NAT Gateway Options

**Option 1: Single NAT Gateway (Cost Effective)**
```hcl
enable_nat_gateway = true
single_nat_gateway = true  # ~$32/month
```

**Option 2: Multi-AZ NAT Gateways (High Availability)**
```hcl
enable_nat_gateway = true
single_nat_gateway = false  # ~$64/month (2 NATs)
```

### Auto Scaling Configuration

```hcl
asg_min_size         = 2    # Minimum instances
asg_max_size         = 6    # Maximum instances
asg_desired_capacity = 2    # Initial instances
```

### Database Configuration

**MySQL (Default)**
```hcl
db_engine         = "mysql"
db_engine_version = "8.0"
db_instance_class = "db.t3.micro"
db_multi_az       = true
```

**PostgreSQL**
```hcl
db_engine         = "postgres"
db_engine_version = "15"
db_instance_class = "db.t3.micro"
db_multi_az       = true
```

## Interview Questions & Answers

### Why ALB instead of NLB?

**Application Load Balancer (ALB)** is chosen for this web application because:

1. **Layer 7 (HTTP/HTTPS)**: ALB operates at the application layer, providing:
   - Path-based routing (`/api/*`, `/admin/*`)
   - Host-based routing (multiple domains)
   - HTTP header inspection
   - WebSocket support

2. **Advanced Health Checks**: 
   - Can check specific endpoints (`/health`)
   - Validates HTTP response codes
   - More granular than NLB's TCP checks

3. **Content-Based Routing**: Can route based on:
   - URL paths
   - HTTP headers
   - Query strings
   - Source IP

4. **SSL/TLS Termination**: Offloads SSL processing from instances

**When to use NLB**:
- Ultra-low latency requirements (<1ms)
- Static IP addresses needed
- TCP/UDP traffic (not HTTP/HTTPS)
- Extreme performance (millions of requests/sec)

### How Health Checks Work

**ALB Health Checks**:
```hcl
health_check {
  path     = "/health"
  interval = 30          # Check every 30 seconds
  timeout  = 5           # 5 second timeout
  healthy_threshold   = 2   # 2 consecutive successes = healthy
  unhealthy_threshold = 2   # 2 consecutive failures = unhealthy
  matcher  = "200"      # Expected HTTP status code
}
```

**Process**:
1. ALB sends HTTP GET to `/health` every 30 seconds
2. Instance must respond with HTTP 200 within 5 seconds
3. After 2 consecutive successes (60 seconds), instance is marked healthy
4. After 2 consecutive failures (60 seconds), instance is marked unhealthy
5. Unhealthy instances are removed from target group
6. No new traffic sent to unhealthy instances

**ASG Health Checks**:
```hcl
health_check_type          = "ELB"  # Use ALB health check
health_check_grace_period  = 300    # Wait 5 minutes before checking
```

- ASG monitors ALB health check status
- Automatically terminates and replaces unhealthy instances
- Grace period allows instance to fully initialize

### How Auto Scaling Reacts to Load

**Scaling Policies**:

1. **Scale Up** (CPU > 70% for 4 minutes):
   ```
   Trigger: CPU > 70%
   Evaluation: 2 periods × 120 seconds = 4 minutes
   Action: Add 1 instance
   Cooldown: 300 seconds (5 minutes)
   ```

2. **Scale Down** (CPU < 20% for 4 minutes):
   ```
   Trigger: CPU < 20%
   Evaluation: 2 periods × 120 seconds = 4 minutes
   Action: Remove 1 instance
   Cooldown: 300 seconds (5 minutes)
   ```

**Scaling Process**:
1. CloudWatch monitors CPU metrics every 60 seconds
2. Alarm evaluates average CPU over 120-second periods
3. After 2 consecutive periods above/below threshold → ALARM state
4. Scaling policy triggered
5. New instance launched (or terminated)
6. 5-minute cooldown prevents rapid scaling
7. New instance registers with ALB
8. Health check validation (300-second grace period)
9. Instance receives traffic

**Benefits**:
- Automatic capacity adjustment
- Cost optimization (scale down when idle)
- Performance maintenance (scale up under load)
- No manual intervention required

### How Private Subnets Are Secured

**Network Isolation**:

1. **No Direct Internet Access**:
   - Private subnets have no Internet Gateway route
   - Cannot receive unsolicited inbound connections
   - Protected from direct internet attacks

2. **NAT Gateway for Outbound**:
   ```
   Private Subnet → NAT Gateway → Internet Gateway → Internet
   ```
   - Allows instances to download updates
   - Initiate outbound connections only
   - NAT Gateway in public subnet handles translation

3. **Security Group Layers**:
   ```
   Internet → ALB SG (80, 443 from 0.0.0.0/0)
        ↓
   ALB → EC2 SG (80, 443 from ALB SG only)
        ↓
   EC2 → RDS SG (3306/5432 from EC2 SG only)
   ```

4. **Defense in Depth**:
   - **Network ACLs**: Subnet-level firewall (stateless)
   - **Security Groups**: Instance-level firewall (stateful)
   - **IAM Roles**: No hardcoded credentials
   - **VPC Flow Logs**: Network traffic monitoring
   - **Database Encryption**: Data at rest and in transit

5. **Access Methods**:
   - **AWS Systems Manager (SSM)**: No SSH keys needed
   - **Bastion Host**: Optional jumpbox in public subnet
   - **VPN/Direct Connect**: Corporate network access

**Database Security**:
- Isolated in database subnets
- No internet route (uses NAT for patches)
- Accepts connections only from EC2 security group
- Encrypted at rest and in transit
- Automated backups to S3
- Multi-AZ for automatic failover

## Cost Estimation

**Monthly Cost Breakdown** (us-east-1, approximate):

| Resource | Configuration | Monthly Cost |
|----------|---------------|--------------|
| VPC | Free | $0 |
| NAT Gateway (1) | $0.045/hour | $32.40 |
| NAT Gateway (2) | $0.045/hour × 2 | $64.80 |
| ALB | $0.0225/hour + LCU | $22 - $30 |
| EC2 (t3.micro × 2) | $0.0104/hour × 2 | $15.20 |
| RDS (db.t3.micro) | $0.017/hour | $12.24 |
| RDS Multi-AZ | $0.034/hour | $24.48 |
| EBS Storage (20GB) | $0.10/GB | $2.00 |
| **Total (1 NAT)** | | **~$84/month** |
| **Total (2 NAT)** | | **~$116/month** |

**Note**: Costs exclude data transfer and may vary by region.

## Monitoring & Maintenance

### CloudWatch Alarms

The infrastructure includes pre-configured alarms:

**ALB Alarms**:
- High response time (>1 second)
- Unhealthy host count (>0)

**ASG Alarms**:
- High CPU utilization (>70%)
- Low CPU utilization (<20%)

**RDS Alarms**:
- High CPU utilization (>80%)
- Low storage space (<2GB)
- Low memory (<256MB)
- High connection count (>80)

### View Metrics

```bash
# Get ALB DNS
terraform output application_url

# View Auto Scaling Group status
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $(terraform output -raw asg_name)

# View RDS status
aws rds describe-db-instances \
  --db-instance-identifier $(terraform output -raw rds_instance_id)
```

## Security Best Practices

### Implemented

✅ Private subnets for application and database tiers
✅ Security groups with least privilege
✅ IAM roles instead of access keys
✅ Encrypted RDS storage
✅ VPC Flow Logs
✅ Multi-AZ deployment
✅ Automated backups

### Recommended for Production

🔒 **AWS Secrets Manager** for database credentials
🔒 **ACM Certificate** for HTTPS/TLS
🔒 **WAF** on ALB for application protection
🔒 **GuardDuty** for threat detection
🔒 **AWS Config** for compliance monitoring
🔒 **CloudTrail** for audit logging
🔒 **KMS** for encryption key management
🔒 **Bastion Host** or **SSM Session Manager** for access

## Disaster Recovery

### RDS Backups

- **Automated Backups**: Daily snapshots, 7-day retention
- **Point-in-Time Recovery**: Restore to any second within retention period
- **Final Snapshot**: Created before deletion (configurable)

### Recovery Procedures

**Instance Failure**:
- Auto Scaling automatically replaces unhealthy instances
- Health check identifies failures within 60-120 seconds
- New instance launched within 2-5 minutes

**AZ Failure**:
- Instances in other AZ continue serving traffic
- RDS automatically fails over to standby (1-2 minutes)
- Auto Scaling launches replacement instances in healthy AZ

**Region Failure**:
- Requires cross-region replication setup (not included)
- Manual failover to DR region
- Recommended: Implement AWS Backup for cross-region copies

## Troubleshooting

### Application Not Accessible

```bash
# 1. Check ALB status
aws elbv2 describe-load-balancers \
  --load-balancer-arns $(terraform output -raw alb_arn)

# 2. Check target health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)

# 3. Check Security Groups
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw alb_security_group_id)

# 4. View instance logs (if SSM enabled)
aws ssm start-session --target <instance-id>
```

### Database Connection Issues

```bash
# Test from EC2 instance
mysql -h <rds-endpoint> -u admin -p

# Check RDS security group
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw rds_security_group_id)
```

### Auto Scaling Not Working

```bash
# View scaling activities
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name $(terraform output -raw asg_name) \
  --max-records 20

# Check CloudWatch alarms
aws cloudwatch describe-alarms \
  --alarm-name-prefix ha-webapp-prod
```

## Cleanup

To destroy all resources:

```bash
# WARNING: This will delete all resources including databases
terraform destroy

# If RDS deletion protection is enabled
# 1. Disable in AWS Console or via Terraform
# 2. Run destroy again
```

**Note**: RDS final snapshot will be created unless `skip_final_snapshot = true`.

## Module Customization

Each module can be used independently:

```hcl
module "vpc" {
  source = "./modules/vpc"
  # ... variables
}
```

## Contributing

When making changes:

1. Update module documentation
2. Run `terraform fmt` to format code
3. Run `terraform validate` to check syntax
4. Test in non-production environment first
5. Update this README if architecture changes

## Support

For issues or questions:
- Review AWS documentation
- Check CloudWatch Logs
- Examine VPC Flow Logs
- Review Security Group rules
- Verify IAM permissions

## License

This code is provided as-is for educational and production use.

---

**Deployed with ❤️ using Terraform**
