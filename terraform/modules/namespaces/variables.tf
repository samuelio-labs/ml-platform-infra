variable "namespaces" {
  description = "Per-namespace resource quota and LimitRange configuration"
  type = map(object({
    lim_cpu         = string
    lim_mem         = string
    default_lim_cpu = string
    default_lim_mem = string
  }))
}
