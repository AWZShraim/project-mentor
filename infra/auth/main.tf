terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "mentor-tfstate-384668480848"
    key            = "auth/terraform.tfstate"
    region         = "ca-central-1"
    dynamodb_table = "mentor-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_cognito_user_pool" "mentor" {
  name = "mentor-users"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = false
  }
}

resource "aws_cognito_user_pool_client" "ios" {
  name         = "mentor-ios-client"
  user_pool_id = aws_cognito_user_pool.mentor.id

  # Native/mobile clients must never hold a secret.
  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH", # convenient for CLI/testing; SRP is what the app itself should use
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}

output "user_pool_id" {
  value = aws_cognito_user_pool.mentor.id
}

output "user_pool_client_id" {
  value = aws_cognito_user_pool_client.ios.id
}
