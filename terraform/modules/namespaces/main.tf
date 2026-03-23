terraform {
  required_version = ">= 1.9"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.30"
    }
  }
}

locals {
  # Resource quotas sized for local k3d development (single-node or 2-agent cluster).
  # In production (EKS) these are overridden per-environment.
  namespaces = {
    argocd = {
      req_cpu = "2"
      req_mem = "4Gi"
      lim_cpu = "4"
      lim_mem = "8Gi"
    }
    mlflow = {
      req_cpu = "2"
      req_mem = "4Gi"
      lim_cpu = "4"
      lim_mem = "8Gi"
    }
    ray-system = {
      req_cpu = "4"
      req_mem = "8Gi"
      lim_cpu = "8"
      lim_mem = "16Gi"
    }
    kubeflow = {
      req_cpu = "2"
      req_mem = "4Gi"
      lim_cpu = "4"
      lim_mem = "8Gi"
    }
    kserve = {
      req_cpu = "2"
      req_mem = "4Gi"
      lim_cpu = "4"
      lim_mem = "8Gi"
    }
    monitoring = {
      req_cpu = "2"
      req_mem = "4Gi"
      lim_cpu = "4"
      lim_mem = "8Gi"
    }
  }
}

resource "kubernetes_namespace" "this" {
  for_each = local.namespaces

  metadata {
    name = each.key
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "ml-platform/namespace"        = each.key
    }
  }
}

resource "kubernetes_resource_quota" "this" {
  for_each = local.namespaces

  metadata {
    name      = "default-quota"
    namespace = kubernetes_namespace.this[each.key].metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = each.value.req_cpu
      "requests.memory" = each.value.req_mem
      "limits.cpu"      = each.value.lim_cpu
      "limits.memory"   = each.value.lim_mem
    }
  }
}
