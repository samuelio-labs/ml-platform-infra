variable "minio_root_user" {
  description = "MinIO root username"
  type        = string
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
  description = "Secret key for MLflow UI session signing"
  type        = string
  sensitive   = true
}
