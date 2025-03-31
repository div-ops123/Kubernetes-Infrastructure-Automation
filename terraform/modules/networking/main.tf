resource "aws_vpc" "note-app-vpc" {
  cidr_block = var.cidr
  tags = merge(
    var.common_tags,
    {
      "Name" = "note-app-vpc"
    }
  )
}

# The Availability Zones data source allows access to the list of AWS Availability Zones which can be accessed by an AWS account within the region configured in the provider.
data "aws_availability_zones" "available" {
  state = "available"
}

# Create subnets in the first two available availability zones
resource "aws_subnet" "note-app-public-subnets" {
  count = length(var.public_subnets)

  vpc_id     = aws_vpc.note-app-vpc.id
  cidr_block = var.public_subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(
    var.common_tags,
    {
      "Name" = "public-subnet-${count.index + 1}"
    }
  )
}

resource "aws_subnet" "note-app-private-subnets" {
  count = length(var.private_subnets)

  vpc_id     = aws_vpc.note-app-vpc.id
  cidr_block = var.private_subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

# Tags combine static inputs with dynamic names.
  tags = merge(
    var.common_tags,
    {
      "Name" = "private-subnet-${count.index + 1}"
    }
  )
}

# Set up an Internet Gateway and route table for public access.