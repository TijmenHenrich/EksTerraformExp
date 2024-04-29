resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd-${var.environment}"
  }
}

# Create a secret version in AWS Secrets Manager
data "aws_secretsmanager_random_password" "argocd_admin_password" { 
  password_length = 20
}

# Set the random pass as the secret value in AWS Secrets Manager
resource  "aws_secretsmanager_secret" "argocd_admin_password_secret" {
  name = "argocd-admin-password"
}

# Fetch the password from AWS Secrets Manager
resource "aws_secretsmanager_secret_version" "argocd_admin_password_version" {
  secret_id = aws_secretsmanager_secret.argocd_admin_password_secret.id
  secret_string = data.aws_secretsmanager_random_password.argocd_admin_password.random_password
  lifecycle {
    ignore_changes = [
      secret_string, # Ignore changes to the secret_string attribute
    ]
  }
}

data "aws_secretsmanager_secret_version" "argocd_admin_password_data" {
  secret_id = aws_secretsmanager_secret.argocd_admin_password_secret.id
}

resource "helm_release" "argocd" {
  name       = "argocd-${var.environment}"
  chart      = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  version    = "5.27.3"
  namespace  = "argocd-${var.environment}"
  timeout    = "1200"
  values     = [templatefile("argocd/install.yaml", {
    argocdServerAdminPassword = data.aws_secretsmanager_secret_version.argocd_admin_password_data.secret_string
  })]
}

data "aws_lb" "argocd_lb" {
  depends_on = [ helm_release.argocd ]
  tags = {
    "kubernetes.io/service-name" = "argocd-${var.environment}/argocd-${var.environment}-server"
  }
}


# Exposed ArgoCD API - authenticated using `username`/`password`
provider "argocd" {
  depends_on = [ data.aws_lb.argocd_lb.dns_name ]
  server_addr = data.aws_lb.argocd_lb.dns_name
  username    = "admin"
  password    = data.aws_secretsmanager_secret_version.argocd_admin_password_data.secret_string
  insecure    = true
}

# Public Helm repository
resource "argocd_repository" "public_nginx_helm" {
  repo = "https://helm.nginx.com/stable"
  name = "nginx-stable"
  type = "helm"
}
