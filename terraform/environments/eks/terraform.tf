terraform {
  required_version = ">= 1.9"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

  # S3 backend for shared state — enable once the bucket exists.
  #
  # backend "s3" {
  #   bucket         = "ml-platform-tfstate"
  #   key            = "eks/terraform.tfstate"
  #   region         = "eu-north-1"
  #   encrypt        = true
  #   dynamodb_table = "ml-platform-tfstate-lock"
  # }
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = var.kubectl_context
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = var.kubectl_context
  }
}
