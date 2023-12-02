output "kubeconfig" {
  value = module.eks-kubeconfig.kubeconfig
  sensitive = true
}
