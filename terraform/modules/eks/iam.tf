# Policies in data blocks

data "aws_iam_policy_document" "cluster_policy" {
  version = "2012-10-17"
  
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ng_policy" {
  version = "2012-10-17"
  
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# IAM for EKS cluster

resource "aws_iam_role" "eks_cluster" {
  name               = "${var.cluster_name}-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_policy.json
}

resource "aws_iam_role_policy_attachment" "amazon_eks_cluster_eks-policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.eks_cluster.name}"
}

resource "aws_iam_role_policy_attachment" "amazon-eks-resource-controller-policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = "${aws_iam_role.eks_cluster.name}"
}

resource "aws_iam_role_policy_attachment" "demo-cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.eks_cluster.name}"
}

resource "aws_iam_role_policy_attachment" "AllowExternalDNSUpdatesPolicy" { # Dan's policy
  policy_arn = "arn:aws:iam::340924313311:policy/AllowExternalDNSUpdatesPolicy-22c"
  role       = "${aws_iam_role.eks_cluster.name}"
}

# IAM for EKS node groups

resource "aws_iam_role" "node_groups" {
  name = "node-instance-role"
  assume_role_policy = data.aws_iam_policy_document.ng_policy.json
}

resource "aws_iam_role_policy_attachment" "node_groups-worker" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "${aws_iam_role.node_groups.name}"
}

resource "aws_iam_role_policy_attachment" "node_groups-cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = "${aws_iam_role.node_groups.name}"
}

resource "aws_iam_role_policy_attachment" "node_groups-ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = "${aws_iam_role.node_groups.name}"
}

resource "aws_iam_role_policy_attachment" "node_groups-ecr-ec2" {
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds"
  role       = "${aws_iam_role.node_groups.name}"
}
