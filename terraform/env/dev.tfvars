# Provider AWS

region            = "us-east-1" # AWS region specification
ami_instance      = "ami-0aa7d40eeae50c9a9" # AWS AMI based on Linux 2
vpc_cidr          = "192.168.0.0/16" # VPC CIDR block where we are deploying VPC
cluster_name      = "main-eks-cluster-dev" # EKS cluster name
version_cluster   = "1.23" # Kubernetes version
instance_type     = "t3.medium" # Node's instance type
