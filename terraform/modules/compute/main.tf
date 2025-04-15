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
      },
      {
        Effect   = "Allow"
        Action   = "ssm:DescribeParameters"
        Resource =  "*"
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
    exec > /var/log/user-data.log 2>&1  # Redirect output to a log file
    echo "Starting user data script"

    # Update package cache
    apt-get update -y
    echo "Apt update completed"

    # Install prerequisite packages
    apt-get install -y apt-transport-https curl containerd unzip
    echo "Prerequisites installed"

    # Install AWS CLI
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf awscliv2.zip aws
    echo "AWS CLI installed"

    # Configure containerd
    mkdir -p /etc/containerd
    containerd config default > /etc/containerd/config.toml
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    systemctl restart containerd
    echo "Containerd configured"

    # Add Kubernetes apt key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    # Add Kubernetes apt repository
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" > /etc/apt/sources.list.d/kubernetes.list

    # Update apt cache and install Kubernetes components
    apt-get update -y
    apt-get install -y kubelet kubeadm kubectl

    # Hold Kubernetes packages at the current version
    apt-mark hold kubelet kubeadm kubectl
    echo "Kubernetes components installed"

    # Disable swap
    swapoff -a
    sed -i '/swap/d' /etc/fstab

    # Load necessary kernel modules
    modprobe overlay
    modprobe br_netfilter

    # Set required sysctl parameters
    cat <<EOF > /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
    EOF
    sysctl --system
    echo "System configured"

    # Retry fetching join command until available
    MAX_ATTEMPTS=30
    ATTEMPT=1
    while ! JOIN_COMMAND=$(aws ssm get-parameter --name "/url-shortener-k8s/join-command" --with-decryption --query "Parameter.Value" --output text --region ${var.region_name}); do
      if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
        echo "Failed to fetch join command after $MAX_ATTEMPTS attempts"
        exit 1
      fi
      echo "Attempt $ATTEMPT: Join command not yet available, retrying in 10 seconds..."
      sleep 10
      ATTEMPT=$((ATTEMPT + 1))
    done
    echo "Join command fetched on attempt number $ATTEMPT: $JOIN_COMMAND"

    # Fetch the join command from SSM Parameter Store
    # JOIN_COMMAND=$(aws ssm get-parameter --name "/url-shortener-k8s/join-command" --with-decryption --query "Parameter.Value" --output text --region ${var.region_name})

    # Execute the join command
    $JOIN_COMMAND
    echo "Join command executed"
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
  min_size             = 0
  max_size             = 4
  desired_capacity     = 0                        # Start with 0 to delay worker provisioning, giving you time to initialize the master node with Ansible
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

  # Ensure master is up before launching workers
  depends_on = [aws_instance.master-node]
}