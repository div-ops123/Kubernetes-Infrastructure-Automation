output "vpc_id" {
  description = "ID of the created VPC"
  value = aws_vpc.note-app-vpc.id
}

# aws_subnet.note-app-public-subnets is a list of subnet resources, and [*].id extracts their id attributes into a list of strings.
output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value = aws_subnet.note-app-public-subnets[*].id
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value = aws_subnet.note-app-private-subnets[*].id
}