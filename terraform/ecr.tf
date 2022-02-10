# Create an ECR repository to store our application images
resource "aws_ecr_repository" "ecr_repo_server" {
  name = "${local.resources_common_name}-server"
}

resource "aws_ecr_repository" "ecr_repo_task" {
  name = "${local.resources_common_name}-task"
}
