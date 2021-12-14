resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    "Name" = "vpc-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_subnet" "private" {
  for_each = {
    for subnet in local.private_nested_config : "${subnet.name}" => subnet
  }

  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Environment = var.environment
    Name        = "${each.value.name}-${var.environment}"
    "kubernetes.io/role/internal-elb" = each.value.eks ? "1" : ""
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_subnet" "public" {
  for_each = {
    for subnet in local.public_nested_config : "${subnet.name}" => subnet
  }

  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = {
    Environment = var.environment
    Name        = "${each.value.name}-${var.environment}"
    "kubernetes.io/role.elb" = each.value.eks ? "1" : ""
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_network_acl" "eks-external-zone" {
  vpc_id = aws_vpc.vpc.id
  subnet_ids = [aws_subnet.public["public-eks-1"].id, aws_subnet.public["public-eks-2"].id]

  tags = {
    Name        = "eks-external-zone-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_network_acl_rule" "eks-ingress-external-zone-rules" {
  network_acl_id = aws_network_acl.eks-external-zone.id
  rule_number    = 100
  rule_action    = "allow"
  egress         = false
  protocol       = "-1"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}

resource "aws_network_acl_rule" "eks-egress-external-zone-rules" {
  network_acl_id = aws_network_acl.eks-external-zone.id
  rule_number    = 100
  rule_action    = "allow"
  egress         = true
  protocol       = "-1"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}

resource "aws_network_acl" "eks-internal-zone" {
  vpc_id = aws_vpc.vpc.id
  subnet_ids = [aws_subnet.private["private-eks-1"].id, aws_subnet.private["private-eks-2"].id]

  tags = {
    Name        = "eks-internal-zone-${var.environment}"
    Environment = var.environment
  }  
}

resource "aws_network_acl_rule" "eks-ingress-internal-zone-rules" {
  network_acl_id = aws_network_acl.eks-internal-zone.id
  rule_number    = 100
  rule_action    = "allow"
  egress         = false
  protocol       = "-1"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}

resource "aws_network_acl_rule" "eks-egress-internal-zole-rules" {
  network_acl_id = aws_network_acl.eks-internal-zone.id
  rule_action    = "allow"
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}
