resource "aws_lambda_function" "refresh_instances" {
  function_name    = "refresh-instances"
  runtime          = "python3.8"
  handler          = "index.handler"
  timeout          = 300
  memory_size      = 128

  role = aws_iam_role.lambda_exec.arn

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  filename         = "${path.module}/lambda/refresh_instances.zip"

  depends_on = [aws_autoscaling_group.jdoodle]
}

# Role for the Lambda execution
data "aws_iam_policy_document" "lambda_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "lambda-exec-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_role.json
}

data "aws_iam_policy_document" "lambda_role1" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_execution_role" {
  name               = "lambda-execution-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_role1.json
}

data "aws_iam_policy_document" "lambda_execution_policy_doc" {
  statement {
    effect    = "Allow"
    actions   = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:UpdateAutoScalingGroup",
      "ec2:DescribeInstances",
      "ec2:CreateLaunchTemplate",
      "ec2:DescribeLaunchTemplates",

      ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "lambda_execution_policy" {
  name        = "lambda_execution_policy"
  description = "A test policy"
  policy      = data.aws_iam_policy_document.lambda_execution_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_execution_policy.arn
}

# Cloud watch event to trigger the refresh at 12AM UTC
resource "aws_cloudwatch_event_rule" "daily_refresh" {
  name        = "daily-refresh"
  description = "Daily refresh of instances at 12 am UTC"
  schedule_expression = "cron(0 0 * * ? *)"
}

resource "aws_cloudwatch_event_target" "invoke_lambda" {
  rule      = aws_cloudwatch_event_rule.daily_refresh.name
  target_id = "invoke-lambda"
  arn       = aws_lambda_function.refresh_instances.arn
}

resource "aws_iam_role" "cloudwatch_events" {
  name = "cloudwatch-events-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "events.amazonaws.com",
        },
      },
    ],
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_events" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
  role       = aws_iam_role.cloudwatch_events.name
}

resource "aws_cloudwatch_event_target" "allow_events" {
  rule      = aws_cloudwatch_event_rule.daily_refresh.name
  target_id = "allow_events"
  arn       = aws_lambda_function.refresh_instances.arn

  input_transformer {
    input_paths = {
      detail     = "$.detail",
      detailType = "$.detailType",
    }
    input_template = jsonencode({
      SourceArn = aws_cloudwatch_event_rule.daily_refresh.arn
    })
  }
}

resource "aws_lambda_permission" "allow_events" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.refresh_instances.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_refresh.arn
}

# creating the SNS Topic
resource "aws_sns_topic" "scaling_alerts" {
  name = "scaling-alerts"
}

resource "aws_autoscaling_notification" "scaling_notification" {
  group_names       = [aws_autoscaling_group.jdoodle.name]
  notifications     = ["autoscaling:EC2_INSTANCE_LAUNCH", "autoscaling:EC2_INSTANCE_TERMINATE"]
  topic_arn         = aws_sns_topic.scaling_alerts.arn
}

# ZIP archive for the Lambda function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda/refresh_instances.zip"
}
