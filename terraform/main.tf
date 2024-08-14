provider "aws" {
    region = var.region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token = data.aws_eks_cluster_auth.cluster.token
}

# VPC Module

module "vpc" {
  source            = "./modules/vpc"
  cidr_vpc          = var.vpc_cidr
  ami_id            = var.ami_instance
  cluster_name      = var.cluster_name
}

module "main_eks_cluster" {
  source            = "./modules/eks"
  cluster_name      = var.cluster_name
  version_cluster   = var.version_cluster
  subnet_id_public  = module.vpc.public_subnets_ids
  subnet_id_private = module.vpc.private_subnets_ids
  master_sg_group   = module.vpc.sg_master_nodes 
  worker_sg_group   = module.vpc.sg_worker_nodes 
  vpc_id            = module.vpc.vpc_id
  instance_type     = var.instance_type
}
