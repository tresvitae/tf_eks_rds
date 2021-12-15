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