# Provision EC2 instances in the private subnets to form a Kubernetes cluster
# Provision 1 EC2 instance in a public subnet for Ansible Control Node to Manage the Kubernetes Nodes

# key-pair for the ec2 instances for ssh access
# Generate SSH key locally, e.g., ssh-keygen -f note-app-key
# Place it in your home_dir/.ssh folder
resource "aws_key_pair" "note-app" {
  key_name   = "note-app-key"
  public_key = file("${var.home_dir}/.ssh/note-app-key.pub")
}

# This uses AWS Systems Manager to get Canonical’s latest stable 24.04 AMI
data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

# Ubuntu EC2 instance for master node using AMI lookup
# data "aws_ami" "ubuntu" {
#   most_recent = true
#   filter {
#     name   = "name"
#     values = ["ubuntu/images/hvm-ssd/ubuntu-noble-24.04-amd64-server-*"]
#     # values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
#   }
#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }
#   owners = ["099720109477"] # Canonical
# }

# Control node: Acts as a `bastion host` for Ansible to access private nodes.
resource "aws_instance" "control-node" {
  ami           = data.aws_ssm_parameter.ubuntu_ami.value   # .value gives the AMI ID string
  instance_type = "t3.medium"
  subnet_id     = var.public_subnet_ids[0]                  # AZ-1 first public subnet.
  vpc_security_group_ids = [ var.control_node_sg_id ]
  key_name      = aws_key_pair.note-app.key_name            # public key (note-app-key.pub) is automatically added to /home/ubuntu/.ssh/authorized_keys
  associate_public_ip_address = true                        # Since it’s in a public subnet
  
  tags = merge(var.common_tags, {Name = "control-node"})
}

resource "aws_instance" "master-node" {
  # ami           = data.aws_ami.ubuntu.id
  ami           = data.aws_ssm_parameter.ubuntu_ami.value   # .value gives the AMI ID string
  instance_type = "t3.medium"
  subnet_id     = var.private_subnet_ids[0]                 # AZ-1 first private subnet
  vpc_security_group_ids = [ var.k8s_nodes_sg_id ]
  key_name      = aws_key_pair.note-app.key_name            # public key (note-app-key.pub) is automatically added to /home/ubuntu/.ssh/authorized_keys
  associate_public_ip_address = false                       # Private Subnet, no public IP needed yet; Ansible can use a bastion or NAT later if required

  tags = merge(var.common_tags, {Name = "master-node"})
}

##################################
# Create aws_launch_template + aws_autoscaling_group "worker-node" (2-4 instances, private subnets).
# aws_launch_template +d aws_autoscaling_group (ASG) automatically launched the worker instances.
# The ASG uses the launch template to create instances based on the desired_capacity (set to 2 in your case). 
# It manages the lifecycle of those instances (launching, terminating, scaling) automatically.
##################################
# Launch Template: Defines worker node config
resource "aws_launch_template" "worker-node" {
  name_prefix   = "note-app-worker-node-"
  image_id      = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type = "t3.medium"
  key_name      = aws_key_pair.note-app.key_name
  vpc_security_group_ids = [ var.k8s_nodes_sg_id ]  # Get from vpc module

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
  name                 = "note-app-workers"
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