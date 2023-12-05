# NOTE: This file is copied into the test container at test runtime.
# This works around Terratest's lack of dynamic provider configuration.
terraform {
  required_providers {
    aws = {
      version = "5.29.0"
      source  = "hashicorp/aws"
    }
  }
}

provider "aws" {
  version = "5.29.0"
  region = "us-east-2"
  endpoints {
    eks = "http://localstack:4566"
    ec2 = "http://localstack:4566"
    cloudwatch = "http://localstack:4566"
    kms = "http://localstack:4566"
    iam = "http://localstack:4566"
  }
}
