variable "profile" {
  type        = string
  description = "Name of the AWS CLI profile that will run these actions."
}
variable "region" {
  type        = string
  description = "Name of the AWS region where to deploy these resources."
}

data "aws_caller_identity" "current" {}
locals {
  account_id = data.aws_caller_identity.current.account_id
  env_suffix = terraform.workspace == "default" ? "prod" : terraform.workspace
  resources_common_name = "ecr-ecs-fargate-overview-${local.env_suffix}"
}
