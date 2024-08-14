# VPC

output "vpc_id" {
  description = "VPC ID for refencing in VPC config in EKS cluster"
  value = module.vpc.vpc_id
}

output "config_map_aws_auth" {
  description = "Basically outputed yaml file of creation ConfigMap for cluster and assuming self-managed nodes"
  value = module.main_eks_cluster.config_map_aws_auth
}
