# Create crawlers user
resource "aws_iam_user" "deploy_user" {
  name          = "${local.resources_common_name}-deploy_user"
  force_destroy = true
}
resource "aws_iam_policy" "deploy_user" {
  name        = "${local.resources_common_name}-deploy_user"
  description = "Policy for crawlers IAM user"
  policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow",
          Action = [
            "ecr:GetAuthorizationToken"
          ]
          "Resource" : "*"
        },
        {
          Effect = "Allow"
          Action = [
            "ecr:BatchCheckLayerAvailability",
            "ecr:PutImage",
            "ecr:InitiateLayerUpload",
            "ecr:UploadLayerPart",
            "ecr:CompleteLayerUpload"
          ]
          "Resource" : [
            aws_ecr_repository.ecr_repo_server.arn,
            aws_ecr_repository.ecr_repo_task.arn
          ]
        }
      ]
    }
  )
}
resource "aws_iam_user_policy_attachment" "deploy_user" {
  user       = aws_iam_user.deploy_user.name
  policy_arn = aws_iam_policy.deploy_user.arn
}
resource "aws_iam_access_key" "deploy_user" {
  user = aws_iam_user.deploy_user.name
}
output "deploy_user_access_key" {
  value = aws_iam_access_key.deploy_user.encrypted_secret
}
