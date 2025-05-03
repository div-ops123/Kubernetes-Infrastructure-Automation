resource "aws_vpc" "vpc" {
  cidr_block = var.cidr
  tags = merge(
    var.common_tags,
    {
      "Name" = "url-shortener-vpc"
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
      "Name" = "url-shortener-public-subnet-${count.index + 1}"
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
      "Name" = "url-shortener-private-subnet-${count.index + 1}"
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
      "Name" = "url-shortener-igw"
    }
  )
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"  # Ensures the EIP is allocated within the VPC

  tags = merge(var.common_tags, {"Name" = "url-shortener-nat-eip"})
}

resource "aws_nat_gateway" "nat-gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public-subnets[0].id         # AZ-1 first public subnet ID

  tags = merge(var.common_tags, {"Name" = "url-shortener-nat"})

  # To ensure proper ordering, Explicit dependency on the Internet Gateway
  depends_on = [aws_internet_gateway.igw]
}


########################################################################
#### Start of Route Tables.
## Public Route Table: A Route Table is a container that holds multiple routes.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(var.common_tags, {"Name" = "url-shortener-public-rt"})
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

  tags = merge(var.common_tags, {"Name" = "url-shortener-private-rt"})
}

# Route: Local route (10.0.0.0/16 → local) is auto-added.
# Route for NAT Gateway in Private Route Table
resource "aws_route" "private-nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"                    # All outbound traffic
  nat_gateway_id         = aws_nat_gateway.nat-gateway.id # Directs traffic to the NAT Gateway
}

# Creates an Association between a Route Table and an Internet Gateway
resource "aws_route_table_association" "private" {
  count = length(var.private_subnets)                     # Dynamically associates each subnet in var.private_subnets
  subnet_id = aws_subnet.private-subnets[count.index].id
  route_table_id = aws_route_table.private.id             # Associates all private subnets with the private route table
}
## End of Route Table
########################################################################
