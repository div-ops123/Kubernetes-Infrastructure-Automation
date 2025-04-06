output "vpc_id" {
  description = "ID of the created VPC"
  value = aws_vpc.vpc.id
}

# aws_subnet.url-shortener-public-subnets is a list of subnet resources, and [*].id extracts their id attributes into a list of strings.
output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value = aws_subnet.public-subnets[*].id
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value = aws_subnet.private-subnets[*].id
}

output "igw_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.igw.id
}

output "nat_eip" {
  description = "Static Elastic Public IP"
  value       = aws_eip.nat_eip.public_ip
}

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
