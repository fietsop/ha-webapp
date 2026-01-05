# Jenkins Installation on Amazon Linux - Manual Guide

## Prerequisites

- AWS Account with appropriate permissions
- EC2 key pair created
- Basic knowledge of SSH and Linux commands

## Step 1: Launch Amazon Linux EC2 Instance

### Via AWS Console:

1. **Navigate to EC2 Dashboard**
   - Go to AWS Console → EC2 → Launch Instance

2. **Configure Instance**
   ```
   Name: jenkins-server
   AMI: Amazon Linux 2023 (or Amazon Linux 2)
   Instance Type: t3.medium (minimum for Jenkins)
   Key Pair: Select your existing key pair
   Network Settings:
     - VPC: Default or custom
     - Auto-assign Public IP: Enable
     - Security Group: Create new (see below)
   Storage: 20 GB gp3
   ```

3. **Security Group Configuration**
   ```
   Inbound Rules:
   - SSH (22)       - Source: Your IP (My IP)
   - HTTP (8080)    - Source: Your IP (Jenkins web UI)
   - Custom (80)    - Source: 0.0.0.0/0 (if using reverse proxy)
   
   Outbound Rules:
   - All traffic    - Destination: 0.0.0.0/0
   ```

4. **Launch Instance** and wait for it to be in "Running" state

### Via AWS CLI:

```bash
# Create security group
aws ec2 create-security-group \
  --group-name jenkins-sg \
  --description "Security group for Jenkins server"

# Add SSH rule
aws ec2 authorize-security-group-ingress \
  --group-name jenkins-sg \
  --protocol tcp \
  --port 22 \
  --cidr $(curl -s https://checkip.amazonaws.com)/32

# Add Jenkins web UI rule
aws ec2 authorize-security-group-ingress \
  --group-name jenkins-sg \
  --protocol tcp \
  --port 8080 \
  --cidr $(curl -s https://checkip.amazonaws.com)/32

# Launch instance
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \  # Update with latest AL2023 AMI
  --instance-type t3.medium \
  --key-name your-key-name \
  --security-groups jenkins-sg \
  --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":20,"VolumeType":"gp3"}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=jenkins-server}]'
```

## Step 2: Connect to Your Instance

### Get Instance Details:
```bash
# Get public IP
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=jenkins-server" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text
```

### SSH Connection:
```bash
# Set permissions on key file
chmod 400 your-key.pem

# Connect to instance
ssh -i your-key.pem ec2-user@<INSTANCE-PUBLIC-IP>
```

## Step 3: Install Java (Jenkins Requirement)

Jenkins requires Java 11 or Java 17.

### For Amazon Linux 2023:
```bash
# Update system packages
sudo dnf update -y

# Install Java 17 (Amazon Corretto - AWS distribution of OpenJDK)
sudo dnf install -y java-17-amazon-corretto-devel

# Verify installation
java -version
# Output: openjdk version "17.0.x"
```

### For Amazon Linux 2:
```bash
# Update system packages
sudo yum update -y

# Install Java 11
sudo amazon-linux-extras install java-openjdk11 -y

# Or install Java 17
sudo yum install -y java-17-amazon-corretto-devel

# Verify installation
java -version
```

### Set JAVA_HOME (Optional but Recommended):
```bash
# Find Java installation path
java_path=$(readlink -f $(which java) | sed "s:/bin/java::")

# Add to profile
echo "export JAVA_HOME=$java_path" | sudo tee -a /etc/profile
echo "export PATH=\$PATH:\$JAVA_HOME/bin" | sudo tee -a /etc/profile

# Apply changes
source /etc/profile

# Verify
echo $JAVA_HOME
```

## Step 4: Install Jenkins

### Method 1: Official Jenkins Repository (Recommended)

#### For Amazon Linux 2023:
```bash
# Add Jenkins repository
sudo wget -O /etc/yum.repos.d/jenkins.repo \
    https://pkg.jenkins.io/redhat-stable/jenkins.repo

# Import Jenkins GPG key
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Install Jenkins
sudo dnf install jenkins -y

# Alternative: Install specific version
# sudo dnf install jenkins-2.426.1-1.1 -y
```

#### For Amazon Linux 2:
```bash
# Add Jenkins repository
sudo wget -O /etc/yum.repos.d/jenkins.repo \
    https://pkg.jenkins.io/redhat-stable/jenkins.repo

# Import Jenkins GPG key
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Install Jenkins
sudo yum install jenkins -y
```

### Method 2: Direct RPM Installation
```bash
# Download Jenkins RPM (LTS version)
wget https://get.jenkins.io/redhat-stable/jenkins-2.426.1-1.1.noarch.rpm

# Install Jenkins
sudo rpm -ivh jenkins-2.426.1-1.1.noarch.rpm
```

