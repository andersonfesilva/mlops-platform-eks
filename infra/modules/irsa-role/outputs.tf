output "role_arn" {
  description = "ARN to annotate on the Kubernetes service account (eks.amazonaws.com/role-arn)."
  value       = aws_iam_role.this.arn
}
