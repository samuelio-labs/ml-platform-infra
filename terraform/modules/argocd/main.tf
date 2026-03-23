terraform {
  required_version = ">= 1.9"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.14"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.5"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2"
    }
  }
}

locals {
  app_of_apps_manifest = templatefile("${path.module}/templates/app-of-apps.yaml.tpl", {
    git_repo_url        = var.git_repo_url
    git_target_revision = var.git_target_revision
  })
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.chart_version
  namespace        = "argocd"
  create_namespace = false # namespace created by the namespaces module
  wait             = true

  values = [
    yamlencode({
      configs = {
        params = {
          # Disable TLS at the ArgoCD server level for local k3d.
          # TLS termination is handled by the ingress or port-forward.
          "server.insecure" = var.server_insecure
        }
        cm = {
          "application.resourceTrackingMethod" = "annotation"
        }
      }
      server = {
        service = { type = "ClusterIP" }
      }
      # Disable DEX (SSO) for local development — use admin password only.
      dex = { enabled = false }
      repoServer = {
        # Generous probe thresholds for local k3d — the repo-server can be
        # slow to accept connections on first boot while initialising caches.
        livenessProbe = {
          timeoutSeconds   = 10
          failureThreshold = 6
          periodSeconds    = 15
        }
        readinessProbe = {
          timeoutSeconds   = 10
          failureThreshold = 6
        }
      }
    })
  ]
}

# Render the App-of-Apps manifest and write it to the argocd/ directory
# so it is committed alongside the rest of the repo for reference.
resource "local_file" "app_of_apps" {
  content  = local.app_of_apps_manifest
  filename = "${path.module}/../../../argocd/app-of-apps.yaml"
}

# Apply the App-of-Apps after ArgoCD is fully ready.
# From this point ArgoCD takes over and reconciles everything under argocd/apps/.
resource "null_resource" "apply_app_of_apps" {
  triggers = {
    manifest_sha = sha256(local.app_of_apps_manifest)
  }

  provisioner "local-exec" {
    command = "kubectl apply -f ${local_file.app_of_apps.filename} --context ${var.kubectl_context}"
  }

  depends_on = [helm_release.argocd, local_file.app_of_apps]
}
