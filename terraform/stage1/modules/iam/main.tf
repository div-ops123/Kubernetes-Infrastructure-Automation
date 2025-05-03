# This tells Terraform to fetch information about the current AWS account — which you're using to build the ARN.
data "aws_caller_identity" "current" {}


# Master Node IAM Role
resource "aws_iam_role" "master_node" {
  name = "master-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}