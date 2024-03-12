resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd-${var.environment}"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd-${var.environment}"
  chart      = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  version    = "5.27.3"
  namespace  = "argocd-${var.environment}"
  timeout    = "1200"
  values     = [templatefile("argocd/install.yaml", {})]
}

resource "null_resource" "password" {
  provisioner "local-exec" {
    command = "kubectl -n argocd-${var.environment} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d > argocd-password.txt"
  }
}

resource "null_resource" "del-argo-pass" {
  depends_on = [null_resource.password]
  provisioner "local-exec" {
    command = "kubectl -n argocd-${var.environment} delete secret argocd-initial-admin-secret"
  }
}

# Exposed ArgoCD API - authenticated using `username`/`password`
provider "argocd" {
  server_addr = "argocd.local:443"
  username    = "admin"
  password    = filebase64("argocd-password.txt")
}

# Public Helm repository
resource "argocd_repository" "public_nginx_helm" {
  repo = "https://helm.nginx.com/stable"
  name = "nginx-stable"
  type = "helm"
}
