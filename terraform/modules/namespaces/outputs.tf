output "namespace_names" {
  description = "Names of all created namespaces"
  value       = [for ns in kubernetes_namespace.this : ns.metadata[0].name]
}

output "namespaces" {
  description = "Map of namespace name to namespace resource"
  value       = kubernetes_namespace.this
}
