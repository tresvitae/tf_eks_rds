output "eks-endpoint" {
    value = aws_eks_cluster.eks.endpoint
}

output "kubeconfig-certificate-authority-data" {
    value = aws_eks_cluster.eks.certificate_authority[0].data
}

output "private-rds-endpoint" {
    value = aws_db_instance.postgresql.address
}

output "rds-username" {
    value = var.username
}

output "rds-password" {
    value = var.password
}

output "public-rds-endpoint" {
    value = "${element(split("/", aws_lb.nlb.arn), 2)}-${element(split("/", aws_lb.nlb.arn), 3)}.elb.${var.region}.amazonaws.com"
}

output "sg-eks-cluster" {
    value = aws_eks_cluster.eks.vpc_config[0].cluster_security_group_id
}

output "sg-rds-access" {
    value = aws_security_group.rds_access.id
}
