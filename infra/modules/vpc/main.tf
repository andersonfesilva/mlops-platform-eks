terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40"
    }
  }
}

locals {
  azs = var.azs
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = var.name
  cidr = var.cidr
  azs  = local.azs

  # /20 private subnets for worker nodes and pods, /24 public subnets for load balancers only.
  private_subnets = [for i, _ in local.azs : cidrsubnet(var.cidr, 4, i)]
  public_subnets  = [for i, _ in local.azs : cidrsubnet(var.cidr, 8, 48 + i)]

  enable_nat_gateway     = true
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = !var.single_nat_gateway

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Security baseline: no implicit public IPs, locked-down default SG, flow logs on.
  map_public_ip_on_launch        = false
  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  enable_flow_log                                 = true
  create_flow_log_cloudwatch_log_group            = true
  create_flow_log_cloudwatch_iam_role             = true
  flow_log_cloudwatch_log_group_retention_in_days = var.flow_log_retention_days
  flow_log_max_aggregation_interval               = 60

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = var.tags
}
