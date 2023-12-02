data "aws_caller_identity" "self" {}

data "aws_region" "current" {}

resource "random_string" "role_suffix" {
  length  = 8
  special = false
  upper   = false
  numeric = false
}

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
    instance_types = ["t3g.medium"]
    capacity_type  = "SPOT"
    desired_size   = 1
    min_size       = 1
  }
  aws_auth_users = [
    {
      userarn  = data.aws_caller_identity.self.arn
      username = "self"
      groups   = ["system:masters"]
    }
  ]
}

module "eks-kubeconfig" {
  depends_on = [
    module.eks
  ]
  source       = "hyperbadger/eks-kubeconfig/aws"
  version      = "2.0.0"
  cluster_name = module.eks.cluster_name
}
