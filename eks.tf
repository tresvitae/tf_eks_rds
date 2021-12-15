resource "aws_eks_cluster" "eks" {
    name     = "${var.eks_cluster_name}-${var.environment}"
    role_arn = aws_iam_role.eks.arn

    vpc_config {
      security_group_ids      = [aws_security_group.eks_cluster.id]
      endpoint_private_access = true
      endpoint_public_access  = true
      public_access_cidrs     = [var.internal_ip_range]
      subnet_ids              = [aws_subnet.private["private-eks-1"].id, aws_subnet.private["private-eks-2"].id, aws_subnet.public["public-eks-1"].id, aws_subnet.public["public-eks-2"].id]
    }

    enabled_cluster_log_types = ["api", "audit", "authentication", "controlManager", "scheduler"]

    depends_on = [
        aws_iam_role_policy_attachment.eks-AmazonEKSClusterPolicy,
        aws_iam_role_policy_attachment.eks-AmazonEKSVPCResourceController,
        aws_iam_role_policy_attachment.eks-AmazonEKSServicePolicy
    ]

    tags = {
        Environment = var.environment
    }
}

