# Output public IPs for Ansible inventory.

output "control_node_public_ip" {
  description = "Control node public IP"
  value = aws_instance.control-node.public_ip
}

# output "master_private_ip" {
#   description = "Private IP of the master node"
#   value       = aws_instance.master-node.private_ip
# }

# Data Source to fetch worker instances by tag
# data "aws_instances" "workers" {
#   instance_tags = { KubernetesRole = "worker"}
#   depends_on = [ aws_autoscaling_group.workers ]  # Ensures ASG creates instances first
# }

# output "worker_instance_ips" {
#   description = "IPs of worker instances"
#   value       = data.aws_instances.workers.private_ips
# }