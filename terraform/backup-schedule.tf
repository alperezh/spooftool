# backup-schedule.tf

resource "aws_cloudwatch_event_rule" "daily_backup" {
  name                = "dmarcdefense-daily-backup"
  description         = "Ejecuta el backup diario de DMARCDefense"
  schedule_expression = "cron(0 3 * * ? *)" # 3AM todos los días
}

resource "aws_cloudwatch_event_target" "backup_lambda_target" {
  rule      = aws_cloudwatch_event_rule.daily_backup.name
  target_id = "TriggerBackupLambda"
  arn       = aws_lambda_function.backup_lambda.arn
}

resource "aws_lambda_function" "backup_lambda" {
  filename         = "${path.module}/lambda/backup_lambda.zip"
  function_name    = "dmarcdefense-backup-trigger"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "index.handler"
  source_code_hash = filebase64sha256("${path.module}/lambda/backup_lambda.zip")
  runtime          = "nodejs18.x"
  timeout          = 60

  environment {
    variables = {
      CONTAINER_SERVICE = aws_lightsail_container_service.dmarcdefense.name
      REGION            = var.aws_region
      S3_BUCKET         = aws_s3_bucket.backups.id
    }
  }
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "dmarcdefense-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_backup_policy" {
  name        = "dmarcdefense-lambda-backup-policy"
  description = "Permisos para ejecutar backup en Lightsail"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "lightsail:GetContainerServices",
          "lightsail:OpenContainerServiceSSH",
          "lightsail:CreateContainerServiceDeployment",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.backups.arn,
          "${aws_s3_bucket.backups.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_backup_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_backup_policy.arn
}
