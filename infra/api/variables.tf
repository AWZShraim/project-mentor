variable "aws_region" {
  description = "AWS region for the API/DB deployment"
  type        = string
  default     = "ca-central-1"
}

variable "db_name" {
  type    = string
  default = "mentor"
}

variable "db_username" {
  type    = string
  default = "mentor"
}

variable "cognito_user_pool_id" {
  description = "Cognito user pool ID (from infra/auth)"
  type        = string
  default     = "ca-central-1_rzWWBgsMU"
}

variable "cognito_app_client_id" {
  description = "Cognito app client ID (from infra/auth)"
  type        = string
  default     = "l1s3vvoleb4goagluak1atg8o"
}
