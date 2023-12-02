terraform {
  backend "s3" {}
  required_providers {
    aws = {
      version = "5.29.0"
      source  = "hashicorp/aws"
    }
  }
}
