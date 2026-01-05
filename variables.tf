# General Variables
variable "aws_region" {
  description = "AWS region to deploy Jenkins server"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "jenkins"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

# Network Variables
variable "use_default_vpc" {
  description = "Use default VPC"
  type        = bool
  default     = true
}

variable "allowed_ssh_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"] # CHANGE THIS to your IP for production!
}

variable "allowed_jenkins_cidr_blocks" {
  description = "CIDR blocks allowed for Jenkins web UI access (port 8080)"
  type        = list(string)
  default     = ["0.0.0.0/0"] # CHANGE THIS to your IP for production!
}

variable "allowed_http_cidr_blocks" {
  description = "CIDR blocks allowed for HTTP access (port 80)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_https_cidr_blocks" {
  description = "CIDR blocks allowed for HTTPS access (port 443)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# EC2 Instance Variables
variable "instance_type" {
  description = "EC2 instance type for Jenkins server"
  type        = string
  default     = "t3.medium"
  
  validation {
    condition     = contains(["t3.medium", "t3.large", "t3.xlarge", "m5.large", "m5.xlarge"], var.instance_type)
    error_message = "Instance type must be at least t3.medium for Jenkins. Recommended: t3.medium or larger."
  }
}

variable "ami_id" {
  description = "AMI ID for Jenkins server (leave empty to use latest Amazon Linux 2023)"
  type        = string
  default     = ""
}

variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
  default     = "jenkins-terraform"
}

variable "root_volume_size" {
  description = "Size of root EBS volume in GB"
  type        = number
  default     = 30
  
  validation {
    condition     = var.root_volume_size >= 20
    error_message = "Root volume size must be at least 20 GB for Jenkins."
  }
}

variable "allocate_elastic_ip" {
  description = "Allocate and associate Elastic IP to Jenkins instance"
  type        = bool
  default     = true
}

# Jenkins Configuration
variable "install_docker" {
  description = "Install Docker on Jenkins server"
  type        = bool
  default     = true
}

variable "install_nginx" {
  description = "Install and configure Nginx as reverse proxy"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Domain name for Jenkins (used if install_nginx is true)"
  type        = string
  default     = ""
}

# Monitoring Variables
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
  
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention period."
  }
}

# Backup Variables
variable "enable_backup" {
  description = "Enable AWS Backup for Jenkins server"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "backup_schedule" {
  description = "Cron expression for backup schedule"
  type        = string
  default     = "cron(0 2 * * ? *)" # Daily at 2 AM UTC
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
