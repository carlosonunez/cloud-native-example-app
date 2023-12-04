data "aws_region" "current" {}
data "aws_caller_identity" "self" {}

module "eks" {
  source                         = "terraform-aws-modules/eks/aws"
  version                        = "19.20.0"
  cluster_name                   = "example-app-cluster"
  cluster_version                = "1.27"
  cluster_endpoint_public_access = true
  cluster_addons = {
    coredns = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
    }
    vpc-cni = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
  }
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.public_subnets
  eks_managed_node_group_defaults = {
    instance_types = ["t4g.medium"]
    capacity_type  = "SPOT"
    desired_size   = 1
    min_size       = 1
    max_size       = 1
  }
  eks_managed_node_groups = {
    default = {
      ami_type = "BOTTLEROCKET_ARM_64"
    }
  }
  aws_auth_accounts = [
    data.aws_caller_identity.self.account_id
  ]
}
