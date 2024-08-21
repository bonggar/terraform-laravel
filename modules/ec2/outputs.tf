output "alb_target_group_name" {
  value = var.infra_role == "core" ? aws_lb_target_group.this[0].name : null
}

output "asg_group_name" {
  value = aws_autoscaling_group.this.name
}