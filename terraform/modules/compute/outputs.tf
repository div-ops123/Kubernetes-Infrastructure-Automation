# Output public IPs for Ansible inventory.

# Add Data Source to fetch worker instances by tag
data "aws_instances" "master" {
  instance_tags = { Name = "master-node"}
  depends_on = [ aws_instance.master-node ]  # Ensures master-node's IP is created. the ip didn't show before
}

output "master_private_ip" {
  description = "Private IP of the master node"
  value       = data.aws_instances.master.private_ips
}

# Add Data Source to fetch worker instances by tag
data "aws_instances" "workers" {
  instance_tags = { KubernetesRole = "worker"}
  depends_on = [ aws_autoscaling_group.workers ]  # Ensures ASG creates instances first
}


output "worker_instance_ids" {
  description = "IDs of worker instances"
  value       = data.aws_instances.workers.ids
}

output "worker_instance_ips" {
  description = "IPs of worker instances"
  value       = data.aws_instances.workers.private_ips
}