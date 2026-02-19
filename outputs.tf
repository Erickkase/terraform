# ============================================================
# OUTPUTS - INFRAESTRUCTURA MICROSERVICIOS
# ============================================================

output "alb_dns_name" {
  description = "DNS name del Application Load Balancer"
  value       = aws_lb.main_alb.dns_name
}

output "alb_url" {
  description = "URL del Application Load Balancer"
  value       = "http://${aws_lb.main_alb.dns_name}"
}

# PostgreSQL Outputs
output "postgres_private_ip" {
  description = "Private IP of the PostgreSQL EC2 instance"
  value       = aws_instance.postgres.private_ip
}

output "postgres_public_ip" {
  description = "Public IP of the PostgreSQL EC2 instance"
  value       = aws_instance.postgres.public_ip
}

output "postgres_instance_id" {
  description = "Instance ID of the PostgreSQL server"
  value       = aws_instance.postgres.id
}

output "postgres_database_name" {
  description = "PostgreSQL database name"
  value       = var.db_name
}

output "postgres_connection_string" {
  description = "PostgreSQL connection string for external access"
  value       = "postgresql://${var.db_username}:${var.db_password}@${aws_instance.postgres.public_ip}:5432/${var.db_name}"
  sensitive   = true
}

# MySQL Outputs
output "mysql_private_ip" {
  description = "Private IP of the MySQL EC2 instance"
  value       = aws_instance.mysql.private_ip
}

output "mysql_public_ip" {
  description = "Public IP of the MySQL EC2 instance"
  value       = aws_instance.mysql.public_ip
}

output "mysql_instance_id" {
  description = "Instance ID of the MySQL server"
  value       = aws_instance.mysql.id
}

output "mysql_connection_string" {
  description = "MySQL connection string for external access"
  value       = "mysql://${var.mysql_username}:${var.mysql_password}@${aws_instance.mysql.public_ip}:3306/"
  sensitive   = true
}

# service1 outputs
output "service1_asg_name" {
  description = "Nombre del Auto Scaling Group de service1"
  value       = aws_autoscaling_group.service1_asg.name
}

output "service1_target_group_arn" {
  description = "ARN del Target Group de service1"
  value       = aws_lb_target_group.service1_tg.arn
}

output "service1_endpoint" {
  description = "Endpoint de service1"
  value       = "http://${aws_lb.main_alb.dns_name}/api/service1"
}

# service2 outputs
output "service2_asg_name" {
  description = "Nombre del Auto Scaling Group de service2"
  value       = aws_autoscaling_group.service2_asg.name
}

output "service2_target_group_arn" {
  description = "ARN del Target Group de service2"
  value       = aws_lb_target_group.service2_tg.arn
}

output "service2_endpoint" {
  description = "Endpoint de service2"
  value       = "http://${aws_lb.main_alb.dns_name}/api/service2"
}

# service3 outputs
output "service3_asg_name" {
  description = "Nombre del Auto Scaling Group de service3"
  value       = aws_autoscaling_group.service3_asg.name
}

output "service3_target_group_arn" {
  description = "ARN del Target Group de service3"
  value       = aws_lb_target_group.service3_tg.arn
}

output "service3_endpoint" {
  description = "Endpoint de service3"
  value       = "http://${aws_lb.main_alb.dns_name}/api/service3"
}

# service4 outputs
output "service4_asg_name" {
  description = "Nombre del Auto Scaling Group de service4"
  value       = aws_autoscaling_group.service4_asg.name
}

output "service4_target_group_arn" {
  description = "ARN del Target Group de service4"
  value       = aws_lb_target_group.service4_tg.arn
}

output "service4_endpoint" {
  description = "Endpoint de service4"
  value       = "http://${aws_lb.main_alb.dns_name}/api/service4"
}

# service5 outputs
output "service5_asg_name" {
  description = "Nombre del Auto Scaling Group de service5"
  value       = aws_autoscaling_group.service5_asg.name
}

output "service5_target_group_arn" {
  description = "ARN del Target Group de service5"
  value       = aws_lb_target_group.service5_tg.arn
}

output "service5_endpoint" {
  description = "Endpoint de service5"
  value       = "http://${aws_lb.main_alb.dns_name}/api/service5"
}

# SSH Keys (Private - para debugging)
output "service1_private_key" {
  description = "Private key para SSH a service1 instances"
  value       = tls_private_key.service1_key.private_key_pem
  sensitive   = true
}

output "service2_private_key" {
  description = "Private key para SSH a service2 instances"
  value       = tls_private_key.service2_key.private_key_pem
  sensitive   = true
}

output "service3_private_key" {
  description = "Private key para SSH a service3 instances"
  value       = tls_private_key.service3_key.private_key_pem
  sensitive   = true
}

output "service4_private_key" {
  description = "Private key para SSH a service4 instances"
  value       = tls_private_key.service4_key.private_key_pem
  sensitive   = true
}

output "service5_private_key" {
  description = "Private key para SSH a service5 instances"
  value       = tls_private_key.service5_key.private_key_pem
  sensitive   = true
}

output "postgres_private_key" {
  description = "Private key for SSH to PostgreSQL instance"
  value       = tls_private_key.postgres_key.private_key_pem
  sensitive   = true
}

output "mysql_private_key" {
  description = "Private key for SSH to MySQL instance"
  value       = tls_private_key.mysql_key.private_key_pem
  sensitive   = true
}

# Summary
output "deployment_summary" {
  description = "Deployment summary"
  value = {
    alb_url              = "http://${aws_lb.main_alb.dns_name}"
    service1_url         = "http://${aws_lb.main_alb.dns_name}/api/service1"
    service2_url         = "http://${aws_lb.main_alb.dns_name}/api/service2"
    service3_url         = "http://${aws_lb.main_alb.dns_name}/api/service3"
    service4_url         = "http://${aws_lb.main_alb.dns_name}/api/service4"
    service5_url         = "http://${aws_lb.main_alb.dns_name}/api/service5"
    postgres_private_ip  = aws_instance.postgres.private_ip
    postgres_public_ip   = aws_instance.postgres.public_ip
    mysql_private_ip     = aws_instance.mysql.private_ip
    mysql_public_ip      = aws_instance.mysql.public_ip
    database_name        = var.db_name
  }
}
