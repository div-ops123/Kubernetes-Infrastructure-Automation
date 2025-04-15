terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # kubernetes = {
    #   source = "hashicorp/kubernetes"
    #   version = "2.36.0"
    # }
  }
}

# Configure the AWS Provider
provider "aws" {
    region = var.region_name
}

# # Configure the Kubernetes Provider
# provider "kubernetes" {
#   config_path = "/home/ubuntu/url-shortener-k8s-project/Kubernetes-Infrastructure-Automation/ansible/playbooks/kubeconfig"  # Path to your kubeconfig
# }