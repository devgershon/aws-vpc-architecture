# ──────────────────────────────────────────────
# IAM — EC2 Instance Profile for SSM Session Manager
# ──────────────────────────────────────────────
# Session Manager requires EC2 instances to have an IAM role
# with the AmazonSSMManagedInstanceCore policy. This lets the
# SSM agent on the instance communicate with the SSM service
# without needing any open inbound ports.
# ──────────────────────────────────────────────

data "aws_iam_policy_document" "ec2_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "${var.project_name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
  description        = "Allows EC2 to use SSM Session Manager"
}

# AmazonSSMManagedInstanceCore grants SSM the permissions it needs
# to communicate with EC2: start sessions, run commands, send logs
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile — the container that attaches an IAM role to an EC2 instance
resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2.name
}
