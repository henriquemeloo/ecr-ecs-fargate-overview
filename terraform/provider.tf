provider "aws" {
  region  = "us-east-1"
  profile = var.profile
  default_tags {
    tags = {
      "project" = "ecr-ecs-fargate-overview"
    }
  }
}
