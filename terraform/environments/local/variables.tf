variable "minio_root_user" {
  description = "MinIO root username"
  type        = string
  default     = "minioadmin"
}

variable "minio_root_password" {
  description = "MinIO root password"
  type        = string
  sensitive   = true
}

variable "postgres_password" {
  description = "PostgreSQL password for the mlflow database user"
  type        = string
  sensitive   = true
}

variable "mlflow_secret_key" {
  description = "Secret key for MLflow UI session signing (min 32 chars)"
  type        = string
  sensitive   = true
}

variable "argocd_chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "7.7.0"
}

variable "git_repo_url" {
  description = "HTTPS URL of the ml-platform-infra git repository (ArgoCD source)"
  type        = string
}

variable "git_target_revision" {
  description = "Branch or tag ArgoCD tracks"
  type        = string
  default     = "main"
}
