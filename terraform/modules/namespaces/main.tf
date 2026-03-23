terraform {
  required_version = ">= 1.9"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.30"
    }
  }
}

resource "kubernetes_namespace" "this" {
  for_each = var.namespaces

  metadata {
    name = each.key
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "ml-platform/namespace"        = each.key
    }
  }
}

resource "kubernetes_limit_range" "this" {
  for_each = var.namespaces

  metadata {
    name      = "default-limits"
    namespace = kubernetes_namespace.this[each.key].metadata[0].name
  }

  spec {
    limit {
      type = "Container"
      default = {
        cpu    = each.value.default_lim_cpu
        memory = each.value.default_lim_mem
      }
      default_request = {
        cpu    = each.value.default_req_cpu
        memory = each.value.default_req_mem
      }
    }
  }
}

resource "kubernetes_resource_quota" "this" {
  for_each = var.namespaces

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
