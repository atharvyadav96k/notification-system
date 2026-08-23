provider "docker" {
  host = var.docker_host

  registry_auth {
    address = var.registry
  }
}

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kube_context != "" ? var.kube_context : null
}
