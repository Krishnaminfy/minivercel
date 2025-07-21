variable "instance_name" {
  type        = string
  description = "Name of the EC2 instance"
}

variable "security_group_name" {
  type        = string
  description = "Name of the security group"
}

variable "docker_image" {
  type        = string
  description = "Docker image with tag"
}

variable "tag" {
  description = "Docker image tag"
  type        = string
  default     = "v1"
}

variable "ami_id" {
  type        = string
  default     = "ami-08abeca95324c9c91" 
}

variable "instance_type" {
  type        = string
  default     = "t2.micro"
}

# variable "port" {
#   description = "Port to expose the application"
#   type        = number
# }

variable "allowed_ssh_ip" {
  description = "Public IP allowed to access SSH"
  type        = string
}
