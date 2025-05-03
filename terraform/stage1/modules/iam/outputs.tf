output "master_iam_role_name" {
  description = "IAM Role Name for the master node"
  value       = aws_iam_role.master_node.name
}

output "master_iam_role_arn" {
  description = "IAM Role ARN for the master node"
  value       = aws_iam_role.master_node.arn
}
