# Cluster

variable "cluster_name" {
  description = "EKS cluster name" 
  type        = string
}

variable "version_cluster" {
  description = "Kubernetes version for our EKS cluster" 
  type        = string
}

variable "subnet_id_public" {
  description = "IDs of Public Subnets" 
}

variable "subnet_id_private" {
  description = "IDs of Private Subnets" 
}

variable "master_sg_group" {
  description = "Security group for the Master Nodes in Cluster" 
}

variable "worker_sg_group" {
  description = "Security group for the Worker Nodes in Cluster" 
}

variable "vpc_id" {
  description = "Variable of output to referencing our VPC ID in EKS cluster"
}

variable "instance_type" {
  description = "Instance compute capacity type" 
  type    = string
}
