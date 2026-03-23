output "namespaces_created" {
  description = "Platform namespaces provisioned by Terraform"
  value       = module.namespaces.namespace_names
}

output "argocd_admin_password_cmd" {
  description = "Retrieve the initial ArgoCD admin password"
  value       = "kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d"
}

output "argocd_ui_cmd" {
  description = "Port-forward the ArgoCD UI"
  value       = "kubectl port-forward svc/argocd-server -n argocd 9090:80"
}