## Step 5: Configure Jenkins Service

```bash
# Reload systemd daemon
sudo systemctl daemon-reload

# Enable Jenkins to start on boot
sudo systemctl enable jenkins

# Start Jenkins service
sudo systemctl start jenkins

# Check Jenkins status
sudo systemctl status jenkins
```

**Expected Output:**
```
● jenkins.service - Jenkins Continuous Integration Server
   Loaded: loaded (/usr/lib/systemd/system/jenkins.service; enabled)
   Active: active (running) since [date]
```

## Step 6: Configure Firewall (If Using)

### For Amazon Linux 2023 (firewalld):
```bash
# Check if firewalld is running
sudo systemctl status firewalld

# If running, open port 8080
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload
```

### For Amazon Linux 2 (iptables):
```bash
# Usually not needed as AWS Security Groups handle this
# But if using iptables:
sudo iptables -I INPUT -p tcp --dport 8080 -j ACCEPT
sudo service iptables save
```

## Step 7: Initial Jenkins Setup

### Get Initial Admin Password:
```bash
# Wait for Jenkins to start (can take 1-2 minutes)
sleep 60

# Retrieve initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

**Copy this password** - you'll need it in the next step.

### Access Jenkins Web Interface:

1. Open browser and navigate to:
   ```
   http://<INSTANCE-PUBLIC-IP>:8080
   ```

2. **Unlock Jenkins**
   - Paste the initial admin password
   - Click "Continue"

3. **Customize Jenkins**
   - Select "Install suggested plugins" (recommended for beginners)
   - Or select "Select plugins to install" (for custom setup)
   
4. **Wait for Plugin Installation** (~5 minutes)

5. **Create First Admin User**
   ```
   Username: admin
   Password: YourSecurePassword123!
   Full name: Your Name
   Email: your.email@example.com
   ```

6. **Instance Configuration**
   - Jenkins URL: http://<INSTANCE-PUBLIC-IP>:8080/
   - Click "Save and Finish"

7. **Start Using Jenkins**
   - Click "Start using Jenkins"

## Step 8: Basic Jenkins Configuration

### Install Additional Plugins:

1. Navigate to: **Manage Jenkins** → **Manage Plugins**
2. Go to "Available" tab
3. Search and install commonly used plugins:
   ```
   - Git plugin
   - GitHub plugin
   - Pipeline plugin
   - Docker plugin
   - AWS Credentials plugin
   - SSH Build Agents plugin
   ```

### Configure Global Tools:

1. **Manage Jenkins** → **Global Tool Configuration**

2. **Git Installation**
   ```bash
   # First install git on the server
   sudo dnf install git -y  # For AL2023
   # or
   sudo yum install git -y  # For AL2
   ```
   
   Then in Jenkins:
   - Name: Default
   - Path to Git executable: /usr/bin/git

3. **Maven Installation** (if needed)
   - Click "Add Maven"
   - Name: Maven-3.9
   - Install automatically from Apache

## Step 9: Create Your First Job

### Simple Freestyle Project:

1. Click "New Item"
2. Enter name: "hello-world"
3. Select "Freestyle project"
4. Click "OK"

5. **Configure Build**
   - Build Steps → Add build step → Execute shell
   ```bash
   echo "Hello from Jenkins!"
   echo "Current date: $(date)"
   echo "Hostname: $(hostname)"
   echo "User: $(whoami)"
   ```

6. Click "Save"
7. Click "Build Now"
8. Check "Console Output" to see results

### Simple Pipeline Project:

1. Click "New Item"
2. Enter name: "hello-pipeline"
3. Select "Pipeline"
4. Click "OK"

5. **Pipeline Script**
   ```groovy
   pipeline {
       agent any
       
       stages {
           stage('Hello') {
               steps {
                   echo 'Hello from Jenkins Pipeline!'
               }
           }
           
           stage('Build') {
               steps {
                   echo 'Building application...'
                   sh 'date'
               }
           }
           
           stage('Test') {
               steps {
                   echo 'Running tests...'
               }
           }
       }
   }
   ```

6. Click "Save" and "Build Now"

## Step 10: Additional Configuration (Optional)

### Install Docker (for Docker-based builds):
```bash
# Install Docker
sudo dnf install docker -y  # For AL2023
# or
sudo yum install docker -y  # For AL2

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Add jenkins user to docker group
sudo usermod -aG docker jenkins

# Restart Jenkins to apply group changes
sudo systemctl restart jenkins

