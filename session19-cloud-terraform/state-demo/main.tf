# Offline demo of the full Terraform lifecycle (state, dependencies, apply, destroy)
# using providers that need no cloud account.
terraform {
  required_providers {
    random = { source = "hashicorp/random", version = "~> 3.6" }
    local  = { source = "hashicorp/local", version = "~> 2.5" }
  }
}

variable "student" {
  type    = string
  default = "Poorav Kumar Gupta (24bcs10080)"
}

resource "random_pet" "server" {
  length = 2
}

# Implicit dependency: references random_pet.server.id
resource "local_file" "hello" {
  filename = "${path.module}/hello.txt"
  content  = "Hello ${var.student}! Your server name is ${random_pet.server.id}\n"
}

# Explicit dependency
resource "random_integer" "port" {
  min        = 8000
  max        = 8999
  depends_on = [local_file.hello]
}

output "server_name" { value = random_pet.server.id }
output "port" { value = random_integer.port.result }
