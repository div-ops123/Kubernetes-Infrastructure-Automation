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

output "alb_sg_id" {
  description = "ALB Security Group ID"
  value       = module.vpc.alb_sg_id
}

output "nodes_sg_id" {
  description = "Kubernetes Nodes Security Group ID"
  value       = module.vpc.nodes_sg_id
}

output "public_route_table_id" {
  description = "Public Route Table ID"
  value       = module.vpc.public_route_table_id
}

output "private_route_table_id" {
  description = "Private Route Table ID"
  value       = module.vpc.private_route_table_id
}

output "master_private_ip" {
  description = "Private IP of the master node"
  value       = module.compute.master_private_ip
}

# ASK Grok if you can manually stop the instances in the console then running terraform apply would it change it back?
# output "worker_instance_ids" {
#   description = "IDs of worker instances"
#   value       = module.compute.worker_instance_ids
# }