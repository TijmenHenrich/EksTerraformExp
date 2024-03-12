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
  values     = [templatefile("./argocd/install.yaml", {})]
}
resource "null_resource" "password" {
  provisioner "local-exec" {
    working_dir = "./argocd"
    command     = "kubectl -n argocd-${var.environment} get secret argocd-initial-admin-secret -o jsonpath={.data.password} | base64 -d > argocd-login.txt"
  }
}

resource "null_resource" "del-argo-pass" {
  depends_on = [null_resource.password]
  provisioner "local-exec" {
    command = "kubectl -n argocd-${var.environment} delete secret argocd-initial-admin-secret"
  }
}