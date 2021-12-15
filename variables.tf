variable "region" {
    type = string
}

variable "vpc_cidr_block" {
  type = string
  default = "10.0.0.0/16"
}
variable "environment" {
  type = string
  default = "dev"
}

variable "private_network_config" {
  type = map(object({
    cidr_block               = string
    az                       = string
    associated_public_subnet = string
    eks                      = bool
  }))
  default = {
    "private-eks-1" = {
      cidr_block               = "10.0.0.0/23"
      az                       = "eu-west-1a"
      associated_public_subnet = "public-eks-1"
      eks                      = true
    },
    "private-eks-2" = {
      cidr_block               = "10.0.2.0/23"
      az                       = "eu-west-1b"
      associated_public_subnet = "public-eks-2"
      eks                      = true
    },
    "private-rds-1" = {
      cidr_block               = "10.0.10.0/24"
      az                       = "eu-west-1a"
      associated_public_subnet = ""
      eks                      = false
    },
    "private-rds-2" = {
      cidr_block               = "10.0.11.0/24"
      az                       = "eu-west-1b"
      associated_public_subnet = ""
      eks                      = false
    }
  }
}

locals {
  private_nested_config = flatten([
    for name, config in var.private_network_config : [
      {
        name                     = name
        cidr_block               = config.cidr_block
        az                       = config.az
        associated_public_subnet = config.associated_public_subnet
        eks                      = config.eks
      }
    ]
  ])
}

variable "public_network_config" {
    type = map(object({
        cidr_block = string
        az         = string
        nat_gw     = bool
        eks        = bool
    }))

    default = {
      "public-eks-1" = {
        cidr_block = "10.0.4.0/23"
        az         = "eu-west-1a"
        nat_gw     = true
        eks        = true
      },
      "public-eks-2" = {
        cidr_block = "10.0.6.0/23"
        az         = "eu-west-1b"
        nat_gw     = true
        eks        = true
      },
      "public-rds-1" = {
        cidr_block = "10.0.12.0/24"
        az         = "eu-west-1a"
        nat_gw     = false
        eks        = false
      },
      "public-rds-2" = {
        cidr_block = "10.0.13.0/24"
        az         = "eu-west-1b"
        nat_gw     = false
        eks        = false
      }
    }
}

locals {
    public_nested_config = flatten([
        for name, config in var.public_network_config : [
            {
                name       = name
                cidr_block = config.cidr_block
                az         = config.az
                nat_gw     = config.nat_gw
                eks        = config.eks
            }
        ]
    ])
}

variable "db_port" {
  type = number
}

variable "internal_ip_range" {
  type = string
}

# NACL external zone rules for RDS
locals {
  nacl_ingress_rds_external_zone_infos = flatten([{
      cidr_block = var.internal_ip_range
      priority   = 100
      from_port  = var.db_port
      to_port    = var.db_port
  },{
      cidr_block = aws_subnet.private["private-rds-1"].cidr_block
      priority   = 101
      from_port  = 0
      to_port    = 65535
  },{
      cidr_block = aws_subnet.private["private-rds-2"].cidr_block
      priority   = 102
      from_port  = 0
      to_port    = 65535
  },{
      cidr_block = aws_subnet.public["public-rds-1"].cidr_block
      priority   = 103
      from_port  = 0
      to_port    = 65535
  },{
      cidr_block = aws_subnet.public["public-rds-2"].cidr_block
      priority   = 104
      from_port  = 0 
      to_port    = 65535
  }])
}

# NACL secure zone rules for RDS
locals {
  nacl_secure_ingress_egress_infos = flatten([{
      cidr_block = aws_subnet.private["private-eks-1"].cidr_block
      priority   = 101
      from_port  = var.db_port
      to_port    = var.db_port
  },{
      cidr_block = aws_subnet.private["private-eks-2"].cidr_block
      priority   = 102
      from_port  = var.db_port
      to_port    = var.db_port
  },{
      cidr_block = aws_subnet.private["private-rds-1"].cidr_block
      priority   = 103
      from_port  = 0
      to_port    = 65535
  },{
      cidr_block = aws_subnet.private["private-rds-2"].cidr_block
      priority   = 104
      from_port  = 0
      to_port    = 65535
  },{
      cidr_block = aws_subnet.public["public-rds-1"].cidr_block
      priority   = 105
      from_port  = 0
      to_port    = 65535
  },{
      cidr_block = aws_subnet.public["public-rds-2"].cidr_block
      priority   = 106
      from_port  = 0
      to_port    = 65535
  }]) 
}

variable "eks_cluster_name" {
  type = string
}

variable "username" {
  type = string
}

variable "password" {
  type = string
}

locals {
    subnet_id = aws_subnet.public["public-rds-1"].availability_zone == aws_db_instance.postgresql.availability_zone ? aws_subnet.public["public-rds-1"].id : aws_subnet.public["public-rds-2"].id
}