# Purpose: Pins Terraform and provider versions and configures remote state management.

terraform {
  required_version = ">= 1.11.2"


  # The code below assumes that the dynamoDB table and the s3 bucket where the terraform.tfstate file will be saved have previously been created.
  backend "s3" {
    bucket = "divine-note-app-store-tf-state"
    key    = "state/terraform.tfstate"
    region = "af-south-1"
    dynamodb_table = "tf-locks"
  }

}

