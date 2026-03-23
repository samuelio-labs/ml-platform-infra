terraform {
  required_version = ">= 1.9"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.30"
    }
  }
}

# MinIO credentials — referenced by MLflow, DVC, and KServe (model storage).
resource "kubernetes_secret" "minio_credentials" {
  metadata {
    name      = "minio-credentials"
    namespace = "mlflow"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  type = "Opaque"

  data = {
    root-user     = var.minio_root_user
    root-password = var.minio_root_password
  }
}

# PostgreSQL credentials — used by the MLflow tracking server backend.
resource "kubernetes_secret" "postgres_credentials" {
  metadata {
    name      = "postgres-credentials"
    namespace = "mlflow"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  type = "Opaque"

  data = {
    username = "mlflow"
    password = var.postgres_password
  }
}

# MLflow session signing key — required for the MLflow UI.
resource "kubernetes_secret" "mlflow_secret_key" {
  metadata {
    name      = "mlflow-secret-key"
    namespace = "mlflow"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  type = "Opaque"

  data = {
    secret-key = var.mlflow_secret_key
  }
}

# MinIO credentials mirrored into kserve namespace so KServe
# can pull model artifacts directly from the object store.
resource "kubernetes_secret" "minio_credentials_kserve" {
  metadata {
    name      = "minio-credentials"
    namespace = "kserve"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  type = "Opaque"

  data = {
    root-user     = var.minio_root_user
    root-password = var.minio_root_password
  }
}
