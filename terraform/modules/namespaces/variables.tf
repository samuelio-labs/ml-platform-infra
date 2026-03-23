variable "namespaces" {
  description = "Per-namespace resource quota configuration"
  type = map(object({
    req_cpu = string
    req_mem = string
    lim_cpu = string
    lim_mem = string
  }))
}
