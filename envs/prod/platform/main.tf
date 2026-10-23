terraform {
  required_version = ">= 1.10"

  cloud {
    organization = "zimba"

    workspaces {
      name = "platform-prod"
    }
  }

  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 4.7"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

provider "linode" {}

locals {
  environment = "prod"

  # Must match the cluster created by the kubernetes-prod workspace (<name>-<environment>).
  cluster_label = "pilot-${local.environment}"

  kube_config = yamldecode(base64decode(data.linode_lke_cluster.this.kubeconfig))
  kube_host   = local.kube_config.clusters[0].cluster.server
  kube_ca     = base64decode(local.kube_config.clusters[0].cluster["certificate-authority-data"])
  kube_token  = local.kube_config.users[0].user.token
}

# Look the cluster up through the Linode API instead of reading another
# workspace's state, the same way the app workspace finds its VPC.
data "linode_lke_clusters" "this" {
  filter {
    name   = "label"
    values = [local.cluster_label]
  }

  lifecycle {
    postcondition {
      condition     = length(self.lke_clusters) == 1
      error_message = "Expected exactly one LKE cluster labelled ${local.cluster_label}. Apply the kubernetes-${local.environment} workspace first."
    }
  }
}

data "linode_lke_cluster" "this" {
  id = one(data.linode_lke_clusters.this.lke_clusters).id
}

provider "kubernetes" {
  host                   = local.kube_host
  cluster_ca_certificate = local.kube_ca
  token                  = local.kube_token
}

provider "helm" {
  kubernetes = {
    host                   = local.kube_host
    cluster_ca_certificate = local.kube_ca
    token                  = local.kube_token
  }
}

provider "kubectl" {
  host                   = local.kube_host
  cluster_ca_certificate = local.kube_ca
  token                  = local.kube_token
  load_config_file       = false
}

module "platform" {
  source  = "app.terraform.io/zimba/kubernetes/linode//modules/platform"
  version = "1.0.0" # exact pin: promote new versions dev -> prod via PR

  acme_email  = var.acme_email
  argocd_host = "argocd.sinza.org"
  n8n_host    = "n8n.sinza.org"

  smtp_user     = var.smtp_user
  smtp_password = var.smtp_password
  smtp_sender   = var.smtp_sender

  n8n_encryption_key = var.n8n_encryption_key

  # Argo CD Applications to create, e.g.:
  # argocd_applications = {
  #   my-app = {
  #     repo_url              = "https://github.com/<owner>/<repo>.git"
  #     path                  = "manifests"
  #     destination_namespace = "my-app"
  #   }
  # }
}
