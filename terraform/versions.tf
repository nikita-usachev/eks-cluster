terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.55.0"
    }
    kubernetes = {
      version = ">= 1.10.0"
    }
  }
  backend "s3" {
    bucket = "terraform-state-files-inside"
    key    = "eks-cluster/terraform.tfstate"
    region = "us-east-1"
  }
}
