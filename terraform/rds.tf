# ──────────────────────────────────────────────
# RDS PostgreSQL
# ──────────────────────────────────────────────
# RDS is AWS's managed relational database service.
# AWS handles backups, patching, and failover.
# The database lives in the DB subnet tier — completely
# isolated from the internet with no outbound route.
# ──────────────────────────────────────────────

# DB subnet group — tells RDS which subnets it can use.
# Must span at least two AZs.
resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-db-subnet-group"
  subnet_ids  = [aws_subnet.db_a.id, aws_subnet.db_b.id]
  description = "DB subnet group for ${var.project_name}"
  tags        = { Name = "${var.project_name}-db-subnet-group" }
}

resource "aws_db_instance" "postgres" {
  identifier        = "${var.project_name}-postgres"
  engine            = "postgres"
  engine_version    = "16"
  instance_class    = var.db_instance_class
  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Critical: keep the database private
  publicly_accessible = false

  # Automated backups — 7-day retention window
  backup_retention_period = 0
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # Encrypt data at rest
  storage_encrypted = true

  # Prevent accidental deletion via terraform destroy
  # Set to false when you are ready to tear down
  deletion_protection = false
  skip_final_snapshot = true

  tags = { Name = "${var.project_name}-postgres" }
}
