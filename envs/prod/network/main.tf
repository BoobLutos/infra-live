terraform {
  required_version = ">= 1.10"

  # Used for CLI-driven speculative plans from a laptop. VCS-driven runs in
  # HCP Terraform use the workspace this directory is connected to.
  cloud {
    organization = "moln"

    workspaces {
      name = "network-prod"
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

module "network" {
  source  = "app.terraform.io/moln/network/linode"
  version = "1.0.0" # exact pin: promote new versions dev -> prod via PR

  name        = "pilot"
  environment = "prod"
  region      = "se-sto"

  subnets = {
    app = "10.1.1.0/24"
  }
}
