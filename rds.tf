resource "random_string" "db_suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "aws_db_instance" "postgresql" {
  username                            = var.username
  password                            = var.password
  # Settings
  engine                              = "postgres"
  engine_version                      = "13.3"
  name                                = "postgresql${var.environment}"
  identifier                          = "postgresql-${var.environment}"
  instance_class                      = "db.t3.micro"
  # Storage
  storage_type                        = "gp2"
  allocated_storage                   = 100
  max_allocated_storage               = 200
  # Connectivity
  db_subnet_group_name                = aws_db_subnet_group.sg.id

  publicly_accessible                 = false
  vpc_security_group_ids              = [aws_security_group.sg.id]
  port                                = var.db_port
  # Availability
  multi_az                            = true
  # Encryption
  storage_encrypted                   = true
  # Deletion protection
  deletion_protection                 = false
  # Database authentication
  iam_database_authentication_enabled = true
  parameter_group_name                = "default.postgres12"
  # Backup
  backup_retention_period             = 14
  backup_window                       = "03:00-04:00"
  final_snapshot_identifier           = "postgresql-final-snapshot-${random_string.db_suffix.result}" 
  delete_automated_backups            = true
  skip_final_snapshot                 = false
  # Maintenance
  auto_minor_version_upgrade          = true
  maintenance_window                  = "Sat:00:00-Sat:02:00"

  tags = {
    Environment = var.environment
  }
}

resource "aws_db_subnet_group" "sg" {
  name       = "postgresql-${var.environment}"
  subnet_ids = [aws_subnet.private["private-rds-1"].id, aws_subnet.private["private-rds-2"].id]

  tags = {
    Environment = var.environment
    Name        = "postgresql-${var.environment}"
  }
}

resource "aws_security_group" "sg" {
  name        = "postgresql-${var.environment}"
  description = "Allow inbound/outbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = var.db_port
    to_port     = var.db_port
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private["private-rds-1"].cidr_block]
  }

  ingress {
    from_port   = var.db_port
    to_port     = var.db_port
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private["private-rds-2"].cidr_block]
  }

  ingress {
    from_port   = var.db_port
    to_port     = var.db_port
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.public["public-rds-1"].cidr_block]  
  }

  ingress {
    from_port   = var.db_port
    to_port     = var.db_port
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.public["public-rds-2"].cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private["private-rds-1"].cidr_block]
  }

  
  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private["private-rds-2"].cidr_block]  
  }

  egress {
    from_port   = var.db_port
    to_port     = var.db_port
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.public["public-rds-1"].cidr_block]  
  }

  egress {
    from_port   = var.db_port
    to_port     = var.db_port
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.public["public-rds-2"].cidr_block]  
  }

  tags = {
    Name        = "postgresql-${var.environment}"
    Environment = var.environment
  }
}