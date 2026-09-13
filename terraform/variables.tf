variable "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Kubeconfig context to use"
  type        = string
  default     = "minikube"
}

variable "namespace" {
  description = "Kubernetes namespace to deploy into"
  type        = string
  default     = "score-api"
}

variable "release_name" {
  description = "Helm release name"
  type        = string
  default     = "score-api"
}

variable "chart_path" {
  description = "Path to the local Helm chart"
  type        = string
  default     = "../chart/score-api"
}

variable "values_file" {
  description = "Path to a Helm values override file"
  type        = string
  default     = "../chart/score-api/values-dev.yaml"
}

variable "image_repository" {
  description = "Container image repository (name only, no tag)"
  type        = string
  default     = "score-api"
}

variable "image_tag" {
  description = "Container image tag"
  type        = string
  default     = "local"
}

variable "ingress_host" {
  description = "Hostname the Ingress will route"
  type        = string
  default     = "score-api.local"
}

variable "basic_auth_password" {
  description = "Password for the /decision endpoint. Never commit a real value."
  type        = string
  sensitive   = true
}

variable "secret_name" {
  description = "Name of the Kubernetes Secret holding BASIC_AUTH_PASSWORD"
  type        = string
  default     = "score-api-basic-auth"
}