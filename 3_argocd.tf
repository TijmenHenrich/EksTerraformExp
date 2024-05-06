# Define the security group
resource "aws_security_group" "argocd_sg" {
  name        = "argocd_sg"
  description = "Security group allowing traffic from two specific IP addresses, vco office and vco vpn"

# Inbound rule allowing LB access from two specific IP addresses
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["157.97.112.130/32", "149.11.201.58/32"]
  }
}

# Retrieve the ARNs of the existing resources
data "aws_security_group" "argocd_sg" {
  name = "argocd_sg"
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd-${var.env_name}"
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
  name       = "argocd-${var.env_name}"
  chart      = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  version    = "5.27.3"
  namespace  = "argocd-${var.env_name}"
  timeout    = "1200"
  values     = [templatefile("argocd/install.yaml", {
    configs = {
      secret = {
        argocdServerAdminPassword = data.aws_secretsmanager_secret_version.argocd_admin_password_data.secret_string
      }
    }
  })]
}

data "aws_lb" "argocd_lb" {
  depends_on = [ helm_release.argocd ]
  tags = {
    "kubernetes.io/service-name" = "argocd-${var.env_name}/argocd-${var.env_name}-server"
  }
}

# Attach the security group to the network load balancer
resource "aws_lb_target_group_attachment" "attach_argocd_sg_to_lb" {
  target_group_arn = data.aws_lb.argocd_lb.arn
  target_id        = data.aws_security_group.argocd_sg.id
}

# Exposed ArgoCD API - authenticated using `username`/`password`
provider "argocd" {
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
