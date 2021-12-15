resource "aws_lambda_function" "rds" {
  filename      = "lambda_function_payload.zip"
  function_name = "populate-nlb-tg-with-rds-private-ip"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "populate-nlb-tg-with-rds-private-ip.handler"

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  runtime = "python3.8"

  timeout = 300

  environment {
    variables = {
      RDS_PORT   = var.db_port
      NLB_TG_ARN = aws_lb_target_group.nlb-tg.arn
      RDS_SG_ID  = aws_security_group.sg.id
      RDS_ID     = aws_db_instance.postgresql.id
    }
  }

  tags = {
    Environment = var.environment
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda_nlb" {
  name = "nlb-tg-access"
  role = aws_iam_role.iam_for_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
            "ec2:DescribeNetworkInterfaces",
            "elasticloadbalancing:DeregisterTargets",
            "elasticloadbalancing:DescribeTargetHealth",
            "elasticloadbalancing:RegisterTargets",
            "rds:DescribeDBInstances"
        ]
        Effect = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy" "lambda_logging" {
  name = "lambda_logging"
  role = aws_iam_role.iam_for_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
        ]
        Effect = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
    ]
  })
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.rds.function_name}"
  retention_in_days = 1
}

resource "aws_cloudwatch_event_rule" "lambda" {
  name                = "populate-nlb-tg-with-rds-private-ip"
  description         = "Populate NLB tg with RDS private IP"
  schedule_expression = "rate(15 minutes)"
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.lambda.name
  target_id = "Lambda"
  arn       = aws_lambda_function.rds.arn
}

resource "aws_lambda_permission" "cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rds.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda.arn
}