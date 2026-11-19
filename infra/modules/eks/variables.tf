variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version."
  type        = string
  default     = "1.31"
}

variable "vpc_id" {
  description = "VPC where the cluster runs."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets for the control plane ENIs and worker nodes."
  type        = list(string)
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint. Empty list = private endpoint only."
  type        = list(string)
  default     = []

  validation {
    condition     = !contains(var.public_access_cidrs, "0.0.0.0/0")
    error_message = "Opening the EKS API to 0.0.0.0/0 is not allowed."
  }
}

variable "admin_role_arns" {
  description = "IAM role ARNs granted cluster-admin through EKS access entries (e.g. an SSO admin role, the CI deploy role). The cluster creator gets no implicit access."
  type        = list(string)

  validation {
    condition     = length(var.admin_role_arns) > 0 && alltrue([for a in var.admin_role_arns : can(regex("^arn:aws:iam::[0-9]{12}:role/", a))])
    error_message = "admin_role_arns must contain at least one IAM role ARN (users are not allowed)."
  }
}

variable "system_instance_types" {
  description = "Instance types for the system node group."
  type        = list(string)
  default     = ["m6i.large"]
}

variable "gpu_instance_types" {
  description = "Instance types for the GPU inference node group."
  type        = list(string)
  default     = ["g5.xlarge"]
}

variable "gpu_capacity_type" {
  description = "ON_DEMAND or SPOT for the GPU node group."
  type        = string
  default     = "SPOT"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.gpu_capacity_type)
    error_message = "gpu_capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "gpu_max_nodes" {
  description = "Upper bound for GPU nodes (cost guardrail)."
  type        = number
  default     = 2
}

variable "log_retention_days" {
  description = "Retention for control plane logs."
  type        = number
  default     = 90
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
