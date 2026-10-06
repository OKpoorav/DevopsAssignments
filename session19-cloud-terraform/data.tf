# Availability zones in the selected region
data "aws_availability_zones" "available" {
  state = "available"
}

# Latest Amazon Linux 2023 AMI (x86_64) published by Amazon
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
