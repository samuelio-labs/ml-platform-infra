output "secret_names" {
  description = "Names of Kubernetes Secrets created by this module"
  value = {
    minio_mlflow = kubernetes_secret.minio_credentials.metadata[0].name
    minio_kserve = kubernetes_secret.minio_credentials_kserve.metadata[0].name
    postgres     = kubernetes_secret.postgres_credentials.metadata[0].name
    mlflow_key   = kubernetes_secret.mlflow_secret_key.metadata[0].name
  }
}
