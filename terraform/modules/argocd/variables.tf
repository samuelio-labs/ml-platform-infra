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
