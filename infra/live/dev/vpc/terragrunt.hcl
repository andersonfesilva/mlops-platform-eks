include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/infra/modules/vpc"
}

inputs = {
  name               = "mlops-dev"
  cidr               = "10.20.0.0/16"
  azs                = ["us-east-1a", "us-east-1b"]
  single_nat_gateway = true # cost-saving for dev; set false in prod
}
