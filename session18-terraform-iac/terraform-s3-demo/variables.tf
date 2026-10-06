variable "aws_region" {
  type        = string
  description = "AWS region where the S3 bucket will be created."
  default     = "us-east-1"
}

variable "bucket_prefix" {
  type        = string
  description = "Prefix for the S3 bucket name (a random suffix is appended for global uniqueness)."
}

variable "environment" {
  type        = string
  description = "Environment tag value."
  default     = "dev"
}

variable "enable_versioning" {
  type        = bool
  description = "Enable object versioning on the bucket."
  default     = true
}
