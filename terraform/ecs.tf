# Create an ECS cluster to run tasks
resource "aws_ecs_cluster" "ecs_cluster" {
  name = local.resources_common_name
}

# Create an IAM role for task execution to assume
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
        name  = local.resources_common_name
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
        name  = local.resources_common_name
        image = "${local.account_id}.dkr.ecr.${var.region}.amazonaws.com/${local.resources_common_name}-server:latest"
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.ecs_tasks_log_group.name
            awslogs-region        = var.region
            awslogs-stream-prefix = "server"
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

# Create service definition for the server
resource "aws_ecs_service" "server" {
  name            = "${local.resources_common_name}-server"
  cluster         = aws_ecs_cluster.ecs_cluster.name
  task_definition = aws_ecs_task_definition.server.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets = [aws_subnet.main.id]
    assign_public_ip = true
  }
}

# # Create an IAM role for our service to assume
# resource "aws_iam_role" "airflow_server" {
#   name                 = "ecs-tasks-tutorial-airflow_server"
#   description          = "ecs-tasks-tutorial IAM role for Airflow server"
#   max_session_duration = 3600
#   assume_role_policy = jsonencode(
#     {
#       Statement = [
#         {
#           Action = "sts:AssumeRole"
#           Effect = "Allow"
#           Principal = {
#             Service = "ec2.amazonaws.com"
#           }
#         },
#       ]
#       Version = "2012-10-17"
#     }
#   )
#   inline_policy {
#     name = "ecs-tasks-tutorial-airflow_server"
#     policy = jsonencode({
#       Version = "2012-10-17"
#       Statement = [
#         {
#           Effect = "Allow"
#           Condition = {
#             ArnEquals = {
#               "ecs:cluster" : aws_ecs_cluster.ecs_cluster.arn
#             }
#           }
#           Action = [
#             "ecs:RunTask"
#           ]
#           Resource = [
#             "arn:aws:ecs:${var.region}:${local.account_id}:task-definition/ecs-tasks-tutorial:*",
#             "arn:aws:ecs:${var.region}:${local.account_id}:task-definition/ecs-tasks-tutorial"
#           ]
#         },
#         {
#           Effect = "Allow"
#           Action = [
#             "ecs:DescribeTasks"
#           ]
#           Resource = [
#             "arn:aws:ecs:${var.region}:${local.account_id}:task/ecs-tasks-tutorial/*"
#           ]
#         },
#         {
#           Effect = "Allow"
#           Action = [
#             "logs:GetLogEvents"
#           ]
#           Resource = [
#             "${aws_cloudwatch_log_group.ecs_tasks_log_group.arn}:*"
#           ]
#         },
#         {
#           Effect = "Allow"
#           Action = [
#             "iam:PassRole"
#           ]
#           Resource = [
#             aws_iam_role.tasks_execution_role.arn
#           ]
#         }
#       ]
#     })
#   }
# }
