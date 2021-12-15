resource "aws_lb" "nlb" {
  name                       = "nlb-expose-rds-${var.environment}"
  internal                   = false
  load_balancer_type         = "network"
  subnets                    = [local.subnet_id]
  enable_deletion_protection = false

  tags = {
    Environment = var.environment
  }
}

resource "aws_lb_listener" "nlb-listener" {
  load_balancer_arn = aws_lb.nlb.id
  port              = var.db_port
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.nlb-tg.id
    type             = "forward"
  }
}

resource "aws_lb_target_group" "nlb-tg" {
  name        = "expose-rds-${var.environment}"
  port        = var.db_port
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = aws_vpc.vpc.id

  health_check {
    enabled  = true
    protocol = "TCP"
  }

  tags = {
    Environment = var.environment
  }
}