# Create an ECS cluster to run tasks
resource "aws_ecs_cluster" "ecs_cluster" {
  name = local.resources_common_name
}

# Create an IAM execution role for task execution to assume
resource "aws_iam_role" "tasks_execution_role" {
  name = "${local.resources_common_name}-execution_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}
resource "aws_iam_role_policy_attachment" "sto-readonly-role-policy-attach" {
  role       = aws_iam_role.tasks_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Create task definition for the task
resource "aws_ecs_task_definition" "task" {
  family = "${local.resources_common_name}-task"
  container_definitions = jsonencode(
    [
      {
        name  = "${local.resources_common_name}-task"
        image = "${local.account_id}.dkr.ecr.${var.region}.amazonaws.com/${local.resources_common_name}-task:latest"
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.ecs_tasks_log_group.name
            awslogs-region        = var.region
            awslogs-stream-prefix = "tasks"
          }
        }
      }
    ]
  )
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.tasks_execution_role.arn
}

# Create task definition for the server
resource "aws_ecs_task_definition" "server" {
  family = "${local.resources_common_name}-server"
  container_definitions = jsonencode(
    [
      {
        name  = "${local.resources_common_name}-server"
        image = "${local.account_id}.dkr.ecr.${var.region}.amazonaws.com/${local.resources_common_name}-server:latest"
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.ecs_tasks_log_group.name
            awslogs-region        = var.region
            awslogs-stream-prefix = "server"
          }
        }
        essential = true
        portMappings = [
          {
            containerPort = 80
            hostPort      = 80
          }
        ],
        environment = [
          {
            "name"  = "AWS_DEFAULT_REGION",
            "value" = var.region
          },
          {
            "name"  = "CLUSTER_NAME",
            "value" = aws_ecs_cluster.ecs_cluster.name
          },
          {
            "name"  = "TASK_NAME",
            "value" = aws_ecs_task_definition.task.family
          },
          {
            "name"  = "SUBNET_ID",
            "value" = aws_subnet.main.id
          }
        ]
      }
    ]
  )
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.tasks_execution_role.arn
  task_role_arn            = aws_iam_role.server.arn
}


resource "aws_lb_target_group" "lb_target_group" {
  name        = "albtg-${local.env_suffix}"
  target_type = "ip"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  health_check {
    path = "/health"
  }
}
resource "aws_security_group" "web_inbound_sg" {
  name        = "albsg-${local.env_suffix}"
  description = "Allow HTTP from Anywhere into ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.resources_common_name}-inbound-sg"
  }
}

resource "aws_alb" "alb" {
  name            = local.resources_common_name
  subnets         = [aws_subnet.main.id, aws_subnet.extra.id]
  security_groups = [aws_security_group.web_inbound_sg.id]
  tags = {
    Name = "${local.resources_common_name}-alb"
  }
}
resource "aws_alb_listener" "lb_listener" {
  load_balancer_arn = aws_alb.alb.arn
  port              = "80"
  protocol          = "HTTP"
  depends_on        = [aws_lb_target_group.lb_target_group]
  default_action {
    target_group_arn = aws_lb_target_group.lb_target_group.arn
    type             = "forward"
  }
}
resource "aws_security_group" "ecs_service" {
  vpc_id      = aws_vpc.main.id
  name        = "${local.resources_common_name}-ecs-service-sg"
  description = "Allow egress from container"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.resources_common_name}-ecs-service-sg"
  }
}
# Create service definition for the server
resource "aws_ecs_service" "server" {
  name            = "${local.resources_common_name}-server"
  cluster         = aws_ecs_cluster.ecs_cluster.name
  task_definition = aws_ecs_task_definition.server.arn
  desired_count   = 2
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = [aws_subnet.main.id, aws_subnet.extra.id]
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = true
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.lb_target_group.arn
    container_name   = "${local.resources_common_name}-server"
    container_port   = 80
  }
  depends_on = [aws_alb.alb]
}

# Create an IAM role for our service to assume
resource "aws_iam_role" "server" {
  name                 = "${local.resources_common_name}-server"
  description          = "${local.resources_common_name} role for server"
  max_session_duration = 3600
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "ecs-tasks.amazonaws.com"
          }
        },
      ]
      Version = "2012-10-17"
    }
  )
  inline_policy {
    name = "ecs-tasks-tutorial-airflow_server"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Condition = {
            ArnEquals = {
              "ecs:cluster" : aws_ecs_cluster.ecs_cluster.arn
            }
          }
          Action = [
            "ecs:RunTask"
          ]
          Resource = [
            "arn:aws:ecs:${var.region}:${local.account_id}:task-definition/${aws_ecs_task_definition.task.family}"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "ecs:DescribeTasks"
          ]
          Condition = {
            ArnEquals = {
              "ecs:cluster" : aws_ecs_cluster.ecs_cluster.arn
            }
          }
          Resource = [
            "arn:aws:ecs:${var.region}:${local.account_id}:task/${aws_ecs_cluster.ecs_cluster.name}/*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "iam:PassRole"
          ]
          Resource = [
            aws_iam_role.tasks_execution_role.arn
          ]
        }
      ]
    })
  }
}
