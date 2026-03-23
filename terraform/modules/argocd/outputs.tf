output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = helm_release.argocd.namespace
}

output "argocd_chart_version" {
  description = "Installed ArgoCD Helm chart version"
  value       = helm_release.argocd.version
}

output "app_of_apps_path" {
  description = "Path to the rendered App-of-Apps manifest"
  value       = local_file.app_of_apps.filename
}
