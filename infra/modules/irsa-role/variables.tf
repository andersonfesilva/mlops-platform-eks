variable "role_name" {
  description = "IAM role name."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster IAM OIDC provider."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace of the service account."
  type        = string
}

variable "service_account" {
  description = "Kubernetes service account allowed to assume the role."
  type        = string
}

variable "corpus_bucket" {
  description = "S3 bucket holding the RAG corpus."
  type        = string
}

variable "corpus_prefix" {
  description = "Prefix inside the bucket the service may read (no leading or trailing slash)."
  type        = string

  validation {
    condition     = length(var.corpus_prefix) > 0 && !startswith(var.corpus_prefix, "/") && !endswith(var.corpus_prefix, "/")
    error_message = "corpus_prefix must be non-empty, without leading or trailing slash."
  }
}

variable "permissions_boundary_arn" {
  description = "Optional permissions boundary attached to the role."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
