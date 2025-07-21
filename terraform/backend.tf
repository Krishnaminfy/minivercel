# terraform {
#   backend "s3" {
#     bucket         = "krish-vercello-states"
#     key            = "apps/${var.instance_name}/terraform.tfstate"
#     region         = "ap-south-1"
#     encrypt        = true
#     dynamodb_table = "krish-vercello-lock"
#   }
# }
