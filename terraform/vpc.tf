# ──────────────────────────────────────────────
# VPC — Virtual Private Cloud
# ──────────────────────────────────────────────
# The VPC is an isolated private network inside AWS.
# Everything in this project lives inside it.
#
# Layout:
#   Public subnets  (AZ-a, AZ-b) — ALB, NAT Gateway
#   Private subnets (AZ-a, AZ-b) — EC2 app servers
#   DB subnets      (AZ-a, AZ-b) — RDS PostgreSQL
#
# The three tiers are in separate subnet ranges and controlled
# by separate security groups. The database has no route to the
# internet whatsoever. EC2 can reach the internet outbound only
# via the NAT Gateway. The ALB is the only resource with inbound
# internet access.
# ──────────────────────────────────────────────

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true # Required for RDS endpoint resolution

  tags = { Name = "${var.project_name}-vpc" }
}

# ── Internet Gateway ───────────────────────────
# Connects the VPC to the internet.
# Public subnets route outbound traffic through this.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

# ── Public Subnets ─────────────────────────────
# Two public subnets in different AZs.
# ALB and NAT Gateway live here.
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project_name}-public-a", Tier = "public" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project_name}-public-b", Tier = "public" }
}

# ── Private Subnets (App tier) ─────────────────
# EC2 instances live here.
# No direct internet access — outbound goes via NAT Gateway.
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "${var.aws_region}a"
  tags              = { Name = "${var.project_name}-private-a", Tier = "private" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "${var.aws_region}b"
  tags              = { Name = "${var.project_name}-private-b", Tier = "private" }
}

# ── DB Subnets (Data tier) ─────────────────────
# RDS lives here.
# No route to the internet at all — not even via NAT.
# Only EC2 instances in the private subnets can reach it.
resource "aws_subnet" "db_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = "${var.aws_region}a"
  tags              = { Name = "${var.project_name}-db-a", Tier = "database" }
}

resource "aws_subnet" "db_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = "${var.aws_region}b"
  tags              = { Name = "${var.project_name}-db-b", Tier = "database" }
}

# ── NAT Gateway ────────────────────────────────
# Allows EC2 instances in private subnets to reach the internet
# for outbound traffic (pulling packages, calling APIs).
# Inbound traffic from the internet cannot reach private subnets.
# Lives in a public subnet (needs internet access itself).
# Has an Elastic IP — its address never changes.
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.project_name}-nat-eip" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id
  tags          = { Name = "${var.project_name}-nat" }
  depends_on    = [aws_internet_gateway.main]
}

# ── Route Tables ───────────────────────────────

# Public route table — sends all outbound traffic to the IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# Private route table — sends outbound traffic to the NAT Gateway
# (not the IGW — inbound from internet is blocked)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = { Name = "${var.project_name}-private-rt" }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# DB route table — no internet route at all
# The database tier has no outbound internet access.
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-db-rt" }
}

resource "aws_route_table_association" "db_a" {
  subnet_id      = aws_subnet.db_a.id
  route_table_id = aws_route_table.db.id
}

resource "aws_route_table_association" "db_b" {
  subnet_id      = aws_subnet.db_b.id
  route_table_id = aws_route_table.db.id
}
