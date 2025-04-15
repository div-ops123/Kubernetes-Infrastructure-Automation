variable "common_tags" {
  description = "Common tags"
  type = map(string)
  default = {
    Terraform   = "true"
    Project = "url-shortener"
  }
}

variable "cidr" {
  description = "CIDR block for the VPC"
  type = string
  default = "10.0.0.0/16"
}

variable "private_subnets" {
  description = "The IPv4 CIDR block for the private subnet."
  type = list(string)
  default = [ "10.0.1.0/24", "10.0.2.0/24" ]
}

variable "public_subnets" {
  description = "The IPv4 CIDR block for the public subnet."
  type = list(string)
  default = [ "10.0.101.0/24", "10.0.102.0/24" ]
}
