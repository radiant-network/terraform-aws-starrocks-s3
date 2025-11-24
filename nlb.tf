resource "aws_lb" "star_rocks_nlb" {
  name               = "${var.project}-nlb-${var.environment}"
  internal           = var.internal_nlb
  load_balancer_type = "network"
  subnets            = [var.subnet_id]
  enable_deletion_protection = false
}

# 9030 is the query port
resource "aws_lb_target_group" "frontend_query_tg" {
  name     = "${var.project}-fe-query-tg-${var.environment}"
  port     = 9030
  protocol = "TCP"
  vpc_id   = var.vpc_id
}

resource "aws_lb_target_group_attachment" "frontend_query_attachment" {
  for_each         = { for idx, id in aws_instance.star_rocks_frontend.*.id : idx => id }
  target_group_arn = aws_lb_target_group.frontend_query_tg.arn
  target_id        = each.value
}


resource "aws_lb_listener" "frontend_query_listener" {
  load_balancer_arn = aws_lb.star_rocks_nlb.arn
  port              = 9030
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_query_tg.arn
  }
}

# 9010 is the port to register Frontends
# Needed on NLB because new host service discovery is done through NLB DNS
resource "aws_lb_target_group" "frontend_editlog_tg" {
  name     = "${var.project}-fe-editlog-tg-${var.environment}"
  port     = 9010
  protocol = "TCP"
  vpc_id   = var.vpc_id
}

resource "aws_lb_target_group_attachment" "frontend_editlog_attachment" {
  for_each         = { for idx, id in aws_instance.star_rocks_frontend.*.id : idx => id }
  target_group_arn = aws_lb_target_group.frontend_editlog_tg.arn
  target_id        = each.value
}


resource "aws_lb_listener" "frontend_editlog_listener" {
  load_balancer_arn = aws_lb.star_rocks_nlb.arn
  port              = 9010
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_editlog_tg.arn
  }
}


