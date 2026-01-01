# Interview Preparation Guide

## Architecture Overview

### Quick Summary
A highly available, auto-scaling web application on AWS using:
- **VPC**: Multi-AZ with public/private/database subnets
- **ALB**: Application Load Balancer in public subnets
- **ASG**: Auto Scaling Group with EC2 instances in private subnets
- **RDS**: Multi-AZ MySQL/PostgreSQL database
- **NAT Gateway**: Secure outbound internet access

## Core Interview Questions

### 1. Why ALB Instead of NLB?

**Short Answer:**
ALB operates at Layer 7 (HTTP/HTTPS) and provides application-level features like path-based routing, host-based routing, and HTTP header inspection. NLB operates at Layer 4 (TCP/UDP) for ultra-low latency and static IPs.

**Detailed Answer:**

**Use ALB when you need:**
- HTTP/HTTPS traffic
- Content-based routing (paths, headers, query strings)
- WebSocket and HTTP/2 support
- Authentication integration (Cognito, OIDC)
- Advanced health checks (HTTP status codes, response body)
- SSL/TLS termination
- Sticky sessions (session affinity)

**Example:** Web application with `/api/*` going to backend servers and `/admin/*` going to admin servers.

**Use NLB when you need:**
- Ultra-low latency (<1ms)
- Static IP addresses
- TCP/UDP protocols (non-HTTP)
- Extreme throughput (millions of requests/second)
- Preserve source IP addresses

**Example:** Gaming servers, IoT applications, or VoIP services.

**Our Choice: ALB**
- Web application (HTTP/HTTPS)
- Need health checks on `/health` endpoint
- Future-proof for microservices routing
- SSL termination capability
- Better CloudWatch integration

---

### 2. How Do Health Checks Work?

**ALB Health Check Configuration:**
```hcl
health_check {
  path                = "/health"      # Endpoint to check
  interval            = 30             # Check every 30 seconds
  timeout             = 5              # Response within 5 seconds
  healthy_threshold   = 2              # 2 successes = healthy
  unhealthy_threshold = 2              # 2 failures = unhealthy
  matcher             = "200"          # Expected HTTP status
}
```

**Health Check Flow:**

1. **Initial State**: Instance launches
   ```
   Time 0s: Instance starts
   Time 300s: Health check grace period ends
   Time 300s: First health check initiated
   ```

2. **Becoming Healthy**:
   ```
   Time 300s: Check 1 → HTTP 200 (Success 1)
   Time 330s: Check 2 → HTTP 200 (Success 2)
   → Instance marked HEALTHY
   → Starts receiving traffic
   ```

3. **Becoming Unhealthy**:
   ```
   Time X: Check N → Timeout/500 error (Failure 1)
   Time X+30s: Check N+1 → Timeout/500 error (Failure 2)
   → Instance marked UNHEALTHY
   → Removed from traffic
   → Auto Scaling terminates and replaces
   ```

**Health Check Types:**

1. **ELB Health Check** (Recommended):
   - ALB checks application endpoint
   - More accurate (application-aware)
   - Detects application failures
   - Our configuration: `health_check_type = "ELB"`

2. **EC2 Health Check**:
   - Only checks instance status
   - Misses application failures
   - Less reliable for web apps

**What Makes an Instance Unhealthy?**
- HTTP response code not 200
- Timeout (no response in 5 seconds)
- Connection refused
- Application crash
- Out of memory
- Disk full

**Recovery Process:**
```
Unhealthy detected → ASG terminates instance
→ Launches new instance → User data runs
→ 300s grace period → Health checks start
→ 2 successful checks → Instance healthy
→ Receives traffic
```

**Total Recovery Time:** ~5-7 minutes
- Launch: 2-3 minutes
- Grace period: 5 minutes
- Health checks: 60 seconds (2×30s)

---

### 3. How Does Auto Scaling React to Load?

