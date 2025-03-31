provider "aws" {
    region = "af-south-1" # avoid hardcode later
}

resource "aws_s3_bucket" "tf-state" {
  bucket = "divine-note-app-store-tf-state"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "tf-state-versioning" {
  bucket = aws_s3_bucket.tf-state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf-state-encryp" {
  bucket = aws_s3_bucket.tf-state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf-state-public-access" {
  bucket = aws_s3_bucket.tf-state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [aws_s3_bucket.tf-state]
}

resource "aws_dynamodb_table" "tf-locks" {
  name           = "tf-locks"
  billing_mode   = "PAY_PER_REQUEST"  # Cost-effective for infrequent use
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"  # String type for lock ID
  }
}