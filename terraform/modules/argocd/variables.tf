variable "chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "7.7.0"
}

variable "git_repo_url" {
  description = "HTTPS URL of the ml-platform-infra git repository"
  type        = string
}

variable "git_target_revision" {
  description = "Branch or tag ArgoCD tracks"
  type        = string
  default     = "main"
}

variable "kubectl_context" {
  description = "kubectl context used to apply the App-of-Apps manifest after ArgoCD is ready"
  type        = string
}

variable "server_insecure" {
  description = "Disable TLS on the ArgoCD server (true for local dev, false for production)"
  type        = bool
  default     = false
}
