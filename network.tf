resource "aws_vpc" "my_vpc" {
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

  vpc_id                  = aws_vpc.my_vpc.id
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

  vpc_id                  = aws_vpc.my_vpc.id
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
