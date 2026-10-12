terraform {
  required_version = ">= 1.10"

  cloud {
    organization = "moln"

    workspaces {
      name = "app-prod"
    }
  }

  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 4.7"
    }
  }
}

provider "linode" {}

locals {
  environment = "prod"
  region      = "se-sto"

  # Must match the VPC created by the network-prod workspace (<name>-<environment>).
  vpc_label   = "pilot-${local.environment}"
  subnet_name = "app"
}

# Look the network up through the Linode API instead of reading another
# workspace's state. This keeps the workspaces decoupled: the app workspace
# only needs to know the VPC's label, not have access to network state.
data "linode_vpcs" "this" {
  filter {
    name   = "label"
    values = [local.vpc_label]
  }

  lifecycle {
    postcondition {
      condition     = length(self.vpcs) == 1
      error_message = "Expected exactly one VPC labelled ${local.vpc_label}. Apply the network-${local.environment} workspace first."
    }
  }
}

data "linode_vpc_subnets" "app" {
  vpc_id = one(data.linode_vpcs.this.vpcs).id

  filter {
    name   = "label"
    values = [local.subnet_name]
  }

  lifecycle {
    postcondition {
      condition     = length(self.vpc_subnets) == 1
      error_message = "Expected exactly one subnet labelled ${local.subnet_name} in ${local.vpc_label}."
    }
  }
}

module "web" {
  source  = "app.terraform.io/moln/webserver/linode"
  version = "1.0.0" # exact pin: promote new versions dev -> prod via PR

  name          = "pilot"
  environment   = local.environment
  region        = local.region
  subnet_id     = one(data.linode_vpc_subnets.app.vpc_subnets).id
  instance_type = "g6-nanode-1"

  authorized_keys = var.ssh_public_keys
  admin_ssh_cidrs = var.admin_ssh_cidrs
  extra_tags      = ["owner:platform-team"]

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    environment = local.environment
  })
}
