module "namespaces" {
  source = "../../modules/namespaces"
}

module "secrets" {
  source = "../../modules/secrets"

  minio_root_user     = var.minio_root_user
  minio_root_password = var.minio_root_password
  postgres_password   = var.postgres_password
  mlflow_secret_key   = var.mlflow_secret_key

  depends_on = [module.namespaces]
}

module "argocd" {
  source = "../../modules/argocd"

  chart_version       = var.argocd_chart_version
  git_repo_url        = var.git_repo_url
  git_target_revision = var.git_target_revision

  depends_on = [module.namespaces]
}
