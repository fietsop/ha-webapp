# Deployment Guide

## Step-by-Step Deployment

### Prerequisites Checklist

- [ ] Terraform installed (v1.0 or higher)
- [ ] AWS CLI installed and configured
- [ ] AWS account with appropriate permissions
- [ ] (Optional) EC2 key pair created for SSH access

### 1. Prepare AWS Credentials

```bash
# Configure AWS CLI
aws configure

# Verify credentials
aws sts get-caller-identity
```

### 2. Clone and Setup

```bash
# Navigate to project directory
cd terraform-ha-webapp

# Initialize Terraform (download providers)
terraform init
```

### 3. Configure Variables

Edit `terraform.tfvars`:

```hcl
# Required Changes
db_username = "admin"
db_password = "YourSecurePassword123!"  # Min 8 characters

# Optional but Recommended
aws_region  = "us-east-1"  # Your preferred region
key_name    = "my-keypair"  # For SSH access
environment = "prod"
```

### 4. Review Infrastructure Plan

```bash
# See what will be created
terraform plan

# Save plan to file
terraform plan -out=tfplan
```

**Expected Resources** (~60 resources):
- 1 VPC
- 6 Subnets (2 public, 2 private, 2 database)
- 1-2 NAT Gateways
- 3 Security Groups
- 1 Application Load Balancer
- 1 Auto Scaling Group
- 1 Launch Template
- 1 RDS Instance
- Multiple CloudWatch Alarms
- IAM Roles and Policies
- Route Tables and Routes

### 5. Deploy Infrastructure

```bash
# Apply the configuration
terraform apply

# Or use saved plan
terraform apply tfplan
```

**Deployment Time**: 15-20 minutes
- VPC and networking: 2-3 minutes
- NAT Gateways: 2-3 minutes
- RDS instance: 10-15 minutes
- Auto Scaling Group: 3-5 minutes

### 6. Verify Deployment

```bash
# Get application URL
terraform output application_url

# Test the application
curl $(terraform output -raw application_url)

# Or open in browser
open $(terraform output -raw application_url)
```

### 7. Check Instance Health

```bash
# Get target group health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn) \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
  --output table
```

Expected output:
```
----------------------------------------
|     DescribeTargetHealth            |
+----------------------+--------------+
|  i-1234567890abcdef0 |  healthy    |
|  i-0987654321fedcba0 |  healthy    |
+----------------------+--------------+
```

## Post-Deployment Configuration

### 1. Enable HTTPS (Recommended)

1. Request ACM certificate:
```bash
aws acm request-certificate \
  --domain-name yourdomain.com \
  --validation-method DNS
```

2. Add certificate ARN to `terraform.tfvars`:
```hcl
certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxx"
```

3. Uncomment HTTPS listener in `modules/alb/main.tf`

4. Apply changes:
```bash
terraform apply
```

### 2. Configure Custom Domain

1. Create Route 53 hosted zone
2. Add ALIAS record pointing to ALB:

```bash
aws route53 change-resource-record-sets \
  --hosted-zone-id Z123456789ABC \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "app.yourdomain.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "'$(terraform output -raw alb_zone_id)'",
          "DNSName": "'$(terraform output -raw alb_dns_name)'",
          "EvaluateTargetHealth": true
        }
      }
    }]
  }'
```

### 3. Set Up Monitoring Alerts

Configure SNS topic for CloudWatch alarms:

```bash
# Create SNS topic
aws sns create-topic --name infrastructure-alerts

# Subscribe email
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:123456789012:infrastructure-alerts \
  --protocol email \
  --notification-endpoint your-email@example.com

# Update alarms to use SNS topic (add to alarm configurations)
```

### 4. Configure Application

SSH into instance (if key configured):

```bash
# Get instance ID
INSTANCE_ID=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $(terraform output -raw asg_name) \
  --query 'AutoScalingGroups[0].Instances[0].InstanceId' \
  --output text)

# Connect via SSM (no SSH key needed)
aws ssm start-session --target $INSTANCE_ID

# Or via SSH (if key configured)
ssh -i ~/.ssh/my-keypair.pem ec2-user@<instance-private-ip>
```

Install your application:
```bash
# Inside instance
cd /var/www/html
sudo git clone https://github.com/your-repo/your-app.git .
sudo systemctl restart httpd
```

## Testing

### 1. Load Testing

```bash
# Install Apache Bench
sudo yum install -y httpd-tools

# Run load test (100 requests, 10 concurrent)
ab -n 100 -c 10 $(terraform output -raw application_url)
```

### 2. Auto Scaling Test

```bash
# Stress test to trigger scaling
# SSH into instance
stress-ng --cpu 4 --timeout 300s

# Watch scaling activity
watch -n 5 'aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $(terraform output -raw asg_name) \
  --query "AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize,Instances[*].InstanceId]"'
```

### 3. Failover Test

```bash
# Terminate instance to test ASG replacement
aws ec2 terminate-instances --instance-ids $INSTANCE_ID

# Watch replacement
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name $(terraform output -raw asg_name) \
  --max-records 5
```

### 4. Database Connection Test

```bash
# From EC2 instance
mysql -h $(terraform output -raw rds_endpoint | cut -d: -f1) \
      -u admin -p \
      -e "SHOW DATABASES;"
```

