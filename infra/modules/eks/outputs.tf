output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 CA bundle for the cluster."
  value       = module.eks.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN, used by IRSA roles."
  value       = module.eks.oidc_provider_arn
}

output "kms_key_arn" {
  description = "KMS key used for Secrets envelope encryption."
  value       = aws_kms_key.eks_secrets.arn
}

output "account_id" {
  description = "AWS account ID the cluster lives in."
  value       = data.aws_caller_identity.current.account_id
}
