resource "aws_lb" "url_shortener_alb" {
  name               = "url-shortener-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg_alb.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.url_shortener_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.url_shortener_tg.arn
  }
}

resource "aws_lb_target_group" "url_shortener_tg" {
  name        = "url-shortener-tg"
  port        = 8000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.url-shortener-vpc.id

  health_check {
    path = "/health"
    port = 8000
  }
}

output "alb_dns_name" {
  value = aws_lb.url_shortener_alb.dns_name
}