

output "control_node_sg_id" {
  description = "Control Node Security Group ID"
  value       = aws_security_group.control-node-sg.id
}

output "k8s_nodes_sg_id" {
  description = "Kubernetes Nodes Security Group ID"
  value       = aws_security_group.k8s-nodes-sg.id
}

output "public_route_table_id" {
  description = "Public Route Table ID"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "Private Route Table ID"
  value       = aws_route_table.private.id
}
