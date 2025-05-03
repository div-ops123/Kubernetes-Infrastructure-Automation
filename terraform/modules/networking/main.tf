

########################################################################
## Start of Security Groups

# Kubernetes Nodes SG:
resource "aws_security_group" "k8s-nodes-sg" {
  name        = "url-shortener-k8s-nodes-sg"
  description = "Security group for Kubernetes nodes"
  vpc_id      = aws_vpc.vpc.id

  tags = merge(var.common_tags, {"Name" = "url-shortener-k8s-nodes-sg"})
}

# Control Node SG:
resource "aws_security_group" "control-node-sg" {
  name        = "url-shortener-control-node-sg"
  description = "Security group for Control node"
  vpc_id      = aws_vpc.vpc.id

  tags = merge(var.common_tags, {"Name" = "url-shortener-control-node-sg"})
}


locals {
  ingress_rules = {
    # Allow traffic from the Load Balancer to NodePorts
    k8s_nodes_from_alb = {
      from_port   = 30000   # NodePort range for LoadBalancer services
      to_port     = 32767
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]  # Update to ELB SG after deployment
    },
    # Allow SSH from control node
    k8s_nodes_from_control_node_ssh = {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      source_sg   = "control-node-sg"  # Static key, resolved later
    },
    # Allow control node to talk to Kubernetes API Server
    k8s_nodes_from_control_node_api = {
      from_port   = 6443
      to_port     = 6443
      protocol    = "tcp"
      source_sg   = "control-node-sg"  # Static key, resolved later
    },
    # Kubernetes API server
    k8s_nodes_api = {
      from_port   = 6443
      to_port     = 6443
      protocol    = "tcp"
      source_sg   = "k8s-nodes-sg"  # Self-reference
    },
    # etcd communication
    k8s_nodes_etcd = {
      from_port   = 2379
      to_port     = 2380
      protocol    = "tcp"
      source_sg   = "k8s-nodes-sg"  # Self-reference
    },
    # Kubelet communication
    k8s_nodes_kubelet = {
      from_port   = 10250
      to_port     = 10252
      protocol    = "tcp"
      source_sg   = "k8s-nodes-sg"  # Self-reference
    },
    # All TCP traffic between nodes (e.g., pod-to-pod communication)
    k8s_nodes_all = {
      from_port   = 0
      to_port     = 65535
      protocol    = "tcp"
      source_sg   = "k8s-nodes-sg"  # Self-reference
    }
  }
}


locals {
  control_node_ingress_rules = {
    # New rule for Flask app testing locally
    control_node_from_flask = {
      from_port   = 5000
      to_port     = 5000
      protocol    = "tcp"
    }

    # SSH rule
    control_node_from_ssh = {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
    }
  }
}

# Cotrol node SG
resource "aws_security_group_rule" "control-node-ingress" {
  for_each = local.control_node_ingress_rules

  type              = "ingress"                   # Direction - Inbound
  description       = "Control Node Inbound rule"
  from_port         = each.value.from_port                       
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = ["0.0.0.0/0"]                # Destination - Allows inbound traffic from anywhere
  security_group_id = aws_security_group.control-node-sg.id # Source - Rule is attached to Control node's sg.
}

# Restrict: Allow control node to outbound traffic to Kubernetes API server(port 6443) on all K8s nodes
resource "aws_security_group_rule" "control-node-egress" {
  type              = "egress"       
  description       = "Allow control-node to reach any IP on the internet"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.control-node-sg.id  # Source - Rule is attached to the Control Node’s security group.
  cidr_blocks       = ["0.0.0.0/0"]                          # Destination - Send traffic to anywhere in and out of VPC
}

# Handles rules with cidr_blocks (e.g., k8s_nodes_from_alb)
resource "aws_security_group_rule" "k8s-nodes-ingress-cidr" {
  for_each          = { for k, v in local.ingress_rules : k => v if lookup(v, "cidr_blocks", null) != null }

  type              = "ingress"
  description       = "Ingress rule for k8s nodes from CIDR"
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = each.value.cidr_blocks
  security_group_id = aws_security_group.k8s-nodes-sg.id
}

# Handles rules with source_sg
resource "aws_security_group_rule" "k8s-nodes-ingress-sg" {
  for_each          = { for k, v in local.ingress_rules : k => v if lookup(v, "source_sg", null) != null }

  type              = "ingress"
  description       = "Ingress rule for k8s nodes from SG"
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  security_group_id = aws_security_group.k8s-nodes-sg.id
  source_security_group_id = (
    each.value.source_sg == "control-node-sg" ? aws_security_group.control-node-sg.id :
    each.value.source_sg == "k8s-nodes-sg" ? aws_security_group.k8s-nodes-sg.id :
    null  # Add more conditions if needed
  )
}

resource "aws_security_group_rule" "k8s-nodes-egress" {
  type              = "egress"
  description       = "allow all"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"               # No restrictions on protocol 
  cidr_blocks       = [ "0.0.0.0/0" ]    # Destination - Allows outbound traffic from nodes to anywhere (inside or outside the VPC). Not secure: Restrict to a NAT Gateway
  security_group_id = aws_security_group.k8s-nodes-sg.id  # Source - Rule is attached to k8s nodes's sg.
}
## End of Security Group
########################################################################


