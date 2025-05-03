variable "common_tags" {
  description = "Common tags"
  type = map(string)
  default = {
    Terraform   = "true"
    Project = "url-shortener"
  }
}
