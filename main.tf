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