#!/bin/bash

# Define directory name for the Terraform project
project_dir="my_terraform_project"

# Create the project directory and subdirectories
mkdir -p "$project_dir"
cd "$project_dir"
mkdir -p {modules,scripts}

# Initialize Terraform Files
echo "Creating Terraform configuration files..."

# Provider Configuration
cat <<EOF > provider.tf
provider "aws" {
  region  = "us-east-1"
  version = "~> 3.0"
}
EOF

# Security Groups
cat <<EOF > security_groups.tf
resource "aws_security_group" "ALBFrontEnd" {
  name        = "ALBFrontEnd"
  description = "Security group for ALB Frontend"
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.EC2BackEnd.id]
  }
}

resource "aws_security_group" "EC2BackEnd" {
  name        = "EC2BackEnd"
  description = "Security group for EC2 Backend"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.ALBFrontEnd.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
EOF

# KMS Key
cat <<EOF > kms.tf
resource "aws_kms_key" "MyDataKey" {
  description             = "KMS key for data encryption"
  is_enabled              = true
  enable_key_rotation     = true
  policy                  = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"AWS": "arn:aws:iam::YOUR_ACCOUNT_ID:user/YOUR_USER"},
      "Action": "kms:*",
      "Resource": "*"
    }
  ]
}
POLICY
}
EOF

# S3 Bucket
cat <<EOF > s3.tf
resource "aws_s3_bucket" "webapp_bucket" {
  bucket = "source-files-ec2-webapp-UNIQUE_ID"
  acl    = "private"
  versioning {
    enabled = true
  }
  lifecycle_rule {
    id      = "log"
    enabled = true
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}
EOF

# IAM Role
cat <<EOF > iam.tf
resource "aws_iam_role" "ec2_ssm_s3_role" {
  name = "ec2-ssm-s3"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      },
    ]
  })
}
resource "aws_iam_role_policy_attachment" "ssm_attachment" {
  role       = aws_iam_role.ec2_ssm_s3_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy_attachment" "s3_readonly_attachment" {
  role       = aws_iam_role.ec2_ssm_s3_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}
EOF

# ACM Certificate
# Note: ACM and Route53 configurations require manual intervention for DNS validation.
#       This script will not automatically validate the ACM certificate.
cat <<EOF > acm.tf
resource "aws_acm_certificate" "cert" {
  domain_name               = "dctlabs.com"
  subject_alternative_names = ["alb.dctlabs.com"]
  validation_method         = "DNS"
}
# Route53 record for ACM DNS validation will be added after 'aws_acm_certificate' is created.
EOF

# Initialize Terraform (downloads provider plugins)
echo "Initializing Terraform..."
terraform init

# Create a Terraform plan
echo "Creating Terraform plan..."
terraform plan -out=tfplan

# Instructions
echo "Terraform project setup is complete. Review and apply the plan as needed."
