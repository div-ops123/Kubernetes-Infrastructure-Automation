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