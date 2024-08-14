# EKS cluster

resource "aws_eks_cluster" "eks" {
  name     = "${var.cluster_name}"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "${var.version_cluster}"

  depends_on = [
    aws_iam_role_policy_attachment.amazon_eks_cluster_eks-policy,
    aws_iam_role_policy_attachment.amazon-eks-resource-controller-policy,
  ]
  
  vpc_config {
    endpoint_private_access = true # indicates whether or not the EKS private API servcer endpoint is enabled
    endpoint_public_access  = true # indicates whether or not the EKS public API server endpoint is enabled 

    subnet_ids         = var.subnet_id_public
    security_group_ids = ["${var.master_sg_group}"]
  }
  
  tags = {
    Name = "${var.cluster_name}-terraform-cluster"
  }
}

# Extracting the latest version of AMI that we need for EKS nodes from AWS
# Amazon Linux AMI is built on top of Amazon Linux 2, and is configured to serve as the base image for Amazon EKS nodes.

data "aws_ami" "eks_ami" {
  most_recent = true
  filter {
    name   = "name"
    values = ["amazon-eks-node-${var.version_cluster}-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  } 
  owners = ["amazon"] 
}

# Creating instance profile

resource "aws_iam_instance_profile" "node_instance_profile" {
  name = "eks-node-instance-profile-${var.cluster_name}"
  role = aws_iam_role.node_groups.name
}

# Injecting user data into data block

data "template_file" "user_data" {
  template = file("../../tf-modules/eks-tf/user-data.tpl")

  vars = {
    CLUSTER_NAME          = "${var.cluster_name}"
    ENDPOINT              = "${aws_eks_cluster.eks.endpoint}"
    CERTIFICATE_AUTHORITY = "${aws_eks_cluster.eks.certificate_authority.0.data}"

  }
}

# EKS self managed node groups

resource "aws_launch_template" "masters-k8s" {
  name                    = "${var.cluster_name}-template-22c"
  image_id                = data.aws_ami.eks_ami.image_id
  instance_type           = var.instance_type
  vpc_security_group_ids  = [var.worker_sg_group]
  user_data               = base64encode(data.template_file.user_data.rendered)
  ebs_optimized           = true

  block_device_mappings {
    device_name             = "/dev/xvda"
    ebs {
      volume_size           = 40
      volume_type           = "gp2"
      delete_on_termination = true
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.node_instance_profile.name
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name                                 = "masters-${var.cluster_name}"
      Terraform                            = "true"
      "k8s.io/cluster/${var.cluster_name}" = "owned"
    }
  }
  
  depends_on = [
    aws_launch_template.masters-k8s
  ]

}

resource "aws_autoscaling_group" "master-k8s-local-01" {
  name                      = "${var.cluster_name}-self-managed-node-asg"
  vpc_zone_identifier       = var.subnet_id_public
  min_size                  = 3
  max_size                  = 5
  desired_capacity          = 4
  health_check_grace_period = 300
  health_check_type         = "EC2"
  
  tag {
    key                 = "Name"
    value               = "terraform-${var.cluster_name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = true
  }

  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id   = aws_launch_template.masters-k8s.id
        version              = "$Latest"
      }
      override {
        instance_type = "${var.instance_type}"
      }
    }
    instances_distribution {
      on_demand_allocation_strategy            = "prioritized"
      on_demand_base_capacity                  = 1
      on_demand_percentage_above_base_capacity = 25
      spot_allocation_strategy                 = "lowest-price"
      spot_instance_pools                      = 2
      spot_max_price                           = "0.05"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_groups-worker,
    aws_iam_role_policy_attachment.node_groups-cni,
    aws_iam_role_policy_attachment.node_groups-ecr,
  ]
}

data "aws_eks_cluster_auth" "cluster" {
  name = "${var.cluster_name}"
}

locals { # ConfigMap it’s required kubernetes configuration to join worker nodes via AWS IAM role authentication
  config_map_aws_auth = <<CONFIGMAPAWSAUTH

apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${aws_iam_role.node_groups.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
CONFIGMAPAWSAUTH
}
