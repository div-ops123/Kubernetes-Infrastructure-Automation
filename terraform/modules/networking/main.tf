resource "aws_vpc" "vpc" {
  cidr_block = var.cidr
  tags = merge(
    var.common_tags,
    {
      "Name" = "note-app-vpc"
    }
  )
}

########################################################################
## Start of Subnets
# The Availability Zones data source allows access to the list of AWS Availability Zones which can be accessed by an AWS account within the region configured in the provider.
data "aws_availability_zones" "available" {
  state = "available"
}

# Create subnets in the first two available availability zones
resource "aws_subnet" "public-subnets" {
  count = length(var.public_subnets)

  vpc_id     = aws_vpc.vpc.id
  cidr_block = var.public_subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(
    var.common_tags,
    {
      "Name" = "note-app-public-subnet-${count.index + 1}"
    }
  )
}

resource "aws_subnet" "private-subnets" {
  count = length(var.private_subnets)

  vpc_id     = aws_vpc.vpc.id
  cidr_block = var.private_subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  # Tags combine static inputs with dynamic names.
  tags = merge(
    var.common_tags,
    {
      "Name" = "note-app-private-subnet-${count.index + 1}"
    }
  )
}
## End of Subnets
########################################################################


# An aws_internet_gateway attached to the VPC, enabling public subnet internet access.
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(
    var.common_tags,
    {
      "Name" = "note-app-igw"
    }
  )
}

########################################################################
#### Start of Route Tables.
## Public Route Table: A Route Table is a container that holds multiple routes.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(var.common_tags, {"Name" = "note-app-public-rt"})
}

# A Route specifies how to send traffic for a certain destination (e.g., internet, another VPC, a VPN).
resource "aws_route" "public-internet" {
  route_table_id            = aws_route_table.public.id
  destination_cidr_block    = "0.0.0.0/0"                   # All non-VPC traffic
  gateway_id                =  aws_internet_gateway.igw.id  # Sends all non-VPC traffic to the IGW
}

# Attach a Route Table and a Public Subnet
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets)
  subnet_id      = aws_subnet.public-subnets[count.index].id
  route_table_id = aws_route_table.public.id
}

## Private Route Table:
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(var.common_tags, {"Name" = "note-app-private-rt"})
}

# Route: Local route (10.0.0.0/16 → local) is auto-added.
# Traffic between subnets (e.g., private subnet nodes talking to each other or to the ALB in public subnets) uses this route. 
# local = the VPC itself, Nodes in private subnet can reach ALB, and themselselves, but not the internet because NAT Gateway is not added yet.

# Creates an Association between a Route Table and an Internet Gateway
resource "aws_route_table_association" "private" {
  count = length(var.private_subnets)
  subnet_id = aws_subnet.private-subnets[count.index].id
  route_table_id = aws_route_table.private.id
}
## End of Route Table
########################################################################


########################################################################
## Start of Security Groups

# ALB SG - HTTP traffic from ALB to nodes
resource "aws_security_group" "alb-sg" {
  name        = "note-app-ALB-sg"
  description = "Allows public HTTP traffic to the ALB and forwards to kubernetes nodes"
  vpc_id      = aws_vpc.vpc.id

  tags = merge(var.common_tags, {"Name" = "note-app-alb-sg"})
}

# Kubernetes Nodes SG:
resource "aws_security_group" "k8s-nodes-sg" {
  name        = "note-app-k8s-nodes-sg"
  description = "Security group for Kubernetes nodes"
  vpc_id      = aws_vpc.vpc.id

  tags = merge(var.common_tags, {"Name" = "note-app-k8s-nodes-sg"})
}

# If you have multiple local values, create locals.tf for better organization.
locals {
  ingress_rules = {
    k8s_nodes_from_alb = {
      from_port   = 30000 # NodePort services
      to_port     = 32767
      protocol    = "tcp"
      source_sg   = aws_security_group.alb-sg.id
    },
    k8s_nodes_api = {
      from_port   = 6443
      to_port     = 6443
      protocol    = "tcp"
      source_sg   = aws_security_group.k8s-nodes-sg.id
    },
    k8s_nodes_etcd = {
      from_port   = 2379
      to_port     = 2380
      protocol    = "tcp"
      source_sg   = aws_security_group.k8s-nodes-sg.id
    },
    k8s_nodes_kubelet = {
      from_port   = 10250
      to_port     = 10252
      protocol    = "tcp"
      source_sg   = aws_security_group.k8s-nodes-sg.id
    },
    k8s_nodes_all = {
      from_port   = 0
      to_port     = 65535
      protocol    = "tcp"
      source_sg   = aws_security_group.k8s-nodes-sg.id
    }
  }
}

resource "aws_security_group_rule" "alb-ingress" {
  type              = "ingress"                   # Direction - Inbound
  description       = "HTTP ingress"
  from_port         = 3000                        # my app.js app runs on port 3000
  to_port           = 3000
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]                # Destination - Allows inbound traffic from anywhere (inside or outside the VPC).
  security_group_id = aws_security_group.alb-sg.id # Source - Rule is attached to ALB's sg.
}

# ALB can forward traffic to Kubernetes nodes only
resource "aws_security_group_rule" "alb-egress" {
  type              = "egress"            # Direction - Outbound
  description       = "Limits the ALB to talk only to the worker node group, not the whole internet."
  from_port         = 30000               # NodePort range, meaning ALB can forward traffic to the app running in Kubernetes.
  to_port           = 32767
  protocol          = "tcp"
  security_group_id = aws_security_group.alb-sg.id  # Source - Rule is attached to the ALB’s security group.
  source_security_group_id = aws_security_group.k8s-nodes-sg.id # Destination - Where to send traffic to.
}

# Kubernetes nodes can receive traffic from 
resource "aws_security_group_rule" "k8s-nodes-ingress" {
  for_each          = local.ingress_rules     # Uses for_each to create multiple security group rules dynamically.

  type              = "ingress"
  description       = "HTTP ingress"
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  source_security_group_id = each.value.source_sg         # Destination - Where to send traffic to.
  security_group_id = aws_security_group.k8s-nodes-sg.id  # Source - Rule is attached to k8s nodes's sg.
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


