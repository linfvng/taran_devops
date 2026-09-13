resource "kubernetes_namespace" "score_api" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_secret" "basic_auth" {
  metadata {
    name      = var.secret_name
    namespace = kubernetes_namespace.score_api.metadata[0].name
  }

  data = {
    BASIC_AUTH_PASSWORD = var.basic_auth_password
  }

  type = "Opaque"
}

resource "helm_release" "score_api" {
  name      = var.release_name
  namespace = kubernetes_namespace.score_api.metadata[0].name
  chart     = var.chart_path
  values    = [file(var.values_file)]

  set {
    name  = "image.repository"
    value = var.image_repository
  }

  set {
    name  = "image.tag"
    value = var.image_tag
  }

  set {
    name  = "ingress.host"
    value = var.ingress_host
  }

  set {
    name  = "auth.existingSecret"
    value = kubernetes_secret.basic_auth.metadata[0].name
  }

  depends_on = [kubernetes_secret.basic_auth]
}