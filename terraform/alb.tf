resource "aws_lb" "url_shortener_alb" {
  name               = "url-shortener-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg_alb.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Name      = "URL-Shortener-ALB"
    Project   = "URL-shortener"
    ManagedBy = "Terraform"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.url_shortener_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = {
    Name      = "URL-Shortener-HTTP-Listener"
    Project   = "URL-shortener"
    ManagedBy = "Terraform"
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.url_shortener_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.shrinkr.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.url_shortener_tg.arn
  }

  tags = {
    Name      = "URL-Shortener-HTTPS-Listener"
    Project   = "URL-shortener"
    ManagedBy = "Terraform"
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

  tags = {
    Name      = "URL-Shortener-TG"
    Project   = "URL-shortener"
    ManagedBy = "Terraform"
  }
}

output "alb_dns_name" {
  value = aws_lb.url_shortener_alb.dns_name
}