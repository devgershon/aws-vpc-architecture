# ──────────────────────────────────────────────
# EC2 — App Servers
# ──────────────────────────────────────────────
# EC2 instances live in the private subnets.
# They are bootstrapped via user_data — a shell script
# that runs on first boot to install Python, the app,
# and start the FastAPI service.
#
# No SSH keys — access is via SSM Session Manager only.
# The instance profile grants the SSM permissions.
# ──────────────────────────────────────────────

locals {
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    db_host     = aws_db_instance.postgres.address
    db_port     = aws_db_instance.postgres.port
    db_name     = var.db_name
    db_username = var.db_username
    db_password = var.db_password
    app_port    = var.app_port
    environment = var.environment
    app_code    = file("${path.module}/../app/main.py")

  }))
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.private_a.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  # No key pair — Session Manager handles access
  # key_name = "..."

  user_data                   = local.user_data
  user_data_replace_on_change = true

  tags = { Name = "${var.project_name}-app-server" }

  # Wait for RDS to be available before launching EC2,
  # otherwise the app starts before the DB is ready
  depends_on = [aws_db_instance.postgres]
}

# Register EC2 with the ALB target group
resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app.id
  port             = var.app_port
}
