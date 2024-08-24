# Step 1: Set Up S3 Buckets
resource "aws_s3_bucket" "source_bucket" {
  bucket = "spdh-src-bucket245254"
  acl    = "private"
}

resource "aws_s3_bucket" "destination_bucket" {
  bucket = "spdh-dest-bucket0178566"
  acl    = "private"
}

# Step 2: Create an IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda_s3_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })

  inline_policy {
    name = "s3_lambda_policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject"
          ]
          Resource = [
            "${aws_s3_bucket.source_bucket.arn}/*",
            "${aws_s3_bucket.destination_bucket.arn}/*"
          ]
        },
        {
          Effect   = "Allow"
          Action   = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = "*"
        }
      ]
    })
  }
}

# Step 3: Create a Lambda Function
resource "aws_lambda_function" "s3_file_mover" {
  function_name = "s3_file_mover"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"

  # Define the S3 bucket and key where your Lambda function code is stored
  filename         = "lambda.zip"
  source_code_hash = filebase64sha256("lambda.zip")

  environment {
    variables = {
      DEST_BUCKET = aws_s3_bucket.destination_bucket.bucket
    }
  }
}

# Step 4: Create a Glue Job (Optional)
resource "aws_glue_catalog_database" "example" {
  name = "my_database"
}

resource "aws_glue_job" "example" {
  name     = "my_glue_job"
  role_arn = aws_iam_role.lambda_role.arn
  command {
    name            = "glueetl"
    script_location = "s3://my-script-bucket/my-script.py"
  }
  default_arguments = {
    "--TempDir"               = "s3://my-temp-dir/"
    "--job-bookmark-option"   = "job-bookmark-enable"
  }
}

# Step 5: Set Up Event Notification for S3 Bucket
resource "aws_s3_bucket_notification" "s3_notification" {
  bucket = aws_s3_bucket.source_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_file_mover.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".txt"
  }
}

# Grant permission for the S3 bucket to invoke the Lambda function
resource "aws_lambda_permission" "allow_s3_invocation" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_file_mover.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.source_bucket.arn
}

