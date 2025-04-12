# Provision EC2 instances in the private subnets to form a Kubernetes cluster
# Provision 1 EC2 instance in a public subnet for Ansible Control Node to Manage the Kubernetes Nodes

# key-pair for the ec2 instances for ssh access
# Generate SSH key locally, e.g., ssh-keygen -t rsa -f ~/.ssh/control-node-key -N ""
# Place it in your home_dir/.ssh folder
resource "aws_key_pair" "control-node" {
  key_name   = "control-node-key"
  public_key = file("${var.home_dir}/.ssh/control-node-key.pub")
}

# This tells Terraform to fetch information about the current AWS account — which you're using to build the ARN.
data "aws_caller_identity" "current" {}

# This uses AWS Systems Manager to get Canonical’s latest stable 24.04 AMI
data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

# Control node: Acts as a `bastion host` for Ansible to access private nodes.
resource "aws_instance" "control-node" {
  ami           = data.aws_ssm_parameter.ubuntu_ami.value   # .value gives the AMI ID string
  instance_type = "t3.medium"
  subnet_id     = var.public_subnet_ids[0]                  # AZ-1 first public subnet.
  vpc_security_group_ids = [ var.control_node_sg_id ]
  key_name      = aws_key_pair.control-node.key_name            # public key (control-node-key.pub) is automatically added to /home/ubuntu/.ssh/authorized_keys on control-node vm
  associate_public_ip_address = true                        # Since it’s in a public subnet
  
  tags = merge(var.common_tags, {Name = "control-node"})
}


resource "aws_key_pair" "url-shortener" {
  key_name   = "url-shortener-key"
  public_key = file("/home/ubuntu/.ssh/url-shortener.pub")  # Path on control-node
}

#######################################
# Start of IAM Role

# define the IAM role and policy for accessing the SSM parameter:
# The `aws_iam_role` allows EC2 instances to assume the role.
resource "aws_iam_role" "worker_nodes" {
  name = "worker-nodes-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# `aws_iam_policy` grants permission to read the specific SSM parameter
resource "aws_iam_policy" "worker_nodes_ssm_access" {
  name        = "worker-nodes-ssm-access"
  description = "Allow worker nodes to read the join command from SSM Parameter Store"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ssm:GetParameter"
        Resource = "arn:aws:ssm:${var.region_name}:${data.aws_caller_identity.current.account_id}:parameter/url-shortener-k8s/join-command"
      }
    ]
  })
}

# `aws_iam_role_policy_attachment` attaches the policy to the role
resource "aws_iam_role_policy_attachment" "worker_nodes_ssm_access" {
  role       = aws_iam_role.worker_nodes.name
  policy_arn = aws_iam_policy.worker_nodes_ssm_access.arn
}
# End of IAM Role
#############################################


resource "aws_instance" "master-node" {
  ami           = data.aws_ssm_parameter.ubuntu_ami.value   # .value gives the AMI ID string
  instance_type = "t3.medium"
  subnet_id     = var.private_subnet_ids[0]                 # AZ-1 first private subnet
  vpc_security_group_ids = [ var.k8s_nodes_sg_id ]
  key_name      = aws_key_pair.url-shortener.key_name            # public key (note-app-key.pub) is automatically added to /home/ubuntu/.ssh/authorized_keys
  associate_public_ip_address = false                       # Private Subnet

  tags = merge(var.common_tags, {Name = "master-node"})
}



##################################
# Create aws_launch_template + aws_autoscaling_group "worker-node" (2-4 instances, private subnets).
# aws_launch_template + aws_autoscaling_group (ASG) automatically launched the worker instances.
# The ASG uses the launch template to create instances based on the desired_capacity (set to 2 in your case). 
# It manages the lifecycle of those instances (launching, terminating, scaling) automatically.
##################################
# 1. Attach the IAM Role to the Launch Template
resource "aws_iam_instance_profile" "worker_nodes" {
  name = "worker-nodes-instance-profile"
  role = aws_iam_role.worker_nodes.name
}

# Launch Template: Defines worker node config
resource "aws_launch_template" "worker-node" {
  name_prefix   = "url-shortener-worker-node-"
  image_id      = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type = "t3.medium"
  key_name      = aws_key_pair.url-shortener.key_name
  vpc_security_group_ids = [ var.k8s_nodes_sg_id ]  # Get from vpc module

  iam_instance_profile {
    name = aws_iam_instance_profile.worker_nodes.name
  }

  user_data = base64encode(<<-EOT
    #!/bin/bash
    set -e

    # Fetch the join command from SSM Parameter Store
    JOIN_COMMAND=$(aws ssm get-parameter --name "/url-shortener-k8s/join-command" --query "Parameter.Value" --output text --region ${var.region_name})

    # Execute the join command
    $JOIN_COMMAND
  EOT
  )

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.common_tags, 
      {
        Name = "worker-node"
        KubernetesRole = "worker"
      }
    )
  }
}

# ASG: Manages 2-4 worker instances across private subnets
# Ensure ASG tags propagate(spread widely) to Instances
resource "aws_autoscaling_group" "workers" {
  name                 = "url-shortener-workers"
  desired_capacity     = 2
  max_size             = 4
  min_size             = 2
  vpc_zone_identifier = var.private_subnet_ids    # Distributes instances across both AZs

  launch_template {
    id      = aws_launch_template.worker-node.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "worker-node"
    propagate_at_launch = true
  }
  tag {
    key                 = "KubernetesRole"
    value               = "worker"
    propagate_at_launch = true
  }
}