# Instance Information
output "instance_id" {
  description = "ID of the Jenkins EC2 instance"
  value       = aws_instance.jenkins.id
}

output "instance_public_ip" {
  description = "Public IP address of Jenkins instance"
  value       = aws_instance.jenkins.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of Jenkins instance"
  value       = aws_instance.jenkins.private_ip
}

output "elastic_ip" {
  description = "Elastic IP address (if allocated)"
  value       = var.allocate_elastic_ip ? aws_eip.jenkins[0].public_ip : "Not allocated"
}

# Access Information
output "jenkins_url" {
  description = "URL to access Jenkins web interface"
  value       = var.install_nginx && var.domain_name != "" ? "http://${var.domain_name}" : "http://${var.allocate_elastic_ip ? aws_eip.jenkins[0].public_ip : aws_instance.jenkins.public_ip}:8080"
}

output "jenkins_url_direct" {
  description = "Direct URL to Jenkins (port 8080)"
  value       = "http://${var.allocate_elastic_ip ? aws_eip.jenkins[0].public_ip : aws_instance.jenkins.public_ip}:8080"
}

output "ssh_command" {
  description = "SSH command to connect to Jenkins instance"
  value       = var.key_name != "" ? "ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${var.allocate_elastic_ip ? aws_eip.jenkins[0].public_ip : aws_instance.jenkins.public_ip}" : "Use AWS Systems Manager Session Manager"
}

# Initial Setup Information
output "initial_password_command" {
  description = "Command to retrieve Jenkins initial admin password"
  value       = "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
}

output "initial_password_ssm" {
  description = "SSM Parameter Store path for initial password"
  value       = "/${var.project_name}/${var.environment}/jenkins-initial-password"
}

output "get_password_command" {
  description = "AWS CLI command to get initial password from SSM"
  value       = "aws ssm get-parameter --name /${var.project_name}/${var.environment}/jenkins-initial-password --with-decryption --query 'Parameter.Value' --output text --region ${var.aws_region}"
}

# Security Information
output "security_group_id" {
  description = "ID of Jenkins security group"
  value       = aws_security_group.jenkins.id
}

output "iam_role_arn" {
  description = "ARN of Jenkins IAM role"
  value       = aws_iam_role.jenkins.arn
}

# Monitoring Information
output "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.jenkins.name
}

output "cpu_alarm_name" {
  description = "Name of CPU utilization alarm"
  value       = aws_cloudwatch_metric_alarm.high_cpu.alarm_name
}

output "health_alarm_name" {
  description = "Name of instance health alarm"
  value       = aws_cloudwatch_metric_alarm.instance_health.alarm_name
}

# Quick Start Guide
output "quick_start" {
  description = "Quick start instructions"
  value       = <<-EOT
    
    ═══════════════════════════════════════════════════════════════
    🎉 Jenkins Server Deployed Successfully!
    ═══════════════════════════════════════════════════════════════
    
    📍 Access Jenkins:
       ${var.install_nginx && var.domain_name != "" ? "http://${var.domain_name}" : "http://${var.allocate_elastic_ip ? aws_eip.jenkins[0].public_ip : aws_instance.jenkins.public_ip}:8080"}
    
    🔑 Get Initial Admin Password:
       Method 1 (SSH):
         ${var.key_name != "" ? "ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${var.allocate_elastic_ip ? aws_eip.jenkins[0].public_ip : aws_instance.jenkins.public_ip}" : "Use SSM Session Manager"}
         sudo cat /var/lib/jenkins/secrets/initialAdminPassword
       
       Method 2 (AWS CLI):
         aws ssm get-parameter --name /${var.project_name}/${var.environment}/jenkins-initial-password --with-decryption --query 'Parameter.Value' --output text --region ${var.aws_region}
       
       Method 3 (Check logs):
         View user-data logs in CloudWatch or run:
         sudo tail -100 /var/log/user-data.log
    
    📊 Monitor:
       CloudWatch Logs: ${aws_cloudwatch_log_group.jenkins.name}
       CloudWatch Alarms: ${aws_cloudwatch_metric_alarm.high_cpu.alarm_name}, ${aws_cloudwatch_metric_alarm.instance_health.alarm_name}
    
    🔧 SSH Access:
       ${var.key_name != "" ? "ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${var.allocate_elastic_ip ? aws_eip.jenkins[0].public_ip : aws_instance.jenkins.public_ip}" : "aws ssm start-session --target ${aws_instance.jenkins.id}"}
    
    ⚠️  Security Reminder:
       - Update Security Group to restrict access to your IP
       - Change default admin password immediately
       - Configure authentication (LDAP, GitHub OAuth, etc.)
       - Enable HTTPS with SSL certificate
    
    📚 Next Steps:
       1. Access Jenkins URL above
       2. Enter initial admin password
       3. Install suggested plugins
       4. Create admin user
       5. Start creating jobs!
    
    ═══════════════════════════════════════════════════════════════
  EOT
}
