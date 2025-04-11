output "vpc_id" {
  description = "VPC ID"
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value = module.vpc.public_subnet_ids
}

output "private_subnets_ids" {
  description = "List of IDs of private subnets"
  value = module.vpc.private_subnet_ids
}

output "igw_id" {
  description = "Internet Gateway ID"
  value       = module.vpc.igw_id
}

output "nat_eip" {
  description = "ALB Security Group ID"
  value       = module.vpc.nat_eip
}

output "k8s_nodes_sg_id" {
  description = "Kubernetes Nodes Security Group ID"
  value       = module.vpc.k8s_nodes_sg_id
}

output "public_route_table_id" {
  description = "Public Route Table ID"
  value       = module.vpc.public_route_table_id
}

output "private_route_table_id" {
  description = "Private Route Table ID"
  value       = module.vpc.private_route_table_id
}

output "control_node_public_ip" {
  description = "Control node public IP"
  value = module.compute.control_node_public_ip
}

output "master_private_ip" {
  description = "Private IP of the master node"
  value       = module.compute.master_private_ip
}

output "worker_instance_ips" {
  description = "IPs of worker instances"
  value       = module.compute.worker_instance_ips
}

output "storage_class_name" {
  value = kubernetes_storage_class.ebs_sc.metadata[0].name  # Outputs "ebs-sc"
}