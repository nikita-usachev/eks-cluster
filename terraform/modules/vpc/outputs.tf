# Output for VPC

output "vpc_id" {
  value = aws_vpc.vpc.id
  description = "VPC ID"
  sensitive = false
}

# Public/Private Subnet ID's Output

output "public_subnets_ids" {
  value = aws_subnet.public_subnets.*.id
  description = "IDs of the created public subnets"
  sensitive = false
}

output "private_subnets_ids" {
  value = aws_subnet.private_subnets.*.id
  description = "IDs of the created private subnets"
  sensitive = false
}

output "sg_master_nodes" {
  value = aws_security_group.k8s-master-nodes.id
  description = "SG ID"
  sensitive = false
}

output "sg_worker_nodes" {
  value = aws_security_group.k8s-worker-nodes.id
  description = "SG ID"
  sensitive = false
}
