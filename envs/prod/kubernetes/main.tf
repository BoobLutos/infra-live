terraform {
  required_version = ">= 1.10"

  # Used for CLI-driven speculative plans from a laptop. VCS-driven runs in
  # HCP Terraform use the workspace this directory is connected to.
  cloud {
    organization = "zimba"

    workspaces {
      name = "kubernetes-prod"
    }
  }

  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 4.7"
    }
  }
}

# Authenticates with the LINODE_TOKEN environment variable, which HCP Terraform
# injects from the "linode-prod" variable set. No credentials live in code.
provider "linode" {}

module "kubernetes" {
  source  = "app.terraform.io/zimba/kubernetes/linode"
  version = "1.0.0" # exact pin: promote new versions dev -> prod via PR

  name        = "pilot"
  environment = "prod"
  region      = "se-sto"
  k8s_version = "1.35"

  node_pools = [
    { type = "g6-standard-1", count = 2 },
  ]

  extra_tags = ["owner:platform-team"]
}
