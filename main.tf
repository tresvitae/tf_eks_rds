terraform {
  required_providers {    
      aws = {      
          source  = "hashicorp/aws"
          version = "~> 3.0"
        }
        random = {
            version = ">= 2.1.2"
        }
  }
}

data "aws_caller_identity" "current" {}

data "archive_file" "lambda_zip" {
    type          = "zip"
    source_file   = "${path.module}/populate-nlb-tg-with-rds-private-ip.py"
    output_path   = "lambda_function_payload.zip"
}