**Scaling Configuration:**
```hcl
min_size         = 2    # Always >= 2 instances
max_size         = 6    # Never > 6 instances
desired_capacity = 2    # Target 2 instances
```

**Scaling Policies:**

**1. Scale Up Policy (Add Instances)**
```hcl
Trigger: CPU > 70%
Evaluation: 2 periods × 120 seconds = 4 minutes
Action: Add 1 instance
Cooldown: 300 seconds
```

**Flow:**
```
09:00:00 - CPU reaches 75%
09:02:00 - Period 1: Average CPU = 75% (above 70%)
09:04:00 - Period 2: Average CPU = 76% (above 70%)
09:04:00 - ALARM triggered → Scale up initiated
09:04:01 - Launch new instance (desired: 2 → 3)
09:06:30 - New instance healthy and serving traffic
09:09:00 - Cooldown ends (can scale again)
```

**2. Scale Down Policy (Remove Instances)**
```hcl
Trigger: CPU < 20%
Evaluation: 2 periods × 120 seconds = 4 minutes
Action: Remove 1 instance
Cooldown: 300 seconds
```

**Flow:**
```
10:00:00 - Load decreases, CPU drops to 15%
10:02:00 - Period 1: Average CPU = 15% (below 20%)
10:04:00 - Period 2: Average CPU = 16% (below 20%)
10:04:00 - ALARM triggered → Scale down initiated
10:04:01 - Terminate 1 instance (desired: 3 → 2)
10:04:01 - Draining connections (30 seconds)
10:04:31 - Instance terminated
10:09:00 - Cooldown ends
```

**Real-World Scenario:**

**Morning Rush (8 AM)**:
```
8:00 AM - 100 users → CPU: 25% → 2 instances
8:30 AM - 500 users → CPU: 45% → 2 instances (below threshold)
9:00 AM - 1200 users → CPU: 72% → 3 instances (scaled up)
9:15 AM - 2000 users → CPU: 78% → 4 instances (scaled up again)
9:30 AM - 2500 users → CPU: 74% → 4 instances (stable)
```

**Evening Decline (6 PM)**:
```
6:00 PM - 1500 users → CPU: 55% → 4 instances
6:30 PM - 800 users → CPU: 32% → 4 instances (above threshold)
7:00 PM - 300 users → CPU: 18% → 3 instances (scaled down)
7:30 PM - 150 users → CPU: 15% → 2 instances (scaled down to min)
```

**Why Cooldown Period?**
- Prevents rapid scaling (flapping)
- Allows new instances to stabilize
- Prevents cost spikes
- Ensures accurate metrics

**Advanced Scaling (Not Implemented but Good to Know):**
```hcl
# Target Tracking Scaling
resource "aws_autoscaling_policy" "target_tracking" {
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0  # Maintain 50% CPU
  }
}
```

---

### 4. How Are Private Subnets Secured?

**Network Architecture:**
```
Internet
   ↓
Internet Gateway (Public only)
   ↓
Public Subnets (ALB) - 10.0.1.0/24, 10.0.2.0/24
   ↓
Private Subnets (EC2) - 10.0.11.0/24, 10.0.12.0/24
   ↓
Database Subnets (RDS) - 10.0.21.0/24, 10.0.22.0/24
```

**Security Layers:**

**1. Network Isolation**

Private subnets have NO route to Internet Gateway:
```hcl
# Private Route Table
route {
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id  # Not IGW!
}
```

**Benefits:**
- No inbound connections from internet
- Cannot be directly accessed
- Protected from DDoS attacks
- Reduced attack surface

**2. NAT Gateway Pattern**
```
Private Instance → NAT Gateway → Internet Gateway → Internet
                ↑ (Outbound only)
```

**Why NAT Gateway?**
- Instances need to download updates
- Call external APIs
- Send logs to external services
- One-way: Outbound only, no inbound

**Example:** EC2 instance can:
✅ Download yum packages
✅ Call external payment API
✅ Send metrics to DataDog
❌ Receive unsolicited inbound connections

