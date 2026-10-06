variable "aws_region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "us-east-1"
}

variable "project" {
  type        = string
  description = "Project name used for resource names and tags."
  default     = "poorav-s19"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC."
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  type        = string
  description = "CIDR block for the public subnet."
  default     = "10.20.1.0/24"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type (free-tier eligible)."
  default     = "t3.micro"
}

variable "allowed_http_cidr" {
  type        = string
  description = "CIDR allowed to reach the web server on port 80."
  default     = "0.0.0.0/0"
}
