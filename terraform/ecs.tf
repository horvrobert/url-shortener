resource "aws_ecs_cluster" "url_shortener_cluster" {
  name = "url-shortener-cluster"
}

resource "aws_ecs_task_definition" "url_shortener_task_definition" {
  family                   = "url-shortener-task-definition"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  container_definitions = jsonencode([
    {
      name  = "url-shortener"
      image = "${aws_ecr_repository.app.repository_url}:v1.0.1"
      portMappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "DB_SECRET_ARN"
          value = aws_secretsmanager_secret.db_credentials.arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/url-shortener"
          "awslogs-region"        = "eu-central-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "url_shortener_service" {
  name            = "url-shortener-service"
  cluster         = aws_ecs_cluster.url_shortener_cluster.id
  task_definition = aws_ecs_task_definition.url_shortener_task_definition.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_groups  = [aws_security_group.sg_app.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.url_shortener_tg.arn
    container_name   = "url-shortener"
    container_port   = 8000
  }
}


resource "aws_cloudwatch_log_group" "url_shortener_logs" {
  name              = "/ecs/url-shortener"
  retention_in_days = 7
}