**3. Security Group Layering (Defense in Depth)**

```
┌─────────────────────────────────────────┐
│ ALB Security Group                      │
│ Inbound:                                │
│   - Port 80 from 0.0.0.0/0             │
│   - Port 443 from 0.0.0.0/0            │
│ Outbound:                               │
│   - All traffic                         │
└─────────────────────────────────────────┘
              ↓ (Only traffic from ALB)
┌─────────────────────────────────────────┐
│ EC2 Security Group                      │
│ Inbound:                                │
│   - Port 80 from ALB SG                │
│   - Port 443 from ALB SG               │
│   - Port 22 from VPC CIDR (mgmt)       │
│ Outbound:                               │
│   - All traffic (NAT Gateway)          │
└─────────────────────────────────────────┘
              ↓ (Only traffic from EC2)
┌─────────────────────────────────────────┐
│ RDS Security Group                      │
│ Inbound:                                │
│   - Port 3306 from EC2 SG              │
│ Outbound:                               │
│   - None needed                         │
└─────────────────────────────────────────┘
```

**Key Principle:** Each layer only accepts traffic from the previous layer.

**4. Additional Security Measures**

**VPC Flow Logs:**
```hcl
resource "aws_flow_log" "main" {
  traffic_type = "ALL"  # Logs all network traffic
}
```
- Captures all IP traffic
- Detects suspicious patterns
- Forensic analysis
- Compliance auditing

**IAM Roles (No Keys):**
```hcl
# Instance profile instead of access keys
iam_instance_profile {
  name = aws_iam_instance_profile.ec2_profile.name
}
```
- No hardcoded credentials
- Temporary credentials
- Automatic rotation
- Least privilege access

**Database Encryption:**
```hcl
resource "aws_db_instance" "main" {
  storage_encrypted = true  # Encryption at rest
  # Encryption in transit via SSL/TLS
}
```

**5. Access Methods**

**AWS Systems Manager (SSM) - Recommended:**
```bash
# No SSH keys, no bastion, no public IPs needed
aws ssm start-session --target i-1234567890
```

**Benefits:**
- No SSH keys to manage
- All access logged
- No public IPs needed
- Session recording available

**Bastion Host (Traditional):**
```
Internet → Bastion (Public) → EC2 (Private)
```
- Jump server in public subnet
- Requires SSH key management
- Single point of entry
- All access logged

---

## Additional Important Questions

### 5. Explain Multi-AZ vs Multi-Region

**Multi-AZ (What We Use):**
- Same region, different availability zones
- Synchronous replication (RDS)
- Automatic failover (<1 minute)
- Protects against: AZ failure, datacenter issues
- RDS: Primary in AZ-A, standby in AZ-B

**Multi-Region:**
- Different AWS regions (us-east-1, us-west-2)
- Asynchronous replication
- Manual or automated failover
- Protects against: Regional disasters
- Higher latency, higher cost

**Our Implementation:**
- 2 AZs: us-east-1a and us-east-1b
- ALB distributes across AZs
- ASG launches instances in both AZs
- RDS Multi-AZ with automatic failover

---

### 6. What Happens During an Instance Failure?

**Timeline:**

```
00:00 - Instance becomes unresponsive
00:30 - First health check fails
01:00 - Second health check fails
01:00 - Instance marked UNHEALTHY
01:00 - Removed from ALB target group (no new connections)
01:00 - ASG initiates replacement
01:30 - Existing connections drained (30s deregistration delay)
02:00 - New instance launched
04:30 - New instance running
05:00 - Health check grace period begins
10:00 - First successful health check
10:30 - Second successful health check
10:30 - Instance marked HEALTHY, receives traffic
```

**Total Impact:**
- Existing connections: Continue for 30 seconds
- New connections: Routed to healthy instances
- Capacity: Reduced by 1 instance for ~10 minutes
- User impact: None (if min 2 instances)

