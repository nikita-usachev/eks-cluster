# VPC

resource "aws_vpc" "vpc" {
  cidr_block                       = var.cidr_vpc
  instance_tenancy                 = "default" # makes your instances shared on the host
  enable_dns_support               = true # required for eks. enable/disable DNS support in the VPC
  enable_dns_hostnames             = true # required for eks. enable/disable DNS hostnames in the VPC

  tags = {
    Name                                        = "${var.cluster_name}-vpc"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Internet gateway

resource "aws_internet_gateway" "vpc_igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "main-vpc_igw"
  }
}

# Route table with public subnets

resource "aws_route_table" "rt-pub-subnets" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "rt-pub-subnets"
  }

  depends_on = [aws_vpc.vpc]

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpc_igw.id
  }
}

# Associating the "public" route table with the VPC's "main" route table association

resource "aws_main_route_table_association" "main-route-table" {
  vpc_id = aws_vpc.vpc.id
  route_table_id = aws_route_table.rt-pub-subnets.id
}

# Route table with private subnets

resource "aws_route_table" "rt-pri-subnets" {
  count  = 3
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "rt-pri-subnets-${count.index+1}"
  }

  depends_on = [aws_vpc.vpc]

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gw.id
  }
}

# Availability zones

locals {
  availability_zones = [
    "a",
    "b",
    "c",
  ]
}

# 3 public subnets

resource "aws_subnet" "public_subnets" {
  count                   = 3
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "192.168.${count.index}.0/24"
  availability_zone       = "us-east-1${element(local.availability_zones, count.index % length(local.availability_zones))}"
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "public-subnet-${count.index + 1}-${var.cluster_name}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }
}

# Association public subnets with our own created route table

resource "aws_route_table_association" "public_subnets_association" {
  count          = 3
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.rt-pub-subnets.id
}

# 3 private subnets

resource "aws_subnet" "private_subnets" {
  count                   = 3
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "192.168.${16 + count.index}.0/24"
  availability_zone       = "us-east-1${element(local.availability_zones, count.index % length(local.availability_zones))}"
  map_public_ip_on_launch = false

  tags = {
    Name                                        = "private-subnet-${count.index + 1}-${var.cluster_name}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }
}

# 4. NAT gateway's and elastic IP's

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnets[0].id
  
  tags = {
    Name = "nat-gw-main-vpc"
  }
}

resource "aws_eip" "nat_eip" { # Creating Elastic IPs
  vpc        = true
  depends_on = [aws_internet_gateway.vpc_igw]
}

# Association private subnets with our own created route table

resource "aws_route_table_association" "private_subnets_association" {
  count          = 3
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.rt-pri-subnets[count.index].id
}

# Security group for the master nodes

resource "aws_security_group" "k8s-master-nodes" {
  name        = "k8s_masters_${var.cluster_name}"
  description = "Master nodes security group"
  vpc_id      = aws_vpc.vpc.id
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name                                        = "${var.cluster_name}_master_nodes"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  } 
}

# Allowing inbound traffic from local workstation external IP to the Kubernetes.

resource "aws_security_group_rule" "demo-cluster-ingress-workstation-https" {
  cidr_blocks       = ["207.181.250.43/32"]
  description       = "Allow inbound traffic from local workstation external IP to the Kubernetes."
  from_port         = 443
  protocol          = "tcp"
  security_group_id = "${aws_security_group.k8s-master-nodes.id}"
  to_port           = 443
  type              = "ingress"
}

# Security group for the worker nodes

resource "aws_security_group" "k8s-worker-nodes" {
  name        = "api-elb.${var.cluster_name}.k8s.local"
  description = "Worker nodes security group"
  vpc_id      = aws_vpc.vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name                                        = "${var.cluster_name}_worker_nodes"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

##############################################################################################################

resource "aws_security_group_rule" "demo-node-ingress-self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = "${aws_security_group.k8s-worker-nodes.id}"
  source_security_group_id = "${aws_security_group.k8s-worker-nodes.id}"
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "demo-node-ingress-cluster-https" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.k8s-worker-nodes.id}"
  source_security_group_id = "${aws_security_group.k8s-master-nodes.id}"
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_security_group_rule" "demo-node-ingress-cluster-others" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.k8s-worker-nodes.id}"
  source_security_group_id = "${aws_security_group.k8s-master-nodes.id}"
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "demo-cluster-ingress-node-https" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.k8s-master-nodes.id}"
  source_security_group_id = "${aws_security_group.k8s-worker-nodes.id}"
  to_port                  = 443
  type                     = "ingress"
}

#############################################################################################################

# Security group for the API Load Balancer (in case if we have more than 1 master node)

# resource "aws_security_group" "api-elb-k8s-local" {
#   name        = "k8s_workers_${var.cluster_name}"
#   description = "Security group for api ELB"
#   vpc_id      = aws_vpc.vpc.id

#   ingress {
#     from_port   = 6443
#     to_port     = 6443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     from_port   = 3
#     to_port     = 4
#     protocol    = "icmp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     KubernetesCluster = "${var.cluster_name}.k8s.local"
#     Name              = "api-elb.${var.cluster_name}.k8s.local"
#   }
# }

# resource "aws_security_group_rule" "traffic_from_lb" {
#   type                     = "ingress"
#   description              = "Allow API traffic from the load balancer"
#   from_port                = 6443
#   to_port                  = 6443
#   protocol                 = "TCP"
#   source_security_group_id = aws_security_group.api-elb-k8s-local.id
#   security_group_id        = aws_security_group.k8s-master-nodes.id
# }
