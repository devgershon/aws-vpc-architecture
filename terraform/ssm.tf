# ──────────────────────────────────────────────
# SSM VPC Endpoints
# ──────────────────────────────────────────────
# Session Manager normally communicates over the internet.
# EC2 instances in private subnets have no internet access,
# so we create VPC endpoints — private connections from the VPC
# directly to AWS services, without traffic leaving AWS.
#
# Three endpoints are required for Session Manager:
#   ssm         — core SSM service
#   ssmmessages — Session Manager message delivery
#   ec2messages — EC2 message delivery
# ──────────────────────────────────────────────

locals {
  ssm_services = ["ssm", "ssmmessages", "ec2messages"]
}

resource "aws_vpc_endpoint" "ssm" {
  for_each = toset(local.ssm_services)

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true # Lets the SSM agent use the standard endpoint URL

  tags = { Name = "${var.project_name}-${each.value}-endpoint" }
}
