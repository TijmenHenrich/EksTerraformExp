resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd-${var.environment}"
  }
}

# Create a secret version in AWS Secrets Manager
data "aws_secretsmanager_random_password" "argocd_admin_password" { 
  password_length = 20 
  exclude_numbers = false 
  exclude_punctuation = true 
  include_space = false 
}

# Set the random pass as the secret value in AWS Secrets Manager
resource  "aws_secretsmanager_secret" "argocd_admin_password_secret" {
  name = "argocd-admin-password"
}

# Fetch the password from AWS Secrets Manager
resource "aws_secretsmanager_secret_version" "argocd_admin_password_version" {
  secret_id = aws_secretsmanager_secret.argocd_admin_password_secret.id
  secret_string = random_password.argocd_admin_password.result
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
    argocd_admin_password = data.aws_secretsmanager_secret_version.argocd_admin_password_data.secret_string
  })]
}

data "aws_lb" "argocd_lb" {
  tags = {
    "kubernetes.io/service-name" = "argocd-service"
  }
}


# Exposed ArgoCD API - authenticated using `username`/`password`
provider "argocd" {
  server_addr = data.aws_lb.argocd_lb.dns_name
  username    = "admin"
  password    = data.aws_secretsmanager_secret_version.argocd_admin_password_data.secret_string
}

# Public Helm repository
resource "argocd_repository" "public_nginx_helm" {
  repo = "https://helm.nginx.com/stable"
  name = "nginx-stable"
  type = "helm"
}
