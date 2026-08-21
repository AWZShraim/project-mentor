terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "s3" {
    bucket         = "mentor-tfstate-384668480848"
    key            = "api/terraform.tfstate"
    region         = "ca-central-1"
    dynamodb_table = "mentor-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

# --- Networking: reuse the account's default VPC rather than standing up a
# custom one. Good enough for a single-instance dev deployment; a proper
# multi-subnet/private-RDS VPC is Phase 4 territory once there's an actual
# distributed backend to justify it.

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# --- Database

resource "random_password" "db" {
  length  = 24
  special = false
}

resource "aws_security_group" "rds" {
  name        = "mentor-api-rds"
  description = "Mentor RDS instance - Postgres from the API instance only"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "Postgres from API instance"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "mentor" {
  identifier     = "mentor-db"
  engine         = "postgres"
  engine_version = "17"
  instance_class = "db.t4g.micro" # AWS free-tier eligible

  allocated_storage = 20 # gp3, within free-tier allowance
  storage_type       = "gp3"

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
  deletion_protection    = false
}

resource "aws_ssm_parameter" "database_url" {
  name  = "/mentor/api/database_url"
  type  = "SecureString"
  value = "postgresql+psycopg://${var.db_username}:${random_password.db.result}@${aws_db_instance.mentor.address}:5432/${var.db_name}"
}

# --- EC2 instance running the API

resource "aws_security_group" "ec2" {
  name        = "mentor-api-ec2"
  description = "Mentor API EC2 instance - API port open, no inbound SSH (uses SSM instead)"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "API"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "ec2" {
  name = "mentor-api-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# Grants Session Manager access (aws ssm start-session) without opening any
# inbound port at all — access is IAM-authenticated, not key/port-based.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "ssm_parameter_read" {
  name = "read-database-url-parameter"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "ssm:GetParameter"
      Resource = aws_ssm_parameter.database_url.arn
    }]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "mentor-api-ec2-profile"
  role = aws_iam_role.ec2.name
}

resource "aws_instance" "api" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro" # AWS free-tier eligible
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    aws_region            = var.aws_region
    database_url_param    = aws_ssm_parameter.database_url.name
    cognito_user_pool_id  = var.cognito_user_pool_id
    cognito_app_client_id = var.cognito_app_client_id
  })

  tags = {
    Name = "mentor-api"
  }

  depends_on = [aws_db_instance.mentor]
}

resource "aws_eip" "api" {
  instance = aws_instance.api.id
  domain   = "vpc"
}

output "api_public_ip" {
  value = aws_eip.api.public_ip
}

output "rds_endpoint" {
  value = aws_db_instance.mentor.address
}
