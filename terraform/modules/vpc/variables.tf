# Variables for VPC module

variable "ami_id" {
  type = string
}

variable "cidr_vpc" {
  description = "CIDR block of our VPC"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name" 
  type        = string
}
