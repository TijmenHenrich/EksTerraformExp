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
  depends_on = [ aws_security_group.argocd_sg ]
  name = "argocd_sg"
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd-${var.env_name}"
  }
}


# Create a random secret string
data "aws_secretsmanager_random_password" "argocd_admin_password" { 
  password_length = 20
}
#init provider htpasswd https://registry.terraform.io/providers/loafoe/htpasswd/latest/docs/resources/password
provider "htpasswd" {
}


# Create the secret in AWS Secrets Manager, no value is added yet
resource  "aws_secretsmanager_secret" "argocd_admin_password_secret" {
  name = "argocd-admin-password"
}
resource "htpasswd_password" "hash"{
  depends_on = [ data.aws_secretsmanager_random_password.argocd_admin_password ]
  password = data.aws_secretsmanager_random_password.argocd_admin_password
}


# Fetch the password and store it in the aws_secretsmanager_secret_version
resource "aws_secretsmanager_secret_version" "argocd_admin_password_version" {
  depends_on = [ data.aws_secretsmanager_random_password.argocd_admin_password ]
  secret_id = aws_secretsmanager_secret.argocd_admin_password_secret.id
  secret_string = data.aws_secretsmanager_random_password.argocd_admin_password
  lifecycle {
    ignore_changes = [
      secret_string, # Ignore changes to the secret_string attribute
    ]
  }
}

# Fetch the secret string from the aws_secretsmanager_secret_version
data "aws_secretsmanager_secret_version" "argocd_admin_password_data" {
  depends_on = [ aws_secretsmanager_secret_version.argocd_admin_password_version ]
  secret_id = aws_secretsmanager_secret.argocd_admin_password_secret.id
}


# Deploy ArgoCD with custom password and LDAP login
resource "helm_release" "argocd" {
  depends_on = [ aws_security_group.argocd_sg ]
  name       = "argocd-${var.env_name}"
  chart      = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  version    = "5.27.3"
  namespace  = "argocd-${var.env_name}"
  timeout    = "1200"
  values     = [templatefile("argocd/install.yaml", {
        argocdServerAdminPassword = "${htpasswd_password.hash.bcrypt}"#,
        #securityGroupId = "${data.aws_security_group.argocd_sg.id}",
  })]
}

data "aws_lb" "argocd_lb" {
  depends_on = [ helm_release.argocd ]
  tags = {
    "kubernetes.io/service-name" = "argocd-${var.env_name}/argocd-${var.env_name}-server"
  }
}

# Exposed ArgoCD API - authenticated using `username`/`password`
provider "argocd" {
  server_addr = "${data.aws_lb.argocd_lb.dns_name}:443"
  username    = "admin"
  password    = data.aws_secretsmanager_secret_version.argocd_admin_password_data.secret_string
  insecure    = true
}

# Public Helm repository
resource "argocd_repository" "public_nginx_helm" {
  depends_on = [ provider.argocd ]
  repo = "https://helm.nginx.com/stable"
  name = "nginx-stable"
  type = "helm"
}
