include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/infra/modules/eks"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id             = "vpc-00000000000000000"
    private_subnet_ids = ["subnet-00000000000000001", "subnet-00000000000000002"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  cluster_name       = "mlops-dev"
  cluster_version    = "1.31"
  vpc_id             = dependency.vpc.outputs.vpc_id
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids

  # Private endpoint only. To reach the API from a laptop, add your /32 here temporarily.
  public_access_cidrs = []

  # Who can administer the cluster. Replace with your SSO admin role and CI deploy role.
  admin_role_arns = [
    "arn:aws:iam::111111111111:role/PlatformAdmin",
  ]

  gpu_capacity_type = "SPOT"
  gpu_max_nodes     = 1
}
