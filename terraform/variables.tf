# VPC

variable "region" {
  description = "AWS Region" 
  type        = string
}

variable "ami_instance" {
  description = "VPC AMI Amazon Linux based"   
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of our VPC" 
  type        = string
}

# Cluster

variable "cluster_name" {
  description = "EKS cluster name" 
  type        = string
}

variable "version_cluster" {
  description = "Kubernetes version for our EKS cluster" 
  type        = string
}

variable "instance_type" { # Instance type configuration for AWS Launch Template
  description = "Instance compute capacity type" 
  type    = string
}
