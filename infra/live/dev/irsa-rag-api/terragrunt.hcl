include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/infra/modules/irsa-role"
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    oidc_provider_arn = "arn:aws:iam::111111111111:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  role_name         = "mlops-dev-rag-api"
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
  namespace         = "rag"
  service_account   = "rag-api"
  corpus_bucket     = "mlops-dev-rag-corpus"
  corpus_prefix     = "docs"
}
