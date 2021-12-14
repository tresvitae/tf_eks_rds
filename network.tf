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
  vpc_id     = aws_vpc.vpc.id
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
  vpc_id     = aws_vpc.vpc.id
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

resource "aws_network_acl" "rds-external-zone" {
  vpc_id     = aws_vpc.vpc.id
  subnet_ids =  [aws_subnet.public["public-rds-1"].id, aws_subnet.public["public-rds-2"].id]

  tags = {
    Name        = "rds-external-zole-${var.environment}" 
    Environment = var.environment
  }
}

resource "aws_network_acl_rule" "rds-ingress-external-zone-rules" {
  for_each = {
    for subnet in local.nacl_ingress_rds_external_zone_infos : "${subnet.priority}" => subnet
  }

  network_acl_id = aws_network_acl.rds-external-zone.id
  rule_number = each.value.priority
  rule_action = "allow"
  egress      = false
  protocol    = "tcp"
  cidr_block  = each.value.cidr_block
  from_port   = each.value.from_port
  to_port     = each.value.to_port
}

resource "aws_network_acl" "rds-secure-zone" {
  vpc_id     = aws_vpc.vpc.id
  subnet_ids = [aws_subnet.private["private-rds-1"].id, aws_subnet.private["private-rds-2"].id]

  tags = {
    Name        = "rds-secure-zone-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_network_acl_rule" "ingress-secure-zone-rules" {
  for_each  = {
    for subnet in local.nacl_secure_ingress_egress_infos : "${subnet.priority}" => subnet
  }

  network_acl_id = aws_network_acl.rds-secure-zone.id
  rule_number    = each.value.priority
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr_block
  from_port      = each.value.from_port
  to_port        = each.value.to_port
}

resource "aws_network_acl_rule" "egress-secure-zone-rules" {
  for_each  = {
    for subnet in local.nacl_secure_ingress_egress_infos : "${subnet.priority}" => subnet
  }
  network_acl_id = aws_network_acl.rds-secure-zone.id
  rule_number    = each.value.priority
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr_block
  from_port      = 0
  to_port        = 65535
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Environment = var.environment
    Name        = "igw-${var.environment}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Environment = var.environment
    Name        = "rt-public-${var.environment}"
  }
}

resource "aws_route_table_association" "public" {
  for_each = {
    for subnet in local.public_nested_config : "${subnet.name}" => subnet
  }

  subnet_id      = aws_subnet.public[each.value.name].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  for_each = {
    for subnet in local.public_nested_config : "${subnet.name}" => subnet
    if subnet.nat_gw == true
  }
  vpc = true

  tags = {
    Environment = var.environment
    Name        = "eip-${each.value.name}-${var.environment}"
  }
}

resource "aws_nat_gateway" "nat-gw" {
  for_each = {
    for subnet in local.public_nested_config : "${subnet.name}" => subnet
    if subnet.nat_gw == true
  }
  allocation_id = aws_eip.nat[each.value.name].id
  subnet_id     = aws_subnet.public[each.value.name].id

  tags = {
    Environment = var.environment
    Name        = "nat-${each.value.name}-${var.environment}"
  }
}

resource "aws_route_table" "private" {
  for_each = {
    for subnet in local.public_nested_config : "${subnet.name}" => subnet
    if subnet.nat_gw == true
  }
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gw[each.value.name].id
  }

  tags = {
    Environment = var.environment
    Name        = "rt-${each.value.name}-${var.environment}"
  }
}

resource "aws_route_table_association" "private" {

  for_each = {
    for subnet in local.private_nested_config : "${subnet.name}" => subnet
    if subnet.associated_public_subnet != ""
  }

  subnet_id      = aws_subnet.private[each.value.name].id
  route_table_id = aws_route_table.private[each.value.associated_public_subnet].id
}
