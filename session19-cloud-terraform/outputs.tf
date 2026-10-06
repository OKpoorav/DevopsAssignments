output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the public subnet."
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "ID of the web security group."
  value       = aws_security_group.web.id
}

output "ami_id" {
  description = "Amazon Linux 2023 AMI used for the instance."
  value       = data.aws_ami.al2023.id
}

output "instance_id" {
  description = "ID of the EC2 instance."
  value       = aws_instance.web.id
}

output "instance_public_ip" {
  description = "Public IP of the EC2 web server."
  value       = aws_instance.web.public_ip
}

output "web_url" {
  description = "URL of the hello page."
  value       = "http://${aws_instance.web.public_ip}"
}

output "s3_bucket_name" {
  description = "Name of the assets S3 bucket."
  value       = aws_s3_bucket.assets.bucket
}
