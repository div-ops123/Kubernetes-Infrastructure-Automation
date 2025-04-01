# Output public IPs for Ansible inventory.

output "master_private_ip" {
  description = "Private IP of the master node"
  value       = aws_instance.master-node.private_ip
}

# output "worker_instance_ids" {
#   description = "IDs of worker instances"
#   value       = aws_autoscaling_group.workers.instances[*].id
# }