---

### 7. Cost Optimization Strategies

**Current Monthly Cost:** ~$84-116

**Optimization Options:**

**1. Reserved Instances (40-60% savings):**
```
EC2: t3.micro x2 → RI = ~$90/year vs $180/year
RDS: db.t3.micro → RI = ~$85/year vs $147/year
Savings: ~$52/year (~45%)
```

**2. Single NAT Gateway (-$32/month):**
```hcl
single_nat_gateway = true  # From $64 → $32/month
```
**Trade-off:** Loss of NAT redundancy

**3. Scale Down During Off-Hours:**
```hcl
# Scheduled scaling
8 AM: Min=4, Max=10
6 PM: Min=2, Max=4
```

**4. Right-Sizing:**
```bash
# Monitor actual usage
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization
  
# If average CPU < 20%, consider smaller instance
```

**5. Use Spot Instances (70% savings):**
```hcl
# For non-critical workloads
mixed_instances_policy {
  instances_distribution {
    on_demand_percentage_above_base_capacity = 50
    spot_allocation_strategy = "lowest-price"
  }
}
```

---

### 8. Disaster Recovery

**RTO (Recovery Time Objective):** How long to restore
**RPO (Recovery Point Objective):** How much data loss acceptable

**Our Configuration:**

**Instance Failure:**
- RTO: ~10 minutes (ASG replacement)
- RPO: 0 (no data on instances)

**AZ Failure:**
- RTO: 0 (already multi-AZ)
- RPO: 0 (RDS synchronous replication)

**Database Failure:**
- RTO: 1-2 minutes (automatic failover)
- RPO: 0 (synchronous replication)

**Region Failure (Not Configured):**
- RTO: Hours (manual setup)
- RPO: 5 minutes (if using cross-region replication)

**Backup Strategy:**
```hcl
backup_retention_period = 7  # 7 days of automated backups
# Point-in-time recovery to any second within 7 days
```

---

### 9. Monitoring and Alerting

**CloudWatch Alarms Configured:**

**ALB:**
- High response time (>1 second)
- Unhealthy host count (>0)

**ASG:**
- High CPU (>70%) → Trigger scale up
- Low CPU (<20%) → Trigger scale down

**RDS:**
- High CPU (>80%)
- Low storage (<2GB)
- Low memory (<256MB)
- High connections (>80)

**How to View:**
```bash
# List all alarms
aws cloudwatch describe-alarms

# View specific metric
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=<alb-name> \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z \
  --period 3600 \
  --statistics Average
```

---

### 10. Security Best Practices

**Implemented:**
✅ Private subnets for compute and database
✅ Security groups with least privilege
✅ IAM roles (no hardcoded keys)
✅ Database encryption at rest
✅ VPC Flow Logs
✅ Multi-AZ deployment

**Should Add for Production:**
🔒 **AWS Secrets Manager** - Store DB password
🔒 **ACM Certificate** - Enable HTTPS
🔒 **WAF** - Web Application Firewall
🔒 **GuardDuty** - Threat detection
🔒 **CloudTrail** - API audit logging
🔒 **Config** - Configuration compliance
🔒 **KMS** - Customer-managed encryption keys

---

## Quick Reference

**When asked about:**

1. **High Availability** → Multi-AZ, Auto Scaling, Multi-AZ RDS
2. **Security** → Private subnets, Security Groups, NAT Gateway, IAM
3. **Scalability** → Auto Scaling policies, CloudWatch alarms
4. **Cost** → $84-116/month, optimization strategies
5. **Monitoring** → CloudWatch alarms for ALB, ASG, RDS
6. **Database** → RDS Multi-AZ, automated backups, encryption
7. **Load Balancing** → ALB for Layer 7, health checks, cross-AZ
8. **Disaster Recovery** → Multi-AZ, automated backups, quick failover

---

**Remember:** Always explain the "why" behind architectural decisions!