# Verify
sudo -u jenkins docker ps
```

### Configure Jenkins Backup:

```bash
# Create backup script
sudo tee /usr/local/bin/jenkins-backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/var/backups/jenkins"
JENKINS_HOME="/var/lib/jenkins"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR
tar -czf $BACKUP_DIR/jenkins-backup-$DATE.tar.gz \
    --exclude=$JENKINS_HOME/workspace \
    --exclude=$JENKINS_HOME/war \
    $JENKINS_HOME

# Keep only last 7 backups
find $BACKUP_DIR -name "jenkins-backup-*.tar.gz" -mtime +7 -delete
EOF

# Make executable
sudo chmod +x /usr/local/bin/jenkins-backup.sh

# Test backup
sudo /usr/local/bin/jenkins-backup.sh

# Add to crontab (daily at 2 AM)
echo "0 2 * * * /usr/local/bin/jenkins-backup.sh" | sudo crontab -
```

### Set Up Reverse Proxy with Nginx (Optional):

```bash
# Install Nginx
sudo dnf install nginx -y

# Configure Nginx for Jenkins
sudo tee /etc/nginx/conf.d/jenkins.conf << 'EOF'
upstream jenkins {
    server 127.0.0.1:8080 fail_timeout=0;
}

server {
    listen 80;
    server_name jenkins.yourdomain.com;

    location / {
        proxy_pass http://jenkins;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Required for WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

# Start Nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Update Security Group to allow port 80
```

## Troubleshooting

### Jenkins Won't Start:
```bash
# Check logs
sudo journalctl -u jenkins -n 50

# Or check Jenkins log file
sudo tail -f /var/log/jenkins/jenkins.log

# Check Java installation
java -version

# Check port usage
sudo netstat -tulpn | grep 8080
```

### Can't Access Jenkins UI:
```bash
# Check Jenkins is running
sudo systemctl status jenkins

# Check AWS Security Group allows port 8080

# Verify firewall rules
sudo firewall-cmd --list-all  # For AL2023

# Test locally
curl http://localhost:8080
```

### Permission Issues:
```bash
# Fix Jenkins home directory permissions
sudo chown -R jenkins:jenkins /var/lib/jenkins

# Restart Jenkins
sudo systemctl restart jenkins
```

### Out of Memory:
```bash
# Increase Jenkins heap size
sudo sed -i 's/JENKINS_JAVA_OPTIONS="-Djava.awt.headless=true"/JENKINS_JAVA_OPTIONS="-Djava.awt.headless=true -Xms512m -Xmx2048m"/' /etc/sysconfig/jenkins

# Or for systemd
sudo mkdir -p /etc/systemd/system/jenkins.service.d
sudo tee /etc/systemd/system/jenkins.service.d/override.conf << 'EOF'
[Service]
Environment="JAVA_OPTS=-Djava.awt.headless=true -Xms512m -Xmx2048m"
EOF

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart jenkins
```

## Maintenance Commands

```bash
# Stop Jenkins
sudo systemctl stop jenkins

# Start Jenkins
sudo systemctl start jenkins

# Restart Jenkins
sudo systemctl restart jenkins

# Check status
sudo systemctl status jenkins

# View logs
sudo journalctl -u jenkins -f

# Check Jenkins version
java -jar /usr/share/java/jenkins.war --version
```

## Security Best Practices

1. **Change default admin password** immediately
2. **Configure authentication** (LDAP, GitHub OAuth, etc.)
3. **Enable CSRF protection** (enabled by default)
4. **Keep Jenkins updated** regularly
5. **Use HTTPS** with SSL certificate
6. **Restrict Security Group** to specific IPs
7. **Enable audit logging**
8. **Regular backups** of Jenkins home directory
9. **Use credentials plugin** for secrets
10. **Configure authorization** properly

## Useful Jenkins Directories

```
Configuration:     /var/lib/jenkins/config.xml
Jobs:             /var/lib/jenkins/jobs/
Plugins:          /var/lib/jenkins/plugins/
Logs:             /var/log/jenkins/jenkins.log
Workspace:        /var/lib/jenkins/workspace/
Secrets:          /var/lib/jenkins/secrets/
```

## Next Steps

1. ✅ Jenkins installed and running
2. 🔲 Create your first CI/CD pipeline
3. 🔲 Integrate with GitHub/GitLab
4. 🔲 Configure webhooks for automatic builds
5. 🔲 Set up Jenkins slaves/agents
6. 🔲 Configure email notifications
7. 🔲 Implement automated testing
8. 🔲 Set up deployment pipelines
9. 🔲 Configure monitoring and alerts
10. 🔲 Document your Jenkins setup

---

**📚 Additional Resources:**
- Jenkins Documentation: https://www.jenkins.io/doc/
- Jenkins Plugins: https://plugins.jenkins.io/
- Jenkins Pipeline Syntax: https://www.jenkins.io/doc/book/pipeline/syntax/
