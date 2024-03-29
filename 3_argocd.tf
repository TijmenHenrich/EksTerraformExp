resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd-${var.environment}"
  }
}

# Create a secret in AWS Secrets Manager
resource "aws_secretsmanager_secret" "argocd_password" {
  name        = "argocd-password"
  description = "Password for ArgoCD"
}

# Create a secret version in AWS Secrets Manager
resource "aws_secretsmanager_secret_version" "argocd_password" {
  secret_id     = aws_secretsmanager_secret.argocd_password.id
  secret_string = "your_secret_password"
}

# Fetch the password from AWS Secrets Manager
data "aws_secretsmanager_secret_version" "argocd_password" {
  secret_id = aws_secretsmanager_secret.argocd_password.id
}

resource "helm_release" "argocd" {
  name       = "argocd-${var.environment}"
  chart      = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  version    = "5.27.3"
  namespace  = "argocd-${var.environment}"
  timeout    = "1200"
  values     = [templatefile("argocd/install.yaml", {
    argocd_admin_password = data.aws_secretsmanager_secret_version.argocd_password.secret_string
  })]
}

# Query AWS for Load Balancers created by ArgoCD
data "aws_lb" "argocd_lbs" {
  tags = {
    "kubernetes.io/service-name" = "argocd/argocd-${var.environment}/argo-app-server" # Load Balancer tag
    #kubernetes.io/service-name" = "argocd/argocd-dev/argo-test-app-server"  # Adjust the tag values as per your ArgoCD configuration
  }
}

# Get the Load Balancer details using the ARN
data "aws_lb" "argocd_lb" {
  arn  = data.aws_lb.argocd_lbs.arn
}

# Exposed ArgoCD API - authenticated using `username`/`password`
provider "argocd" {
  server_addr = data.aws_lb.argocd_lb.dns_name
  username    = "admin"
  password    = data.aws_secretsmanager_secret_version.argocd_password.secret_string
}

# Public Helm repository
resource "argocd_repository" "public_nginx_helm" {
  repo = "https://helm.nginx.com/stable"
  name = "nginx-stable"
  type = "helm"
}
