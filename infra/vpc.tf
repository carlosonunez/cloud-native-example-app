data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" { # E: This module is not yet installed. Run "terraform init" to install all modules required by this configuration.
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.2.0"

  name = "example-app-vpc"
  cidr = "172.16.0.0/16"

  private_subnets = ["172.16.0.0/24",
    "172.16.1.0/24",
  "172.16.2.0/24"]
  public_subnets = ["172.16.3.0/24",
    "172.16.4.0/24",
  "172.16.5.0/24"]
  enable_nat_gateway = true
  azs                = slice(sort(data.aws_availability_zones.available.names), 0, 3)
}

