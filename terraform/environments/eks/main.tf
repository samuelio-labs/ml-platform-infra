# gp3 StorageClass using the EKS-managed EBS CSI driver.
# The default gp2 class uses kubernetes.io/aws-ebs (in-tree), which CSI migration
# maps to ebs.csi.aws.com — not matching ebs.csi.eks.amazonaws.com installed here.
resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner    = "ebs.csi.eks.amazonaws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true
  parameters = {
    type      = "gp3"
    fsType    = "ext4"
    encrypted = "true"
  }
}

module "namespaces" {
  source = "../../modules/namespaces"

  namespaces = {
    argocd     = { req_cpu = "500m", req_mem = "2Gi", lim_cpu = "4", lim_mem = "6Gi", default_lim_cpu = "500m", default_lim_mem = "512Mi", default_req_cpu = "100m", default_req_mem = "128Mi" }
    mlflow     = { req_cpu = "1", req_mem = "2Gi", lim_cpu = "4", lim_mem = "8Gi", default_lim_cpu = "500m", default_lim_mem = "1Gi", default_req_cpu = "100m", default_req_mem = "256Mi" }
    ray-system = { req_cpu = "2", req_mem = "4Gi", lim_cpu = "8", lim_mem = "16Gi", default_lim_cpu = "500m", default_lim_mem = "1Gi", default_req_cpu = "100m", default_req_mem = "256Mi" }
    kubeflow   = { req_cpu = "1", req_mem = "2Gi", lim_cpu = "4", lim_mem = "8Gi", default_lim_cpu = "500m", default_lim_mem = "1Gi", default_req_cpu = "100m", default_req_mem = "256Mi" }
    kserve     = { req_cpu = "1", req_mem = "2Gi", lim_cpu = "4", lim_mem = "8Gi", default_lim_cpu = "500m", default_lim_mem = "1Gi", default_req_cpu = "100m", default_req_mem = "256Mi" }
    monitoring = { req_cpu = "1", req_mem = "2Gi", lim_cpu = "4", lim_mem = "8Gi", default_lim_cpu = "500m", default_lim_mem = "1Gi", default_req_cpu = "100m", default_req_mem = "256Mi" }
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
  kubectl_context     = var.kubectl_context
  server_insecure     = false

  depends_on = [module.namespaces]
}
