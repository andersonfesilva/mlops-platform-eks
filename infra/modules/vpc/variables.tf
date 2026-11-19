variable "name" {
  description = "Name prefix for the VPC and its resources."
  type        = string
}

variable "cidr" {
  description = "VPC CIDR block. Must be a /16 so the subnet math in main.tf fits."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.cidr)) && endswith(var.cidr, "/16")
    error_message = "cidr must be a valid /16 block."
  }
}

variable "azs" {
  description = "Availability zones to span, listed explicitly so the layout never changes when AWS adds a zone."
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2 && length(var.azs) <= 3
    error_message = "azs must list 2 or 3 availability zones."
  }
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway (cheaper, not HA). Set false for production."
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "Retention for VPC flow logs in CloudWatch."
  type        = number
  default     = 90
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