## Updating Infrastructure

### Making Changes

1. Edit Terraform files
2. Run plan to review changes:
```bash
terraform plan
```

3. Apply changes:
```bash
terraform apply
```

### Common Updates

**Update instance type**:
```hcl
# In terraform.tfvars
instance_type = "t3.small"
```

**Change scaling thresholds**:
```hcl
asg_min_size = 3
asg_max_size = 10
```

**Update RDS instance**:
```hcl
db_instance_class = "db.t3.small"
db_allocated_storage = 50
```

### Blue/Green Deployment

For zero-downtime deployments:

1. Create new launch template version
2. Update ASG to use new template
3. Gradually replace instances:
```bash
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name $(terraform output -raw asg_name)
```

## Backup and Recovery

### Creating Manual Backup

```bash
# Create RDS snapshot
aws rds create-db-snapshot \
  --db-instance-identifier $(terraform output -raw rds_instance_id) \
  --db-snapshot-identifier manual-backup-$(date +%Y%m%d-%H%M%S)
```

### Restoring from Backup

```bash
# List available snapshots
aws rds describe-db-snapshots \
  --db-instance-identifier $(terraform output -raw rds_instance_id)

# Restore (requires Terraform update or manual process)
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier new-instance-id \
  --db-snapshot-identifier snapshot-id
```

## Scaling Strategies

### Vertical Scaling (Instance Size)

```hcl
# terraform.tfvars
instance_type = "t3.medium"  # From t3.micro
db_instance_class = "db.t3.small"  # From db.t3.micro
```

Apply and watch rolling update:
```bash
terraform apply
```

### Horizontal Scaling (Instance Count)

```hcl
# terraform.tfvars
asg_min_size = 4
asg_desired_capacity = 4
```

### Scheduled Scaling

Add to ASG module:
```hcl
# Scale up during business hours
resource "aws_autoscaling_schedule" "scale_up" {
  scheduled_action_name  = "scale-up"
  min_size               = 4
  max_size               = 10
  desired_capacity       = 4
  recurrence             = "0 8 * * MON-FRI"
  autoscaling_group_name = aws_autoscaling_group.main.name
}

# Scale down after hours
resource "aws_autoscaling_schedule" "scale_down" {
  scheduled_action_name  = "scale-down"
  min_size               = 2
  max_size               = 4
  desired_capacity       = 2
  recurrence             = "0 18 * * MON-FRI"
  autoscaling_group_name = aws_autoscaling_group.main.name
}
```

## Troubleshooting

### Issue: Instances Not Healthy

**Check 1**: Health check endpoint
```bash
# From local machine
curl http://<alb-dns>/health

# Should return: OK
```

**Check 2**: Security groups
```bash
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw ec2_security_group_id)
```

**Check 3**: Instance logs
```bash
aws ssm start-session --target $INSTANCE_ID
sudo tail -f /var/log/httpd/error_log
```

### Issue: Cannot Connect to RDS

**Check 1**: Security group rules
```bash
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw rds_security_group_id)
```

**Check 2**: From EC2 instance
```bash
# Test network connectivity
telnet <rds-endpoint> 3306

# Test MySQL connection
mysql -h <rds-endpoint> -u admin -p
```

### Issue: High Costs

**Check 1**: NAT Gateway usage
```bash
# Consider using single NAT
single_nat_gateway = true
```

**Check 2**: Instance hours
```bash
# Check running instances
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,LaunchTime]' \
  --output table
```

**Check 3**: Unused resources
```bash
# Check for unused EBS volumes
aws ec2 describe-volumes \
  --filters "Name=status,Values=available"
```

## Cleanup

### Full Cleanup

```bash
# WARNING: This destroys everything
terraform destroy

# If RDS has deletion protection
aws rds modify-db-instance \
  --db-instance-identifier $(terraform output -raw rds_instance_id) \
  --no-deletion-protection \
  --apply-immediately

# Then destroy
terraform destroy
```

### Partial Cleanup

Disable specific components:

```hcl
# Disable NAT Gateway (keep instances private-only)
enable_nat_gateway = false

# Reduce instance count
asg_desired_capacity = 1
asg_min_size = 1
```

## Best Practices

✅ Always run `terraform plan` before `apply`
✅ Use version control for Terraform code
✅ Store state in S3 with state locking (DynamoDB)
✅ Use AWS Secrets Manager for passwords
✅ Enable CloudTrail for audit logging
✅ Regular backups and disaster recovery testing
✅ Use separate environments (dev, staging, prod)
✅ Implement proper tagging strategy
✅ Monitor costs with AWS Cost Explorer
✅ Review security groups quarterly

## Next Steps

1. ✅ Deploy infrastructure
2. ✅ Verify all components healthy
3. 🔲 Configure custom domain
4. 🔲 Enable HTTPS with ACM certificate
5. 🔲 Set up monitoring alerts
6. 🔲 Deploy your application
7. 🔲 Perform load testing
8. 🔲 Document runbooks
9. 🔲 Schedule regular backups
10. 🔲 Plan disaster recovery exercises

---

**Need Help?**
- AWS Documentation: https://docs.aws.amazon.com
- Terraform Documentation: https://www.terraform.io/docs
- Check CloudWatch Logs for application errors
- Review VPC Flow Logs for network issues
