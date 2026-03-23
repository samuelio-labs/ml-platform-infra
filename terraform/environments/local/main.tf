module "namespaces" {
  source = "../../modules/namespaces"

  namespaces = {
    argocd     = { req_cpu = "500m", req_mem = "2Gi", lim_cpu = "4", lim_mem = "6Gi", default_lim_cpu = "500m", default_lim_mem = "512Mi", default_req_cpu = "100m", default_req_mem = "128Mi" }
    mlflow     = { req_cpu = "500m", req_mem = "1Gi", lim_cpu = "2", lim_mem = "4Gi", default_lim_cpu = "500m", default_lim_mem = "512Mi", default_req_cpu = "100m", default_req_mem = "128Mi" }
    ray-system = { req_cpu = "1", req_mem = "2Gi", lim_cpu = "4", lim_mem = "8Gi", default_lim_cpu = "500m", default_lim_mem = "512Mi", default_req_cpu = "100m", default_req_mem = "128Mi" }
    kubeflow   = { req_cpu = "500m", req_mem = "1Gi", lim_cpu = "2", lim_mem = "4Gi", default_lim_cpu = "500m", default_lim_mem = "512Mi", default_req_cpu = "100m", default_req_mem = "128Mi" }
    kserve     = { req_cpu = "500m", req_mem = "1Gi", lim_cpu = "2", lim_mem = "4Gi", default_lim_cpu = "500m", default_lim_mem = "512Mi", default_req_cpu = "100m", default_req_mem = "128Mi" }
    monitoring = { req_cpu = "500m", req_mem = "1Gi", lim_cpu = "2", lim_mem = "4Gi", default_lim_cpu = "500m", default_lim_mem = "512Mi", default_req_cpu = "100m", default_req_mem = "128Mi" }
  }
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
  kubectl_context     = "k3d-ml-platform"
  server_insecure     = true

  depends_on = [module.namespaces]
}
