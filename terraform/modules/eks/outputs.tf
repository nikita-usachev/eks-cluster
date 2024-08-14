output "config_map_aws_auth" {
  description = "Basically outputed yaml file of creation ConfigMap for cluster and assuming self-managed nodes"
  value = "${local.config_map_aws_auth}"
}
