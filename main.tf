terraform {
  required_providers {    
      aws = {      
          source  = "hashicorp/aws"
          version = "~> 3.0"
        }
        random = {
            version = ">= 2.1.2"
        }
  }
}

data "aws_caller_identity" "current" {}

data "archive_file" "lambda_zip" {
    type          = "zip"
    source_file   = "${path.module}/populate-nlb-tg-with-rds-private-ip.py"
    output_path   = "lambda_function_payload.zip"
}

# Enabling IAM roles for Service Account
data "tls_certificate" "cert" {
  url = aws_eks_cluster.eks.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "openid" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cert.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks.identity[0].oidc[0].issuer
}

data "aws_iam_policy_document" "web_identity_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.openid.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:metabase:metabase"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.openid.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.openid.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "web_identity_role" {
  assume_role_policy = data.aws_iam_policy_document.web_identity_assume_role_policy.json
  name               = "web-identity-role-${var.environment}"
}

resource "aws_iam_role_policy" "rds_access_from_k8s_pods" {
  name = "rds-access-from-k8s-pods-${var.environment}"
  role = aws_iam_role.web_identity_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "rds-db:connect",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:rds-db:${var.region}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_db_instance.postgresql.resource_id}/metabase"
      }
    ]
  })
}

resource "aws_security_group" "rds_access" {
    name        = "rds-access-from-pod-${var.environment}"
    description = "Allow RDS Access from Kubernetes Pods"
    vpc_id      = aws_vpc.vpc.id

    ingress {
        from_port = 0
        to_port   = 0
        protocol  = "-1"
        self      = true
    }

    ingress {
        from_port       = 53
        to_port         = 53
        protocol        = "tcp"
        security_groups = [aws_eks_cluster.eks.vpc_config[0].cluster_security_group_id]
    }

    ingress {
        from_port       = 53
        to_port         = 53
        protocol        = "udp"
        security_groups = [aws_eks_cluster.eks.vpc_config[0].cluster_security_group_id]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name        = "rds-access-from-pod-${var.environment}"
        Environment = var.environment
    }
}
