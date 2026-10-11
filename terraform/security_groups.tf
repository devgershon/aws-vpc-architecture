# ──────────────────────────────────────────────
# Security Groups
# ──────────────────────────────────────────────
# Four security groups, one per tier:
#   ALB       — accepts HTTP from internet
#   EC2       — accepts app traffic from ALB only
#   RDS       — accepts PostgreSQL from EC2 only
#   SSM VPC Endpoints — accepts HTTPS from EC2 (for Session Manager)
# ──────────────────────────────────────────────

# ── ALB ───────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "ALB - accepts HTTP from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-alb-sg" }
}

# ── EC2 App Servers ────────────────────────────
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "EC2 - accepts app traffic from ALB only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App port from ALB only"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All outbound - needed for NAT Gateway, RDS, SSM"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-ec2-sg" }
}

# ── RDS PostgreSQL ─────────────────────────────
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "RDS - accepts PostgreSQL from EC2 only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from EC2 only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  # No egress rule — RDS does not initiate outbound connections

  tags = { Name = "${var.project_name}-rds-sg" }
}

# ── SSM VPC Endpoints ──────────────────────────
# Session Manager communicates through VPC endpoints so EC2 in
# private subnets can use SSM without internet access.
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project_name}-vpce-sg"
  description = "VPC endpoints - accepts HTTPS from EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTPS from EC2 for SSM"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-vpce-sg" }
}
