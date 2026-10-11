output "alb_url" {
  description = "The public URL of your app via the ALB."
  value       = "http://${aws_lb.main.dns_name}"
}

output "alb_dns_name" {
  description = "ALB DNS name without protocol."
  value       = aws_lb.main.dns_name
}

output "ec2_instance_id" {
  description = "EC2 instance ID — use this to start a Session Manager session."
  value       = aws_instance.app.id
}

output "rds_endpoint" {
  description = "RDS endpoint — the DB_HOST value for the app."
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "RDS port."
  value       = aws_db_instance.postgres.port
}

output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.main.id
}

output "ssm_connect_command" {
  description = "Command to connect to the EC2 instance via Session Manager."
  value       = "aws ssm start-session --target ${aws_instance.app.id} --region ${var.aws_region}"
}
