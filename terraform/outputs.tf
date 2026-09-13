output "namespace" {
  value = kubernetes_namespace.score_api.metadata[0].name
}

output "release_name" {
  value = helm_release.score_api.name
}

output "release_status" {
  value = helm_release.score_api.status
}

output "ingress_host" {
  value = var.ingress_host
}

output "secret_name" {
  value = kubernetes_secret.basic_auth.metadata[0].name
}