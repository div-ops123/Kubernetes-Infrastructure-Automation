# You can Override the Region (e.g., to us-east-1) using a terraform.tfvars file or the CLI (-var "region_name=us-east-1") without modifying the code.
variable "region_name" {
  description = "AWS Region to deploy resources to."
  type = string
  default = "af-south-1"
}
