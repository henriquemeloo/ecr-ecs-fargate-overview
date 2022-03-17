# Create a log group for tasks to feed
resource "aws_cloudwatch_log_group" "ecs_tasks_log_group" {
  name = local.resources_common_name
}
