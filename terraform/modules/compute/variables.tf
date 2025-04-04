variable "common_tags" {
  description = "Common tags"
  type = map(string)
  default = {
    Terraform   = "true"
    Environment = "dev"
  }
}

variable "home_dir" {
  description = "Home directory"
  type        = string
  default     = "/home/ec2-user"
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "k8s_nodes_sg_id" {
  description = "Security group ID for Kubernetes nodes"
  type        = string
}

variable "control_node_sg_id" {
  description = "Security group ID for Control Node"
  type        = string
}
