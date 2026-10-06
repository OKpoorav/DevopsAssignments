# ---------- EC2 web server ----------
resource "aws_instance" "web" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data                   = file("${path.module}/user_data.sh")
  user_data_replace_on_change = true

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }

  # Explicit dependency: the instance needs a working internet route
  # (IGW + route table association) before user_data runs `dnf install`.
  # Terraform cannot infer this from attribute references, so we declare it.
  depends_on = [aws_route_table_association.public]

  tags = { Name = "${var.project}-web" }
}
