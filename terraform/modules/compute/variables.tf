variable "common_tags" {
  description = "Common tags"
  type = map(string)
  default = {
    Terraform   = "true"
    Project = "url-shortener"
  }
}

variable "home_dir" {
  description = "Directory where keys are"
  type        = string
  default     = "/home/ubuntu"
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

variable "region_name" {
  description = "AWS Region to deploy resources to."
  type = string
  default = "af-south-1"
}