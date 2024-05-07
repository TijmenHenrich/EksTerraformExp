configs:
  secret:
    argocdServerAdminPassword: $2a$10$OrLe1Lo12dhCmUrYBhpQ4.x9L0w8FCRof6CqHCjKHk5gBQZkoHBze <- encypted htpasswd -nbBC 10 "" password123 | tr -d ':\n' | sed 's/$2y/$2a/'
    argocdServerAdminPasswordMtime: "2006-01-02T15:04:05Z" < set in the past to set changes right away>


# Attach the security group to the network load balancer
resource "aws_lb_target_group_attachment" "attach_argocd_sg_to_lb" {
  target_group_arn = data.aws_lb.argocd_lb.arn
  target_id        = data.aws_security_group.argocd_sg.id
}